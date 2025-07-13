import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/airspace.dart';
import '../services/spatial_airspace_service.dart';
import '../utils/airspace_utils.dart';

/// Ultra-fast airspace overlay using spatial indexing
class SpatialAirspacesOverlay extends StatefulWidget {
  final SpatialAirspaceService spatialService;
  final bool showAirspacesLayer;
  final Function(Airspace)? onAirspaceTap;
  final double currentAltitude;
  final Set<int>? typeFilter;
  final Set<int>? icaoClassFilter;

  const SpatialAirspacesOverlay({
    super.key,
    required this.spatialService,
    required this.showAirspacesLayer,
    this.onAirspaceTap,
    this.currentAltitude = 0,
    this.typeFilter,
    this.icaoClassFilter,
  });

  @override
  State<SpatialAirspacesOverlay> createState() => _SpatialAirspacesOverlayState();
}

class _SpatialAirspacesOverlayState extends State<SpatialAirspacesOverlay> {
  List<Airspace> _visibleAirspaces = [];
  bool _isLoading = false;
  LatLngBounds? _lastBounds;
  double? _lastZoom;
  bool _isDisposing = false;
  
  // Cache for simplified polygons at different zoom levels
  final Map<String, Map<int, List<LatLng>>> _simplifiedPolygonsCache = {};
  

