/// Constants used throughout flight tracking
class FlightConstants {
  // Physics constants
  static const double gravity = 9.80665; // Standard gravity (m/s²)
  
  // Movement detection thresholds
  static const double movingSpeedThreshold = 1.0 / 3.6; // 1 km/h in m/s
  static const double minSegmentDistance = 25.0; // Minimum 250m segment length
  static const double significantHeadingChange = 10.0; // 10 degrees
  static const double significantAltitudeChange = 30.0; // 30 meters
  
  // Sensor update rates
  static const Duration sensorSamplingPeriod = Duration(milliseconds: 100); // 10Hz
  static const Duration compassThrottleInterval = Duration(milliseconds: 500); // 2Hz
  static const int notifyThrottleMs = 250; // Max 4 updates per second
  
  // Conversion factors
  static const double metersToFeet = 3.28084;
  static const double metersPerSecondToKnots = 1.94384;
  static const double metersPerSecondToFeetPerMinute = 196.85;
  static const double hPaToInHg = 1 / 33.863886666667;
  
  // Default values
  static const double defaultPressureHPa = 1013.25;
}