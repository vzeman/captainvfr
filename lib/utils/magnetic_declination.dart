import 'dart:math' as math;

/// Magnetic declination calculator based on World Magnetic Model (WMM)
/// This is a simplified implementation that uses WMM2020 coefficients
/// Based on the geomagJS implementation by Christopher Weiss
class MagneticDeclination {
  // WMM2020 coefficients (valid 2020-2025)
  // Format: n, m, gnm, hnm, dgnm, dhnm
  static const List<List<double>> _wmm2020Coefficients = [
    [1, 0, -29404.5, 0.0, 6.7, 0.0],
    [1, 1, -1450.7, 4652.9, 7.7, -25.1],
    [2, 0, -2500.0, 0.0, -11.5, 0.0],
    [2, 1, 2982.0, -2991.6, -7.1, -30.2],
    [2, 2, 1676.8, -734.8, -2.2, -23.9],
    [3, 0, 1363.9, 0.0, 2.8, 0.0],
    [3, 1, -2381.0, -82.2, -6.2, 5.7],
    [3, 2, 1236.2, 241.8, 3.4, -1.0],
    [3, 3, 525.7, -542.9, -12.2, 1.1],
    [4, 0, 903.1, 0.0, -1.1, 0.0],
    [4, 1, 809.4, 282.0, -1.6, 0.2],
    [4, 2, 86.2, -158.4, -6.0, 6.9],
    [4, 3, -309.4, 199.8, 5.4, 3.7],
    [4, 4, 47.9, -350.1, -5.5, -5.6],
    [5, 0, -234.4, 0.0, -0.3, 0.0],
    [5, 1, 363.1, 47.7, 0.6, 0.1],
    [5, 2, 187.8, 208.4, -0.7, 2.5],
    [5, 3, -140.7, -121.3, 0.1, -0.9],
    [5, 4, -151.2, 32.2, 1.2, 3.0],
    [5, 5, 13.7, 99.1, 1.0, 0.5],
    [6, 0, 65.9, 0.0, -0.6, 0.0],
    [6, 1, 65.6, -19.1, -0.4, 0.1],
    [6, 2, 73.0, 25.0, 0.5, -1.8],
    [6, 3, -121.5, 52.7, 1.4, -1.4],
    [6, 4, -36.2, -64.4, -1.4, 0.9],
    [6, 5, 13.5, 9.0, -0.0, 0.1],
    [6, 6, -64.7, 68.1, 0.8, 1.0],
    [7, 0, 80.6, 0.0, -0.1, 0.0],
    [7, 1, -76.8, -51.4, -0.3, 0.5],
    [7, 2, -8.3, -16.8, -0.1, 0.6],
    [7, 3, 56.5, 2.3, 0.7, -0.7],
    [7, 4, 15.8, 23.5, 0.2, -0.2],
    [7, 5, 6.4, -2.2, -0.5, -1.2],
    [7, 6, -7.2, -27.2, -0.8, 0.2],
    [7, 7, 9.8, -1.9, 1.0, 0.3],
    [8, 0, 23.6, 0.0, -0.1, 0.0],
    [8, 1, 9.8, 8.4, 0.1, -0.3],
    [8, 2, -17.5, -15.3, -0.1, 0.7],
    [8, 3, -0.4, 12.8, 0.5, -0.2],
    [8, 4, -21.1, -11.8, -0.1, 0.5],
    [8, 5, 15.3, 14.9, 0.4, -0.3],
    [8, 6, 13.7, 3.6, 0.5, -0.5],
    [8, 7, -16.5, -6.9, 0.0, 0.4],
    [8, 8, -0.3, 2.8, 0.4, 0.1],
    [9, 0, 5.0, 0.0, -0.1, 0.0],
    [9, 1, 8.2, -23.3, -0.2, -0.3],
    [9, 2, 2.9, 11.1, -0.0, 0.2],
    [9, 3, -1.4, 9.8, 0.4, -0.4],
    [9, 4, -1.1, -5.1, -0.3, 0.4],
    [9, 5, -13.3, -6.2, -0.0, 0.1],
    [9, 6, 1.1, 7.8, 0.3, -0.0],
    [9, 7, 8.9, 0.4, -0.0, -0.2],
    [9, 8, -9.3, -1.5, -0.0, 0.5],
    [9, 9, -11.9, 9.7, -0.4, 0.2],
    [10, 0, -1.9, 0.0, 0.0, 0.0],
    [10, 1, -6.2, 3.4, -0.0, -0.0],
    [10, 2, -0.1, -0.2, -0.0, 0.1],
    [10, 3, 1.7, 3.5, 0.2, -0.3],
    [10, 4, -0.9, 4.8, -0.1, 0.1],
    [10, 5, 0.6, -8.6, -0.2, -0.2],
    [10, 6, -0.9, -0.1, -0.0, 0.1],
    [10, 7, 1.9, -4.2, -0.1, -0.0],
    [10, 8, 1.4, -3.4, -0.2, -0.1],
    [10, 9, -2.4, -0.1, -0.1, 0.2],
    [10, 10, -3.9, -8.8, -0.0, -0.0],
    [11, 0, 3.0, 0.0, -0.0, 0.0],
    [11, 1, -1.4, -0.0, -0.1, -0.0],
    [11, 2, -2.5, 2.6, -0.0, 0.1],
    [11, 3, 2.4, -0.5, 0.0, 0.0],
    [11, 4, -0.9, -0.4, -0.0, 0.2],
    [11, 5, 0.3, 0.6, -0.1, -0.0],
    [11, 6, -0.7, -0.2, 0.0, 0.0],
    [11, 7, -0.1, -1.7, -0.0, 0.1],
    [11, 8, 1.4, -1.6, -0.1, -0.0],
    [11, 9, -0.6, -3.0, -0.1, -0.1],
    [11, 10, 0.2, -2.0, -0.1, 0.0],
    [11, 11, 3.1, -2.6, -0.1, -0.0],
    [12, 0, -2.0, 0.0, 0.0, 0.0],
    [12, 1, -0.1, -1.2, -0.0, -0.0],
    [12, 2, 0.5, 0.5, -0.0, 0.0],
    [12, 3, 1.3, 1.3, 0.0, -0.1],
    [12, 4, -1.2, -1.8, -0.0, 0.1],
    [12, 5, 0.7, 0.1, -0.0, -0.0],
    [12, 6, 0.3, 0.7, 0.0, 0.0],
    [12, 7, 0.5, -0.1, -0.0, -0.0],
    [12, 8, -0.2, 0.6, 0.0, 0.1],
    [12, 9, -0.5, 0.2, -0.0, -0.0],
    [12, 10, 0.1, -0.9, -0.0, -0.0],
    [12, 11, -1.1, -0.0, -0.0, 0.0],
    [12, 12, -0.3, 0.5, -0.1, -0.1],
  ];

