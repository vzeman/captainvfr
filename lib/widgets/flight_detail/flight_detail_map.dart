import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/flight.dart';
import '../../models/moving_segment.dart';
import '../../constants/flight_detail_constants.dart';

class FlightDetailMap extends StatefulWidget {
  final Flight flight;
  final dynamic selectedSegment;
  final Function(dynamic) onSegmentSelected;
  final int? selectedChartPointIndex;

  const FlightDetailMap({
    super.key,
    required this.flight,
    this.selectedSegment,
    required this.onSegmentSelected,
    this.selectedChartPointIndex,
  });

  @override
  State<FlightDetailMap> createState() => FlightDetailMapState();
}

class FlightDetailMapState extends State<FlightDetailMap> {
  late final MapController _mapController;
  LatLngBounds? _flightBounds;
  final GlobalKey<State> _mapKey = GlobalKey();
  bool _isMapReady = false;
  bool _tilesLoaded = false;
  LatLng? _selectedChartPoint;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _calculateBounds();
    // Immediate initialization
    _isMapReady = true;

    // Schedule bounds fitting after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Small delay to ensure map is fully initialized
        Future.delayed(
          const Duration(milliseconds: FlightDetailConstants.mapFitDelayMilliseconds),
          () {
          if (mounted) {
            _fitBoundsWhenReady();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Calculates the geographical bounds of the flight path.
  /// Adds 10% padding to ensure the entire flight track is visible
  /// with some margin around the edges.
  void _calculateBounds() {
    if (widget.flight.path.isEmpty) return;

    final positions = widget.flight.positions;
    if (positions.isEmpty) return;

    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final point in positions) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1 + 0.01; // Add minimum padding
    final lngPadding = (maxLng - minLng) * 0.1 + 0.01; // Add minimum padding

    _flightBounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  /// Attempts to fit the map view to show the entire flight path.
  /// Includes retry logic in case the map controller isn't ready yet.
  /// Also triggers a micro zoom adjustment to force tile loading.
  void _fitBoundsWhenReady() {
    if (_flightBounds == null || !mounted) return;

    // Try to fit bounds, with retry logic if the map isn't ready yet
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: _flightBounds!,
          padding: const EdgeInsets.all(40.0),
        ),
      );

      // Force tile loading by triggering a micro zoom change
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_tilesLoaded) {
          final currentZoom = _mapController.camera.zoom;
          // Micro zoom in and out to force tile loading
          _mapController.move(_mapController.camera.center, currentZoom + 0.01);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _mapController.move(_mapController.camera.center, currentZoom);
            }
          });
        }
      });
    } catch (e) {
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _fitBoundsWhenReady();
        }
      });
    }
  }

  /// Fits the map view to display the entire flight track.
  /// This is called after the user finishes resizing the map panel
  /// to ensure the flight path remains centered and visible.
  void fitMapToTrack() {
    if (_flightBounds == null || !mounted) return;
    
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: _flightBounds!,
          padding: const EdgeInsets.all(40.0),
        ),
      );
    } catch (e) {
      // Silently fail if map is not ready
    }
  }

  /// Shows a marker on the map at the GPS location corresponding to
  /// the given data point index from the flight path.
  /// 
  /// [index] - The index in the flight path array (0-based)
  /// 
  /// This method is called when users interact with charts to visualize
  /// the selected point's location on the map.
  void showMarkerAtIndex(int index) {
    if (!mounted || widget.flight.path.isEmpty) return;
    
    // Ensure index is within bounds
    if (index < 0 || index >= widget.flight.path.length) {
      return;
    }
    
    final pathPoint = widget.flight.path[index];
    final newPoint = LatLng(pathPoint.latitude, pathPoint.longitude);
    setState(() {
      _selectedChartPoint = newPoint;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flight.path.isEmpty) {
      return const Center(child: Text('No flight path data available'));
    }

    if (!_isMapReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final positions = widget.flight.positions;
    final startPoint = positions.isNotEmpty
        ? positions.first
        : const LatLng(0, 0);
    final endPoint = positions.length > 1 ? positions.last : positions.first;

    // Create polylines for segments
    List<Polyline> polylines = [];

    // Default flight path
    polylines.add(
      Polyline(
        points: positions,
        color: Colors.blue.withValues(alpha: 0.6),
        strokeWidth: 3.0,
      ),
    );

    // Highlighted segment path
    if (widget.selectedSegment != null) {
      List<LatLng> segmentPoints = [];
      if (widget.selectedSegment is MovingSegment) {
        final segment = widget.selectedSegment as MovingSegment;
        final startIndex = widget.flight.path.indexWhere(
          (point) =>
              point.timestamp.millisecondsSinceEpoch >=
              segment.start.millisecondsSinceEpoch,
        );
        final endIndex = widget.flight.path.lastIndexWhere(
          (point) =>
              point.timestamp.millisecondsSinceEpoch <=
              segment.end.millisecondsSinceEpoch,
        );

        if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
          segmentPoints = widget.flight.path
              .sublist(startIndex, endIndex + 1)
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        }
      }

      if (segmentPoints.isNotEmpty) {
        polylines.add(
          Polyline(
            points: segmentPoints,
            color: Colors.orange,
            strokeWidth: 5.0,
          ),
        );
      }
    }

    // Calculate initial zoom level based on bounds
    double initialZoom = 13.0;
    LatLng initialCenter = startPoint;

    if (_flightBounds != null) {
      // Calculate center of bounds
      final centerLat = (_flightBounds!.north + _flightBounds!.south) / 2;
      final centerLng = (_flightBounds!.east + _flightBounds!.west) / 2;
      initialCenter = LatLng(centerLat, centerLng);

      // Calculate appropriate zoom level based on bounds size
      final latDiff = _flightBounds!.north - _flightBounds!.south;
      final lngDiff = _flightBounds!.east - _flightBounds!.west;
      final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

      // Rough estimation of zoom level based on bounds
      if (maxDiff > 1.0) {
        initialZoom = 8.0;
      } else if (maxDiff > 0.5) {
        initialZoom = 9.0;
      } else if (maxDiff > 0.2) {
        initialZoom = 10.0;
      } else if (maxDiff > 0.1) {
        initialZoom = 11.0;
      } else if (maxDiff > 0.05) {
        initialZoom = 12.0;
      } else {
        initialZoom = 13.0;
      }
    }

    return Container(
      color: const Color(0xFFE5E3DF), // Light grey background
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return FlutterMap(
              key: _mapKey,
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoom,
                minZoom: 3.0,
                maxZoom: 18.0,
                onMapReady: () {
                  // Force a rebuild when map is ready
                  if (mounted) {
                    // Force immediate state update to trigger tile loading
                    setState(() {});

                    if (_flightBounds != null) {
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) {
                          _fitBoundsWhenReady();
                        }
                      });
                    }
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.captainvfr',
                  maxZoom: 19,
                  tileBuilder: (context, tileWidget, tile) {
                    // Mark tiles as loaded when first tile renders
                    if (!_tilesLoaded && mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_tilesLoaded) {
                          setState(() {
                            _tilesLoaded = true;
                          });
                        }
                      });
                    }
                    return tileWidget;
                  },
                ),
                PolylineLayer(polylines: polylines),
                MarkerLayer(
                  markers: [
                    // Start marker
                    Marker(
                      point: startPoint,
                      child: const Icon(
                        Icons.flight_takeoff,
                        color: Colors.green,
                        size: 30,
                      ),
                    ),
                    // End marker
                    if (positions.length > 1)
                      Marker(
                        point: endPoint,
                        child: const Icon(
                          Icons.flight_land,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                    // Selected chart point marker
                    if (_selectedChartPoint != null)
                      Marker(
                        point: _selectedChartPoint!,
                        width: FlightDetailConstants.markerSize,
                        height: FlightDetailConstants.markerSize,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.deepOrange,
                            border: Border.all(
                              color: Colors.white,
                              width: FlightDetailConstants.markerBorderWidth,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(102),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: FlightDetailConstants.markerIconSize,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
