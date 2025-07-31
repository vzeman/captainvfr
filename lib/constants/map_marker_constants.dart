/// Constants for map marker sizing and positioning
class MapMarkerConstants {
  // Navaid marker label constants
  static const double navaidLabelMinFontSize = 8.0; // Minimum readable font size
  static const double navaidLabelMaxFontSize = 14.0; // Maximum font size for clarity
  static const double navaidLabelBaseHighZoom = 11.0; // Base font at high zoom (was 11.0)
  static const double navaidLabelBaseLowZoom = 9.0; // Base font at low zoom (was 9.0)
  static const double navaidLabelScaleFactor = 0.75; // 25% reduction factor
  
  // Navaid label container dimensions
  static const double navaidLabelHeight = 22.5; // Height for label container
  static const double navaidLabelWidth = 60.0; // Width for label container
  static const double navaidLabelMinWidth = 44.0; // Minimum touch target width (Material Design)
  
  // Wind information positioning
  static const double windInfoMarkerHeight = 140.0; // Total marker height
  static const double windInfoBottomPadding = 90.0; // Padding from bottom
  static const double windInfoMinBottomPadding = 50.0; // Minimum padding to avoid overlap
  
  // Accessibility constants
  static const double minTouchTargetSize = 44.0; // Material Design minimum touch target
  static const double minReadableFontSize = 8.0; // Minimum font size for readability
  
  // Zoom level thresholds
  static const double navaidLabelShowZoom = 11.0; // Zoom level to show navaid labels
  static const double navaidHighDetailZoom = 12.0; // Zoom level for high detail
  static const double windInfoShowZoom = 9.0; // Minimum zoom to show wind info
}