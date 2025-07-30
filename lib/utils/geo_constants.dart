import 'dart:math' show cos, pow;

/// Geographic and conversion constants
class GeoConstants {
  /// Earth's circumference at the equator in meters
  static const double earthCircumferenceMeters = 40075016.686;
  
  /// Meters per degree of latitude (constant across the globe)
  static const double metersPerDegreeLat = 111319.0;
  
  /// Conversion factor from feet to meters
  static const double feetPerMeter = 3.28084;
  
  /// Conversion factor from meters to feet
  static const double metersPerFoot = 0.3048;
  
  /// Minimum runway length for label display (in feet)
  static const int minRunwayLengthForLabel = 3000;
  
  /// Minimum zoom level for runway visualization
  static const double minZoomForRunways = 10.0;
  
  /// Minimum zoom level for runway length labels
  static const double minZoomForLabels = 14.0;
  
  /// Calculate meters per degree of longitude at a given latitude
  static double metersPerDegreeLon(double latitude) {
    return metersPerDegreeLat * cos(latitude.toRadians());
  }
  
  /// Calculate meters per pixel for Web Mercator projection
  static double metersPerPixel(double latitude, double zoom) {
    return earthCircumferenceMeters * cos(latitude.toRadians()) / pow(2, zoom + 8);
  }
}

extension DoubleAngleExtension on double {
  double toRadians() => this * (3.14159265358979323846 / 180);
  double toDegrees() => this * (180 / 3.14159265358979323846);
}