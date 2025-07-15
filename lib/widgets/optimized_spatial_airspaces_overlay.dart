import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/airspace.dart';
import '../services/spatial_airspace_service.dart';
import '../utils/airspace_utils.dart';

/// Optimized airspace overlay with proper debouncing and performance improvements
class OptimizedSpatialAirspacesOverlay extends StatefulWidget {
  final SpatialAirspaceService spatialService;
  final bool showAirspacesLayer;
  final Function(Airspace) onAirspaceTap;
  final double currentAltitude;
  final Set<int>? typeFilter;

  const OptimizedSpatialAirspacesOverlay({
    super.key,
    required this.spatialService,
    required this.showAirspacesLayer,
    required this.onAirspaceTap,
    this.currentAltitude = 0,
    this.typeFilter,
  });

  @override
  State<OptimizedSpatialAirspacesOverlay> createState() =>
      _OptimizedSpatialAirspacesOverlayState();
}

class _OptimizedSpatialAirspacesOverlayState
    extends State<OptimizedSpatialAirspacesOverlay> {
  List<Airspace> _visibleAirspaces = [];
  LatLngBounds? _lastBounds;
  double? _lastZoom;
  bool _isLoading = false;
  Timer? _updateTimer;
  Timer? _loadingIndicatorTimer;
  bool _showLoadingIndicator = false;
  
  // Performance tuning constants
  static const Duration _updateDebounceDelay = Duration(milliseconds: 300);
  static const Duration _loadingIndicatorDelay = Duration(milliseconds: 500);
  static const double _zoomChangeThreshold = 0.5;
  static const double _boundsChangeThreshold = 0.01; // ~1km

  @override
  void initState() {
    super.initState();
    // Schedule initial load after first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkAndUpdateAirspaces();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _loadingIndicatorTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(OptimizedSpatialAirspacesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (!widget.showAirspacesLayer && oldWidget.showAirspacesLayer) {
      // Clear airspaces when layer is hidden
      setState(() {
        _visibleAirspaces.clear();
        _isLoading = false;
        _showLoadingIndicator = false;
      });
      _updateTimer?.cancel();
      _loadingIndicatorTimer?.cancel();
    } else if (widget.showAirspacesLayer && !oldWidget.showAirspacesLayer) {
      // Load airspaces when layer is shown
      _checkAndUpdateAirspaces();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAirspacesLayer) {
      return const SizedBox.shrink();
    }

    final mapController = MapCamera.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    // Schedule bounds check after build completes
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkBoundsChanged(mapController);
    });

    // Build polygons with performance optimizations
    final polygons = _buildOptimizedPolygons(mapController.zoom);
    
    if (polygons.isEmpty && !_showLoadingIndicator) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (polygons.isNotEmpty)
          PolygonLayer(
            polygons: polygons,
            polygonCulling: true, // Enable culling for better performance
          ),
        if (_showLoadingIndicator)
          Positioned(
            top: 10,
            right: 10,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Loading airspaces',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _checkBoundsChanged(MapCamera mapController) {
    final bounds = mapController.visibleBounds;
    final zoom = mapController.zoom;

    if (_shouldUpdateAirspaces(bounds, zoom)) {
      _scheduleUpdate(bounds, zoom);
    }
  }

  bool _shouldUpdateAirspaces(LatLngBounds bounds, double zoom) {
    if (_lastBounds == null || _lastZoom == null) {
      return true;
    }

    // Check if zoom changed significantly
    if ((zoom - _lastZoom!).abs() > _zoomChangeThreshold) {
      return true;
    }

    // Check if bounds changed significantly
    final latDiff = (bounds.center.latitude - _lastBounds!.center.latitude).abs();
    final lngDiff = (bounds.center.longitude - _lastBounds!.center.longitude).abs();

    return latDiff > _boundsChangeThreshold || lngDiff > _boundsChangeThreshold;
  }

  void _scheduleUpdate(LatLngBounds bounds, double zoom) {
    // Cancel any pending update
    _updateTimer?.cancel();

    // Schedule new update with debounce
    _updateTimer = Timer(_updateDebounceDelay, () {
      _updateVisibleAirspaces(bounds, zoom);
    });
  }

  void _checkAndUpdateAirspaces() {
    final mapController = MapCamera.maybeOf(context);
    if (mapController != null) {
      final bounds = mapController.visibleBounds;
      final zoom = mapController.zoom;
      _updateVisibleAirspaces(bounds, zoom);
    }
  }

  Future<void> _updateVisibleAirspaces(LatLngBounds bounds, double zoom) async {
    _lastBounds = bounds;
    _lastZoom = zoom;

    // Start loading
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });

      // Show loading indicator only if loading takes longer than expected
      _loadingIndicatorTimer?.cancel();
      _loadingIndicatorTimer = Timer(_loadingIndicatorDelay, () {
        if (_isLoading && mounted) {
          setState(() {
            _showLoadingIndicator = true;
          });
        }
      });
    }

    try {
      // Add padding to bounds for smoother scrolling
      final padding = _calculateBoundsPadding(zoom);
      final paddedBounds = LatLngBounds(
        LatLng(bounds.southWest.latitude - padding, bounds.southWest.longitude - padding),
        LatLng(bounds.northEast.latitude + padding, bounds.northEast.longitude + padding),
      );

      // Use spatial service for ultra-fast queries
      final airspaces = await widget.spatialService.getAirspacesInBounds(
        paddedBounds,
        currentAltitude: widget.currentAltitude > 0 ? widget.currentAltitude : null,
        typeFilter: widget.typeFilter,
      );

      if (mounted) {
        setState(() {
          _visibleAirspaces = airspaces;
          _isLoading = false;
          _showLoadingIndicator = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading airspaces: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showLoadingIndicator = false;
        });
      }
    } finally {
      _loadingIndicatorTimer?.cancel();
    }
  }

  double _calculateBoundsPadding(double zoom) {
    // More padding at lower zoom levels
    if (zoom < 8) return 0.5;
    if (zoom < 10) return 0.3;
    if (zoom < 12) return 0.2;
    return 0.1;
  }

  List<Polygon> _buildOptimizedPolygons(double zoom) {
    // At low zoom levels, we might want to filter out very small airspaces
    // For now, just build all visible airspaces
    return _visibleAirspaces
        .map((airspace) => _buildPolygon(airspace, zoom))
        .toList();
  }

  Polygon _buildPolygon(Airspace airspace, double zoom) {
    // Parse type and class to integers for color determination
    final typeInt = int.tryParse(airspace.type ?? '') ?? 0;
    final classInt = int.tryParse(airspace.icaoClass ?? '') ?? 0;
    
    final color = AirspaceUtils.getAirspaceColor(typeInt, classInt);
    final opacity = _calculateOpacity(airspace, zoom);

    return Polygon(
      points: airspace.geometry,
      color: color.withValues(alpha: opacity * 0.2),
      borderColor: color.withValues(alpha: opacity * 0.8),
      borderStrokeWidth: zoom > 12 ? 2.0 : 1.5,
      hitValue: airspace,
    );
  }

  double _calculateOpacity(Airspace airspace, double zoom) {
    // Base opacity
    double opacity = 0.8;

    // Reduce opacity for overlapping airspaces
    if (_visibleAirspaces.length > 20) {
      opacity *= 0.7;
    }

    // Reduce opacity at lower zoom levels
    if (zoom < 10) {
      opacity *= 0.6;
    }

    return opacity;
  }
}