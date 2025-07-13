import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/airspace.dart';
import '../utils/airspace_utils.dart';

class AirspacesOverlay extends StatelessWidget {
  final List<Airspace> airspaces;
  final bool showAirspacesLayer;
  final Function(Airspace)? onAirspaceTap;
  final double currentAltitude;

  const AirspacesOverlay({
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

    return PolygonLayer(
      polygons: airspaces
          .map((airspace) => _buildAirspacePolygon(airspace))
          .toList(),
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
