import 'package:latlong2/latlong.dart';

class Runway {
  final int id;
  final String airportRef;
  final String airportIdent;
  final int lengthFt;
  final int? widthFt;
  final String surface;
  final bool lighted;
  final bool closed;
  final String leIdent;
  final double? leLatitude;
  final double? leLongitude;
  final int? leElevationFt;
  final double? leHeadingDegT;
  final int? leDisplacedThresholdFt;
  final String heIdent;
  final double? heLatitude;
  final double? heLongitude;
  final int? heElevationFt;
  final double? heHeadingDegT;
  final int? heDisplacedThresholdFt;

  Runway({
    required this.id,
    required this.airportRef,
    required this.airportIdent,
    required this.lengthFt,
    this.widthFt,
    required this.surface,
    required this.lighted,
    required this.closed,
    required this.leIdent,
    this.leLatitude,
    this.leLongitude,
    this.leElevationFt,
    this.leHeadingDegT,
    this.leDisplacedThresholdFt,
    required this.heIdent,
    this.heLatitude,
    this.heLongitude,
    this.heElevationFt,
    this.heHeadingDegT,
    this.heDisplacedThresholdFt,
  });

  /// Create a Runway from CSV row data
  factory Runway.fromCsvRow(List<String> row) {
    return Runway(
      id: int.tryParse(row[0]) ?? 0,
      airportRef: row[1],
      airportIdent: row[2],
      lengthFt: int.tryParse(row[3]) ?? 0,
      widthFt: row[4].isNotEmpty ? int.tryParse(row[4]) : null,
      surface: row[5],
      lighted: row[6] == '1',
      closed: row[7] == '1',
      leIdent: row[8],
      leLatitude: row[9].isNotEmpty ? double.tryParse(row[9]) : null,
      leLongitude: row[10].isNotEmpty ? double.tryParse(row[10]) : null,
      leElevationFt: row[11].isNotEmpty ? int.tryParse(row[11]) : null,
      leHeadingDegT: row[12].isNotEmpty ? double.tryParse(row[12]) : null,
      leDisplacedThresholdFt: row[13].isNotEmpty ? int.tryParse(row[13]) : null,
      heIdent: row[14],
      heLatitude: row[15].isNotEmpty ? double.tryParse(row[15]) : null,
      heLongitude: row[16].isNotEmpty ? double.tryParse(row[16]) : null,
      heElevationFt: row[17].isNotEmpty ? int.tryParse(row[17]) : null,
      heHeadingDegT: row[18].isNotEmpty ? double.tryParse(row[18]) : null,
      heDisplacedThresholdFt: row[19].isNotEmpty ? int.tryParse(row[19]) : null,
    );
  }

  /// Convert to Map for caching
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'airport_ref': airportRef,
      'airport_ident': airportIdent,
      'length_ft': lengthFt,
      'width_ft': widthFt,
      'surface': surface,
      'lighted': lighted,
      'closed': closed,
      'le_ident': leIdent,
      'le_latitude_deg': leLatitude,
      'le_longitude_deg': leLongitude,
      'le_elevation_ft': leElevationFt,
      'le_heading_degT': leHeadingDegT,
      'le_displaced_threshold_ft': leDisplacedThresholdFt,
      'he_ident': heIdent,
      'he_latitude_deg': heLatitude,
      'he_longitude_deg': heLongitude,
      'he_elevation_ft': heElevationFt,
      'he_heading_degT': heHeadingDegT,
      'he_displaced_threshold_ft': heDisplacedThresholdFt,
    };
  }

  /// Create from Map (for caching)
  factory Runway.fromMap(Map<String, dynamic> map) {
    return Runway(
      id: map['id'] ?? 0,
      airportRef: map['airport_ref'] ?? '',
      airportIdent: map['airport_ident'] ?? '',
      lengthFt: map['length_ft'] ?? 0,
      widthFt: map['width_ft'],
      surface: map['surface'] ?? '',
      lighted: map['lighted'] ?? false,
      closed: map['closed'] ?? false,
      leIdent: map['le_ident'] ?? '',
      leLatitude: map['le_latitude_deg']?.toDouble(),
      leLongitude: map['le_longitude_deg']?.toDouble(),
      leElevationFt: map['le_elevation_ft'],
      leHeadingDegT: map['le_heading_degT']?.toDouble(),
      leDisplacedThresholdFt: map['le_displaced_threshold_ft'],
      heIdent: map['he_ident'] ?? '',
      heLatitude: map['he_latitude_deg']?.toDouble(),
      heLongitude: map['he_longitude_deg']?.toDouble(),
      heElevationFt: map['he_elevation_ft'],
      heHeadingDegT: map['he_heading_degT']?.toDouble(),
      heDisplacedThresholdFt: map['he_displaced_threshold_ft'],
    );
  }

  /// Get runway designation (e.g., "09/27")
  String get designation => '$leIdent/$heIdent';

  /// Get runway length in meters
  double get lengthM => lengthFt * 0.3048;

  /// Get runway width in meters
  double? get widthM => widthFt != null ? widthFt! * 0.3048 : null;

  /// Get formatted length string
  String get lengthFormatted {
    if (lengthFt >= 1000) {
      return '${(lengthFt / 1000).toStringAsFixed(1)}k ft';
    }
    return '$lengthFt ft';
  }

  /// Get formatted surface string
  String get surfaceFormatted {
    switch (surface.toLowerCase()) {
      case 'asp':
      case 'asph':
        return 'Asphalt';
      case 'con':
      case 'conc':
        return 'Concrete';
      case 'grs':
      case 'grass':
        return 'Grass';
      case 'grv':
      case 'gravel':
        return 'Gravel';
      case 'dirt':
        return 'Dirt';
      case 'sand':
        return 'Sand';
      case 'water':
        return 'Water';
      default:
        return surface.isNotEmpty ? surface.toUpperCase() : 'Unknown';
    }
  }

  /// Check if runway has both ends with coordinates
  bool get hasCompleteCoordinates {
    return leLatitude != null &&
        leLongitude != null &&
        heLatitude != null &&
        heLongitude != null;
  }

  /// Get low end position if available
  LatLng? get lePosition {
    if (leLatitude != null && leLongitude != null) {
      return LatLng(leLatitude!, leLongitude!);
    }
    return null;
  }

  /// Get high end position if available
  LatLng? get hePosition {
    if (heLatitude != null && heLongitude != null) {
      return LatLng(heLatitude!, heLongitude!);
    }
    return null;
  }

  @override
  String toString() {
    return 'Runway($designation, $lengthFormatted, $surfaceFormatted)';
  }
}