  @override
  void initState() {
    super.initState();
    widget.spatialService.addListener(_onAirspacesChanged);
    
    // Load initial airspaces if layer is visible
    if (widget.showAirspacesLayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshVisibleAirspaces();
      });
    }
  }

  @override
  void dispose() {
    widget.spatialService.removeListener(_onAirspacesChanged);
    super.dispose();
  }

  void _onAirspacesChanged() {
    // Clear cache when airspaces change
    _simplifiedPolygonsCache.clear();
    _refreshVisibleAirspaces();
  }

  @override
  void didUpdateWidget(SpatialAirspacesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if layer visibility changed
    if (oldWidget.showAirspacesLayer != widget.showAirspacesLayer) {
      if (!widget.showAirspacesLayer) {
        // Clear airspaces immediately when layer is hidden
        setState(() {
          _isDisposing = true;
          _visibleAirspaces = [];
          _simplifiedPolygonsCache.clear();
        });
        return;
      } else {
        // Layer was turned on, refresh airspaces
        setState(() {
          _isDisposing = false;
          // Reset bounds tracking to force update
          _lastBounds = null;
          _lastZoom = null;
        });
        _refreshVisibleAirspaces();
      }
    }
    
    // Check if filters changed
    if (oldWidget.typeFilter != widget.typeFilter ||
        oldWidget.icaoClassFilter != widget.icaoClassFilter ||
        (widget.currentAltitude - oldWidget.currentAltitude).abs() > 100) {
      _refreshVisibleAirspaces();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAirspacesLayer || _isDisposing) {
      return const SizedBox.shrink();
    }

    // Get map controller to check visible bounds
    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final bounds = mapController.camera.visibleBounds;
    final zoom = mapController.camera.zoom;

    // Check if we need to update airspaces
    if (_shouldUpdateAirspaces(bounds, zoom)) {
      _updateVisibleAirspaces(bounds, zoom);
    }

    // Build polygons with performance optimizations
    final polygons = _buildOptimizedPolygons(zoom);
    
    // If no polygons to render, return early
    if (polygons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        PolygonLayer(
          key: ValueKey('airspace_polygons_${DateTime.now().millisecondsSinceEpoch}'),
          polygons: polygons,
          polygonCulling: true,
        ),
        if (_isLoading)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading airspaces...',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  bool _shouldUpdateAirspaces(LatLngBounds bounds, double zoom) {
    if (_lastBounds == null || _lastZoom == null) {
      return true;
    }

    // Check if zoom changed significantly
    if ((zoom - _lastZoom!).abs() > 0.5) {
      return true;
    }

    // Check if bounds changed significantly
    final latDiff = (bounds.center.latitude - _lastBounds!.center.latitude).abs();
    final lngDiff = (bounds.center.longitude - _lastBounds!.center.longitude).abs();
    final threshold = 0.01; // Approximately 1km

    return latDiff > threshold || lngDiff > threshold;
  }

  void _updateVisibleAirspaces(LatLngBounds bounds, double zoom) async {
    _lastBounds = bounds;
    _lastZoom = zoom;

    setState(() {
      _isLoading = true;
    });

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
        icaoClassFilter: widget.icaoClassFilter,
      );

      
      if (mounted) {
        setState(() {
          _visibleAirspaces = airspaces;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _refreshVisibleAirspaces() {
    _lastBounds = null; // Force refresh
    final mapController = MapController.maybeOf(context);
    if (mapController != null) {
      final bounds = mapController.camera.visibleBounds;
      final zoom = mapController.camera.zoom;
      _updateVisibleAirspaces(bounds, zoom);
    }
  }

  double _calculateBoundsPadding(double zoom) {
    // Adjust padding based on zoom level
    if (zoom >= 15) return 0.01;  // ~1km
    if (zoom >= 12) return 0.05;  // ~5km
    if (zoom >= 10) return 0.1;   // ~10km
    if (zoom >= 8) return 0.2;    // ~20km
    return 0.5;                   // ~50km
  }

  List<Polygon> _buildOptimizedPolygons(double zoom) {
    // Don't build polygons if layer is not visible or disposing
    if (!widget.showAirspacesLayer || _isDisposing || _visibleAirspaces.isEmpty) {
      return [];
    }

    // Sort airspaces by area (largest first) for better render performance
    final sortedAirspaces = [..._visibleAirspaces];
    sortedAirspaces.sort((a, b) {
      final aArea = _estimatePolygonArea(a.geometry);
      final bArea = _estimatePolygonArea(b.geometry);
      return bArea.compareTo(aArea);
    });

    final polygons = <Polygon>[];
    
    // Limit number of polygons based on zoom level to maintain performance
    final maxPolygons = _getMaxPolygonsForZoom(zoom);
    final airspacesToRender = sortedAirspaces.take(maxPolygons);

    for (final airspace in airspacesToRender) {
      final polygon = _buildOptimizedAirspacePolygon(airspace, zoom);
      if (polygon != null) {
        polygons.add(polygon);
      }
    }

    return polygons;
  }

  int _getMaxPolygonsForZoom(double zoom) {
    if (zoom >= 15) return 500;  // High detail
    if (zoom >= 12) return 300;  // Medium detail
    if (zoom >= 10) return 200;  // Low detail
    if (zoom >= 8) return 100;   // Very low detail
    return 50;                   // Minimal detail
  }

  Polygon? _buildOptimizedAirspacePolygon(Airspace airspace, double zoom) {
    if (airspace.geometry.isEmpty) return null;

    // Simplify polygons based on zoom level with caching
    final points = _simplifyPolygonWithCache(airspace, zoom);
    if (points.length < 3) return null;

    final isAtCurrentAltitude = airspace.isAtAltitude(widget.currentAltitude);
    final color = _getAirspaceColor(int.tryParse(airspace.type ?? '') ?? 0, int.tryParse(airspace.icaoClass ?? '') ?? 0);

    // Adjust transparency based on zoom and altitude
    final baseAlpha = isAtCurrentAltitude ? 0.5 : 0.15;
    final borderAlpha = isAtCurrentAltitude ? 0.9 : 0.5;
    
    // Reduce opacity at lower zoom levels to reduce visual clutter
    final zoomFactor = zoom < 10 ? 0.7 : 1.0;

    return Polygon(
      points: points,
      color: color.withValues(alpha: baseAlpha * zoomFactor),
      borderColor: color.withValues(alpha: borderAlpha * zoomFactor),
      borderStrokeWidth: isAtCurrentAltitude ? 2.0 : 1.0,
      hitValue: airspace,
    );
  }

  List<LatLng> _simplifyPolygonWithCache(Airspace airspace, double zoom) {
    // Create cache key based on airspace ID and zoom level
    final zoomLevel = zoom.round();
    final cacheKey = airspace.id.isNotEmpty
        ? airspace.id
        : airspace.hashCode.toString();

    // Check cache first
    if (_simplifiedPolygonsCache.containsKey(cacheKey)) {
      final zoomCache = _simplifiedPolygonsCache[cacheKey]!;
      if (zoomCache.containsKey(zoomLevel)) {
        return zoomCache[zoomLevel]!;
      }
    }

    // If not in cache, simplify and store
    final simplified = _simplifyPolygon(airspace.geometry, zoom);

    // Store in cache (limit cache size to prevent memory issues)
    if (_simplifiedPolygonsCache.length > 1000) {
      _simplifiedPolygonsCache.clear();
    }
    
    _simplifiedPolygonsCache.putIfAbsent(cacheKey, () => {});
    _simplifiedPolygonsCache[cacheKey]![zoomLevel] = simplified;

    return simplified;
  }

  List<LatLng> _simplifyPolygon(List<LatLng> points, double zoom) {
    if (points.length <= 3) return points;

    // Aggressive simplification based on zoom level
    double tolerance;
    if (zoom >= 16) {
      tolerance = 0.00001; // ~1m
    } else if (zoom >= 14) {
      tolerance = 0.00005; // ~5m
    } else if (zoom >= 12) {
      tolerance = 0.0001;  // ~10m
    } else if (zoom >= 10) {
      tolerance = 0.0005;  // ~50m
    } else if (zoom >= 8) {
      tolerance = 0.001;   // ~100m
    } else {
      tolerance = 0.005;   // ~500m
    }

    // Use Douglas-Peucker algorithm for line simplification
    return _douglasPeucker(points, tolerance);
  }

  List<LatLng> _douglasPeucker(List<LatLng> points, double epsilon) {
    if (points.length < 3) return points;

    // Find the point with the maximum distance
    double dmax = 0.0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double d = _perpendicularDistance(
        points[i],
        points[0],
        points[points.length - 1],
      );
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    // If max distance is greater than epsilon, recursively simplify
    if (dmax > epsilon) {
      // Recursive call
      List<LatLng> recResults1 = _douglasPeucker(
        points.sublist(0, index + 1),
        epsilon,
      );
      List<LatLng> recResults2 = _douglasPeucker(
        points.sublist(index),
        epsilon,
      );

      // Build the result list
      List<LatLng> result = [];
      result.addAll(recResults1.sublist(0, recResults1.length - 1));
      result.addAll(recResults2);
      return result;
    } else {
      return [points[0], points[points.length - 1]];
    }
  }

  double _estimatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    // Use simple bounding box area estimation for performance
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return (maxLat - minLat) * (maxLng - minLng);
  }

  double _perpendicularDistance(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    double x = point.longitude;
    double y = point.latitude;
    double x1 = lineStart.longitude;
    double y1 = lineStart.latitude;
    double x2 = lineEnd.longitude;
    double y2 = lineEnd.latitude;

    double A = x - x1;
    double B = y - y1;
    double C = x2 - x1;
    double D = y2 - y1;

    double dot = A * C + B * D;
    double lenSq = C * C + D * D;
    double param = -1;
    if (lenSq != 0) {
      param = dot / lenSq;
    }

    double xx, yy;

    if (param < 0) {
      xx = x1;
      yy = y1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
    } else {
      xx = x1 + param * C;
      yy = y1 + param * D;
    }

    double dx = x - xx;
    double dy = y - yy;
    return math.sqrt(dx * dx + dy * dy);
  }

  Color _getAirspaceColor(int type, int icaoClass) {
    return AirspaceUtils.getAirspaceColor(type, icaoClass);
  }
}