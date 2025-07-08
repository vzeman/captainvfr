import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/airspace.dart';
import '../utils/airspace_utils.dart';

class OptimizedAirspacesOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!showAirspacesLayer || airspaces.isEmpty) {
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
    
    for (final airspace in airspaces) {
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

    debugPrint('OptimizedAirspacesOverlay: ${visibleAirspaces.length} of ${airspaces.length} airspaces visible at zoom $zoom');

    // Render all visible airspaces regardless of zoom level
    return PolygonLayer(
      polygons: visibleAirspaces.map((airspace) => _buildAirspacePolygon(airspace)).toList(),
    );
  }

  Polygon _buildAirspacePolygon(Airspace airspace) {
    final isAtCurrentAltitude = airspace.isAtAltitude(currentAltitude);
    final color = _getAirspaceColor(airspace.type, airspace.icaoClass);
    
    return Polygon(
      points: airspace.geometry,
      color: color.withValues(alpha: isAtCurrentAltitude ? 0.3 : 0.1),
      borderColor: color.withValues(alpha: isAtCurrentAltitude ? 0.8 : 0.4),
      borderStrokeWidth: isAtCurrentAltitude ? 2.0 : 1.0,
      hitValue: airspace, // This enables tap detection
    );
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