import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/flight.dart';
import '../../models/moving_segment.dart';

class FlightDetailMap extends StatefulWidget {
  final Flight flight;
  final dynamic selectedSegment;
  final Function(dynamic) onSegmentSelected;

  const FlightDetailMap({
    super.key,
    required this.flight,
    this.selectedSegment,
    required this.onSegmentSelected,
  });

  @override
  State<FlightDetailMap> createState() => _FlightDetailMapState();
}

class _FlightDetailMapState extends State<FlightDetailMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Wait for the map to be ready before fitting bounds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitBounds();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitBounds() {
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

    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    // Fit bounds with animation
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flight.path.isEmpty) {
      return const Center(child: Text('No flight path data available'));
    }

    final positions = widget.flight.positions;
    final startPoint = positions.isNotEmpty ? positions.first : const LatLng(0, 0);
    final endPoint = positions.length > 1 ? positions.last : positions.first;

    // Create polylines for segments
    List<Polyline> polylines = [];

    // Default flight path
    polylines.add(Polyline(
      points: positions,
      color: Colors.blue.withValues(alpha: 0.6),
      strokeWidth: 3.0,
    ));

    // Highlighted segment path
    if (widget.selectedSegment != null) {
      List<LatLng> segmentPoints = [];
      if (widget.selectedSegment is MovingSegment) {
        final segment = widget.selectedSegment as MovingSegment;
        final startIndex = widget.flight.path.indexWhere((point) =>
          point.timestamp.millisecondsSinceEpoch >= segment.start.millisecondsSinceEpoch);
        final endIndex = widget.flight.path.lastIndexWhere((point) =>
          point.timestamp.millisecondsSinceEpoch <= segment.end.millisecondsSinceEpoch);

        if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
          segmentPoints = widget.flight.path
            .sublist(startIndex, endIndex + 1)
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
        }
      }

      if (segmentPoints.isNotEmpty) {
        polylines.add(Polyline(
          points: segmentPoints,
          color: Colors.orange,
          strokeWidth: 5.0,
        ));
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: startPoint,
        initialZoom: 13.0,
        minZoom: 3.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.captainvfr',
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
          ],
        ),
      ],
    );
  }
}