  static const double _epoch = 2020.0;
  static const int _maxDegree = 12;
  
  // Earth parameters
  // static const double _earthRadiusKm = 6371.2; // Not used in simplified calculation
  // static const double _wgs84a = 6378.137; // WGS84 semi-major axis - not used in simplified calculation
  // static const double _wgs84b = 6356.7523142; // WGS84 semi-minor axis - not used in simplified calculation

  /// Calculate magnetic declination for a given location and date
  /// 
  /// [latitude] - Latitude in decimal degrees (north positive)
  /// [longitude] - Longitude in decimal degrees (east positive)
  /// [altitude] - Altitude in meters above sea level (default: 0)
  /// [date] - Date for calculation (default: current date)
  /// 
  /// Returns magnetic declination in degrees (east positive)
  static double calculate(
    double latitude,
    double longitude, {
    double altitude = 0,
    DateTime? date,
  }) {
    date ??= DateTime.now();
    
    // Convert to radians
    final latRad = latitude * math.pi / 180;
    final lonRad = longitude * math.pi / 180;
    
    // Calculate decimal year
    final year = date.year;
    final daysInYear = _isLeapYear(year) ? 366 : 365;
    final dayOfYear = date.difference(DateTime(year, 1, 1)).inDays + 1;
    final decimalYear = year + (dayOfYear - 1) / daysInYear;
    
    // Time since epoch
    final dt = decimalYear - _epoch;
    
    // Convert altitude to km (not used in simplified calculation)
    // final altKm = altitude / 1000.0;
    
    // Initialize coefficients arrays
    final c = List.generate(_maxDegree + 1, (_) => List.filled(_maxDegree + 1, 0.0));
    final cd = List.generate(_maxDegree + 1, (_) => List.filled(_maxDegree + 1, 0.0));
    
    // Load coefficients
    for (final coef in _wmm2020Coefficients) {
      final n = coef[0].toInt();
      final m = coef[1].toInt();
      final gnm = coef[2];
      final hnm = coef[3];
      final dgnm = coef[4];
      final dhnm = coef[5];
      
      c[m][n] = gnm + dt * dgnm;
      if (m != 0) {
        c[n][m - 1] = hnm + dt * dhnm;
      }
      cd[m][n] = dgnm;
      if (m != 0) {
        cd[n][m - 1] = dhnm;
      }
    }
    
    // Calculate field components
    final sinLat = math.sin(latRad);
    final cosLat = math.cos(latRad);
    final sinLon = math.sin(lonRad);
    final cosLon = math.cos(lonRad);
    
    // Geodetic to spherical coordinates (not used in simplified calculation)
    // final a2 = _wgs84a * _wgs84a;
    // final b2 = _wgs84b * _wgs84b;
    // final u2 = cosLat * cosLat * a2 + sinLat * sinLat * b2;

    // Radius at location (not used in simplified calculation)
    // final r = math.sqrt(altKm * altKm + 2 * altKm * math.sqrt(u2) + 
    //                    (a2 * a2 * cosLat * cosLat + b2 * b2 * sinLat * sinLat) / u2);

    // Simplified calculation for declination only
    // This is a very simplified version focusing on the main dipole terms
    final g10 = c[0][1];
    final g11 = c[1][1];
    final h11 = c[1][0];  // This should be c[1][0], not c[0][1]
    
    // Calculate horizontal components
    final bx = -g10 * cosLat - (g11 * cosLon + h11 * sinLon) * sinLat;
    final by = g11 * sinLon - h11 * cosLon;
    
    // Calculate declination
    final declination = math.atan2(by, bx) * 180 / math.pi;
    
    return declination;
  }
  
  /// Calculate magnetic variation (alias for declination)
  static double calculateVariation(
    double latitude,
    double longitude, {
    double altitude = 0,
    DateTime? date,
  }) {
    return calculate(latitude, longitude, altitude: altitude, date: date);
  }
  
  /// Convert magnetic heading to true heading
  /// 
  /// For map display purposes:
  /// True = Magnetic - Declination
  /// This aligns the runway with the true north grid on the map
  static double magneticToTrue(double magneticHeading, double declination) {
    return (magneticHeading - declination + 360) % 360;
  }
  
  /// Convert true heading to magnetic heading
  /// 
  /// For map display purposes:
  /// Magnetic = True + Declination
  static double trueToMagnetic(double trueHeading, double declination) {
    return (trueHeading + declination + 360) % 360;
  }
  
  static bool _isLeapYear(int year) {
    return (year % 400 == 0) || (year % 4 == 0 && year % 100 != 0);
  }
}