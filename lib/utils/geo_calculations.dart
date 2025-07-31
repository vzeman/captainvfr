import 'dart:math' as math;

/// Utility class for geographic calculations
class GeoCalculations {
  /// Calculate the true bearing from point 1 to point 2
  /// Returns bearing in degrees (0-360)
  static double calculateTrueBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Convert to radians
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final deltaLon = (lon2 - lon1) * math.pi / 180;

    // Calculate bearing using the forward azimuth formula
    final y = math.sin(deltaLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(deltaLon);

    // Convert from radians to degrees and normalize to 0-360
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Calculate the distance between two points using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final deltaLat = (lat2 - lat1) * math.pi / 180;
    final deltaLon = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}