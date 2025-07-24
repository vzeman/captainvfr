import 'package:flutter/material.dart';

class MapConstants {
  MapConstants._();

  // SharedPreferences keys
  static const String keyFlightPlanningExpanded = 'flight_planning_expanded';
  
  // Map operation constants
  static const double boundsPaddingFactor = 0.1;  // 10% padding for flight plan bounds
  static const double maxFitZoom = 16.0;          // Maximum zoom when fitting bounds
  static const double fitPadding = 50.0;          // Edge padding when fitting bounds
  static const double singlePointZoom = 14.0;     // Default zoom for single waypoint
  
  // Waypoint drop detection constants
  static const double baseSearchRadius = 2000.0;  // Base search radius at zoom 9 (meters)
  static const double searchRadiusZoomFactor = 0.5; // Halves radius per zoom level
  static const int searchRadiusZoomBase = 9;      // Base zoom level for radius calculation
  
  // Search radius lookup table by zoom level (precomputed for performance)
  static const Map<int, double> searchRadiusLookup = {
    5: 32000.0,   // 2000 * 0.5^(5-9) = 2000 * 16
    6: 16000.0,   // 2000 * 0.5^(6-9) = 2000 * 8
    7: 8000.0,    // 2000 * 0.5^(7-9) = 2000 * 4
    8: 4000.0,    // 2000 * 0.5^(8-9) = 2000 * 2
    9: 2000.0,    // 2000 * 0.5^(9-9) = 2000 * 1
    10: 1000.0,   // 2000 * 0.5^(10-9) = 2000 * 0.5
    11: 500.0,    // 2000 * 0.5^(11-9) = 2000 * 0.25
    12: 250.0,    // 2000 * 0.5^(12-9) = 2000 * 0.125
    13: 125.0,    // 2000 * 0.5^(13-9) = 2000 * 0.0625
    14: 62.5,     // 2000 * 0.5^(14-9) = 2000 * 0.03125
    15: 31.25,    // 2000 * 0.5^(15-9) = 2000 * 0.015625
    16: 15.625,   // 2000 * 0.5^(16-9) = 2000 * 0.0078125
    17: 7.8125,   // 2000 * 0.5^(17-9) = 2000 * 0.00390625
    18: 3.90625,  // 2000 * 0.5^(18-9) = 2000 * 0.001953125
  };
  
  // Map settings
  static const double initialZoom = 13.0;
  static const double minZoom = 4.0;
  static const double maxZoom = 18.0;
  
  // Auto-centering settings
  static const Duration autoCenteringDelay = Duration(minutes: 3);
  
  // Position tracking settings
  static const Duration positionUpdateInterval = Duration(seconds: 3);
  
  // Panel positions
  static const Offset defaultFlightDataPanelPosition = Offset(
    double.infinity, // We'll position from right side
    16.0, // Top padding  
  );
  
  static const Offset defaultAirspacePanelPosition = Offset(
    double.infinity, // Right side
    16.0, // Below flight data panel
  );
  
  static const Offset defaultFlightPlanningPanelPosition = Offset(
    16.0,  // Left padding
    120.0, // Below top controls
  );
  
  static const Offset defaultTogglePanelPosition = Offset(
    16.0,  // Left padding
    double.infinity, // Bottom aligned
  );
}

// Segment color and icon utilities
class SegmentUtils {
  SegmentUtils._();
  
  static Color getSegmentColor(String segmentType) {
    switch (segmentType) {
      case 'takeoff':
        return Colors.green;
      case 'landing':
        return Colors.red;
      case 'cruise':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  static IconData getSegmentIcon(String segmentType) {
    switch (segmentType) {
      case 'takeoff':
        return Icons.arrow_upward;
      case 'landing':
        return Icons.arrow_downward;
      case 'cruise':
        return Icons.flight;
      default:
        return Icons.circle;
    }
  }
}