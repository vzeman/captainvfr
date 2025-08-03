/// Constants for the Flight Detail Screen
class FlightDetailConstants {
  // Drag sensitivity for resizing map/chart panels
  static const double dragSensitivity = 2.5;
  
  // Map height fraction limits (percentage of screen)
  static const double minMapHeightFraction = 0.15;
  static const double maxMapHeightFraction = 0.85;
  static const double defaultMapHeightFraction = 0.5;
  
  // Layout dimensions
  static const double dividerHeight = 16.0;
  static const double minPanelHeight = 60.0;
  
  // Marker dimensions
  static const double markerSize = 24.0;
  static const double markerIconSize = 8.0;
  static const double markerBorderWidth = 2.0;
  
  // Animation and timing
  static const int touchDebounceMilliseconds = 16; // ~60fps
  static const int mapFitDelayMilliseconds = 300;
  
  // Divider styling
  static const double dividerBorderWidth = 0.5;
  static const double dividerHandleRadius = 12.0;
  static const double dividerHandlePadding = 12.0;
  static const double dividerHandleIconSize = 16.0;
  static const double dividerHandleBarWidth = 3.0;
  static const double dividerHandleBarHeight = 10.0;
}