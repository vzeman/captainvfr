import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/airspace.dart';
import '../utils/airspace_utils.dart';

class OptimizedAirspacesOverlay extends StatefulWidget {
  final List<Airspace> airspaces;
  final bool showAirspacesLayer;
  final Function(Airspace)? onAirspaceTap;
  final double currentAltitude;

  const OptimizedAirspacesOverlay({
    super.key,
    required this.airspaces,
    required this.showAirspacesLayer,
    this.onAirspaceTap,
    this.currentAltitude = 0,
  });

  @override
  State<OptimizedAirspacesOverlay> createState() => _OptimizedAirspacesOverlayState();
}

class _OptimizedAirspacesOverlayState extends State<OptimizedAirspacesOverlay> {
  // Cache for simplified polygons at different zoom levels
  final Map<String, Map<int, List<LatLng>>> _simplifiedPolygonsCache = {};
  
  @override
  void didUpdateWidget(OptimizedAirspacesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear cache if airspaces changed
    if (oldWidget.airspaces.length != widget.airspaces.length) {
      _simplifiedPolygonsCache.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAirspacesLayer || widget.airspaces.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get map controller to check visible bounds
    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final bounds = mapController.camera.visibleBounds;
    final zoom = mapController.camera.zoom;
    
    // Add padding to bounds for smoother scrolling
    final paddedBounds = LatLngBounds(
      LatLng(
        bounds.southWest.latitude - 0.5,
        bounds.southWest.longitude - 0.5,
      ),
      LatLng(
        bounds.northEast.latitude + 0.5,
        bounds.northEast.longitude + 0.5,
      ),
    );

    // Filter airspaces to only those that might be visible
    final visibleAirspaces = <Airspace>[];
    
    for (final airspace in widget.airspaces) {
      // Quick check using cached bounding box
      final airspaceBounds = airspace.boundingBox;
      if (airspaceBounds == null) continue;
      
      // Check if bounding boxes intersect
      bool isVisible = !(airspaceBounds.northEast.latitude < paddedBounds.southWest.latitude || 
                        airspaceBounds.southWest.latitude > paddedBounds.northEast.latitude ||
                        airspaceBounds.northEast.longitude < paddedBounds.southWest.longitude || 
                        airspaceBounds.southWest.longitude > paddedBounds.northEast.longitude);
      
      if (isVisible) {
        visibleAirspaces.add(airspace);
      }
    }

    // Build polygons once and cache them
    // Sort by area (largest first) for better render performance
    visibleAirspaces.sort((a, b) {
      final aArea = _estimatePolygonArea(a.geometry);
      final bArea = _estimatePolygonArea(b.geometry);
      return bArea.compareTo(aArea);
    });
    
    final polygons = <Polygon>[];
    for (final airspace in visibleAirspaces) {
      final polygon = _buildOptimizedAirspacePolygon(airspace, zoom);
      if (polygon != null) {
        polygons.add(polygon);
      }
    }

    // Render all visible airspaces
    return PolygonLayer(
      polygons: polygons,
      polygonCulling: true, // Enable culling for better performance
    );
  }

  Polygon? _buildOptimizedAirspacePolygon(Airspace airspace, double zoom) {
    if (airspace.geometry.isEmpty) return null;
    
    // Simplify polygons based on zoom level
    final points = _simplifyPolygonWithCache(airspace, zoom);
    if (points.isEmpty) return null;
    
    final isAtCurrentAltitude = airspace.isAtAltitude(widget.currentAltitude);
    final color = _getAirspaceColor(airspace.type, airspace.icaoClass);
    
    return Polygon(
      points: points,
      color: color.withValues(alpha: isAtCurrentAltitude ? 0.3 : 0.1),
      borderColor: color.withValues(alpha: isAtCurrentAltitude ? 0.8 : 0.4),
      borderStrokeWidth: isAtCurrentAltitude ? 2.0 : 1.0,
      hitValue: airspace
    );
  }
  
  List<LatLng> _simplifyPolygonWithCache(Airspace airspace, double zoom) {
    // Create cache key based on airspace ID and zoom level
    final zoomLevel = zoom.round();
    final cacheKey = airspace.id ?? airspace.hashCode.toString();
    
    // Check cache first
    if (_simplifiedPolygonsCache.containsKey(cacheKey)) {
      final zoomCache = _simplifiedPolygonsCache[cacheKey]!;
      if (zoomCache.containsKey(zoomLevel)) {
        return zoomCache[zoomLevel]!;
      }
    }
    
    // If not in cache, simplify and store
    final simplified = _simplifyPolygon(airspace.geometry, zoom);
    
    // Store in cache
    _simplifiedPolygonsCache.putIfAbsent(cacheKey, () => {});
    _simplifiedPolygonsCache[cacheKey]![zoomLevel] = simplified;
    
    return simplified;
  }
  
  List<LatLng> _simplifyPolygon(List<LatLng> points, double zoom) {
    if (points.length <= 3) return points; // Can't simplify triangles
    
    // Calculate simplification tolerance based on zoom
    // Higher zoom = more detail, lower tolerance
    // Lower zoom = less detail, higher tolerance
    double tolerance;
    if (zoom >= 15) {
      tolerance = 0.00001; // ~1m at equator
    } else if (zoom >= 12) {
      tolerance = 0.00005; // ~5m at equator
    } else if (zoom >= 10) {
      tolerance = 0.0001; // ~10m at equator
    } else if (zoom >= 8) {
      tolerance = 0.0005; // ~50m at equator
    } else {
      tolerance = 0.001; // ~100m at equator
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
      double d = _perpendicularDistance(points[i], points[0], points[points.length - 1]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }
    
    // If max distance is greater than epsilon, recursively simplify
    if (dmax > epsilon) {
      // Recursive call
      List<LatLng> recResults1 = _douglasPeucker(points.sublist(0, index + 1), epsilon);
      List<LatLng> recResults2 = _douglasPeucker(points.sublist(index), epsilon);
      
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
  
  double _perpendicularDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
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
    return dx * dx + dy * dy;
  }


  Color _getAirspaceColor(String? type, String? icaoClass) {
    // Color coding based on airspace type and class
    final typeName = AirspaceUtils.getAirspaceTypeName(type);
    
    switch (typeName.toUpperCase()) {
      case 'CTR': // Control Zone
        return Colors.red;
      case 'TMA': // Terminal Maneuvering Area
        return Colors.orange;
      case 'ATZ': // Aerodrome Traffic Zone
        return Colors.blue;
      case 'D': // Class D
      case 'DANGER':
        return Colors.red.shade700;
      case 'P': // Prohibited
      case 'PROHIBITED':
        return Colors.red.shade900;
      case 'R': // Restricted
      case 'RESTRICTED':
        return Colors.orange.shade700;
      case 'TSA': // Temporary Segregated Area
        return Colors.purple;
      case 'TRA': // Temporary Reserved Area
        return Colors.purple.shade700;
      case 'GLIDING':
        return Colors.green;
      case 'WAVE':
        return Colors.cyan;
      case 'TMZ': // Transponder Mandatory Zone
        return Colors.amber;
      case 'RMZ': // Radio Mandatory Zone
        return Colors.yellow.shade700;
      default:
        // Check ICAO class if type doesn't match
        final className = AirspaceUtils.getIcaoClassName(icaoClass);
        if (className != 'Unclassified') {
          switch (className.toUpperCase()) {
            case 'A':
              return Colors.red.shade800;
            case 'B':
              return Colors.red.shade600;
            case 'C':
              return Colors.orange.shade600;
            case 'D':
              return Colors.blue.shade600;
            case 'E':
              return Colors.green.shade600;
            case 'F':
              return Colors.green.shade400;
            case 'G':
              return Colors.grey;
            default:
              return Colors.grey.shade600;
          }
        }
        return Colors.grey.shade600;
    }
  }
}