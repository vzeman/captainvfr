import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../../../models/flight_point.dart';
import '../../../models/aircraft.dart';
import '../models/flight_constants.dart';

/// Handles calculations for flight metrics
class FlightCalculator {
  /// Calculate total distance of a flight path in meters
  static double calculateTotalDistance(List<FlightPoint> flightPath) {
    if (flightPath.length < 2) return 0.0;
    
    double distance = 0.0;
    for (int i = 1; i < flightPath.length; i++) {
      final prev = flightPath[i - 1];
      final current = flightPath[i];
      distance += Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );
    }
    return distance;
  }
  
  /// Calculate average speed from flight path in m/s
  static double calculateAverageSpeed(List<FlightPoint> flightPath) {
    if (flightPath.isEmpty) return 0.0;
    
    double totalSpeed = 0.0;
    for (final point in flightPath) {
      totalSpeed += point.speed;
    }
    return totalSpeed / flightPath.length;
  }
  
  /// Get maximum speed from flight path in m/s
  static double getMaxSpeed(List<FlightPoint> flightPath) {
    if (flightPath.isEmpty) return 0.0;
    return flightPath.map((p) => p.speed).reduce((a, b) => a > b ? a : b);
  }
  
  /// Calculate vertical speed in feet per minute
  static double calculateVerticalSpeed(List<FlightPoint> flightPath) {
    if (flightPath.length < 2) return 0.0;
    
    // Use up to last 3 points for smoothing
    int pointsToUse = math.min(3, flightPath.length);
    if (pointsToUse < 2) return 0.0;
    
    double totalVerticalSpeed = 0.0;
    int validMeasurements = 0;
    
    for (int i = flightPath.length - 1; i > flightPath.length - pointsToUse; i--) {
      final currentPoint = flightPath[i];
      final previousPoint = flightPath[i - 1];
      
      final altitudeDiff = currentPoint.altitude - previousPoint.altitude;
      final timeDiff = currentPoint.timestamp
          .difference(previousPoint.timestamp)
          .inMilliseconds / 1000.0; // Convert to seconds
      
      if (timeDiff > 0) {
        // Convert from m/s to feet/minute
        final verticalSpeedMps = altitudeDiff / timeDiff;
        final verticalSpeedFpm = verticalSpeedMps * FlightConstants.metersPerSecondToFeetPerMinute;
        totalVerticalSpeed += verticalSpeedFpm;
        validMeasurements++;
      }
    }
    
    return validMeasurements > 0 ? totalVerticalSpeed / validMeasurements : 0.0;
  }
  
  /// Calculate fuel consumption based on aircraft and time
  static double calculateFuelUsed(Aircraft? aircraft, Duration movingTime) {
    if (aircraft == null) return 0;
    final hours = movingTime.inMilliseconds / 3600000.0;
    return aircraft.fuelConsumption * hours;
  }
  
  /// Calculate moving time duration
  static Duration calculateMovingTime(DateTime? startTime, List<FlightPoint> flightPath, bool isTracking) {
    if (startTime == null) return Duration.zero;
    if (flightPath.isEmpty) {
      // If no flight path data, return time since start if tracking, otherwise zero
      return isTracking ? DateTime.now().difference(startTime) : Duration.zero;
    }
    final endTime = isTracking ? DateTime.now() : flightPath.last.timestamp;
    return endTime.difference(startTime);
  }
  
  /// Format duration as HH:MM:SS
  static String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
  
  /// Check if speed indicates movement
  static bool isMoving(double speedMps) {
    return speedMps >= FlightConstants.movingSpeedThreshold;
  }
  
  /// Check if heading change is significant
  static bool isSignificantHeadingChange(double oldHeading, double newHeading) {
    double diff = (newHeading - oldHeading).abs();
    if (diff > 180) {
      diff = 360 - diff;
    }
    return diff >= FlightConstants.significantHeadingChange;
  }
  
  /// Check if altitude change is significant
  static bool isSignificantAltitudeChange(double oldAltitude, double newAltitude) {
    return (newAltitude - oldAltitude).abs() >= FlightConstants.significantAltitudeChange;
  }
  
  /// Calculate distance between two points
  static double calculateDistance(FlightPoint point1, FlightPoint point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
}