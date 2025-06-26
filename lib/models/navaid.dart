import 'package:latlong2/latlong.dart';

/// Model for radio navigation aids (navaids)
class Navaid {
  final int id;
  final String filename;
  final String ident;
  final String name;
  final String type;
  final double frequencyKhz;
  final LatLng position;
  final int elevationFt;
  final String isoCountry;
  final double dmeFrequencyKhz;
  final String dmeChannel;
  final int dmeLatitudeDeg;
  final int dmeLongitudeDeg;
  final int dmeElevationFt;
  final double slavedVariationDeg;
  final double magneticVariationDeg;
  final String usageType;
  final double power;
  final String associatedAirport;

  Navaid({
    required this.id,
    required this.filename,
    required this.ident,
    required this.name,
    required this.type,
    required this.frequencyKhz,
    required this.position,
    required this.elevationFt,
    required this.isoCountry,
    required this.dmeFrequencyKhz,
    required this.dmeChannel,
    required this.dmeLatitudeDeg,
    required this.dmeLongitudeDeg,
    required this.dmeElevationFt,
    required this.slavedVariationDeg,
    required this.magneticVariationDeg,
    required this.usageType,
    required this.power,
    required this.associatedAirport,
  });

  /// Create Navaid from CSV line
  factory Navaid.fromCsv(String csvLine) {
    final parts = csvLine.split(',');
    if (parts.length < 19) {
      throw Exception('Invalid CSV line for navaid: insufficient columns');
    }

    return Navaid(
      id: int.tryParse(parts[0]) ?? 0,
      filename: parts[1].replaceAll('"', '').trim(),
      ident: parts[2].replaceAll('"', '').trim(),
      name: parts[3].replaceAll('"', '').trim(),
      type: parts[4].replaceAll('"', '').trim(),
      frequencyKhz: double.tryParse(parts[5]) ?? 0.0,
      position: LatLng(
        double.tryParse(parts[6]) ?? 0.0,
        double.tryParse(parts[7]) ?? 0.0,
      ),
      elevationFt: int.tryParse(parts[8]) ?? 0,
      isoCountry: parts[9].replaceAll('"', '').trim(),
      dmeFrequencyKhz: double.tryParse(parts[10]) ?? 0.0,
      dmeChannel: parts[11].replaceAll('"', '').trim(),
      dmeLatitudeDeg: int.tryParse(parts[12]) ?? 0,
      dmeLongitudeDeg: int.tryParse(parts[13]) ?? 0,
      dmeElevationFt: int.tryParse(parts[14]) ?? 0,
      slavedVariationDeg: double.tryParse(parts[15]) ?? 0.0,
      magneticVariationDeg: double.tryParse(parts[16]) ?? 0.0,
      usageType: parts[17].replaceAll('"', '').trim(),
      power: double.tryParse(parts[18]) ?? 0.0,
      associatedAirport: parts.length > 19 ? parts[19].replaceAll('"', '').trim() : '',
    );
  }

  /// Convert to Map for caching
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filename': filename,
      'ident': ident,
      'name': name,
      'type': type,
      'frequency_khz': frequencyKhz,
      'latitude_deg': position.latitude,
      'longitude_deg': position.longitude,
      'elevation_ft': elevationFt,
      'iso_country': isoCountry,
      'dme_frequency_khz': dmeFrequencyKhz,
      'dme_channel': dmeChannel,
      'dme_latitude_deg': dmeLatitudeDeg,
      'dme_longitude_deg': dmeLongitudeDeg,
      'dme_elevation_ft': dmeElevationFt,
      'slaved_variation_deg': slavedVariationDeg,
      'magnetic_variation_deg': magneticVariationDeg,
      'usage_type': usageType,
      'power': power,
      'associated_airport': associatedAirport,
    };
  }

  /// Create from Map (for caching)
  factory Navaid.fromMap(Map<String, dynamic> map) {
    return Navaid(
      id: map['id'] ?? 0,
      filename: map['filename'] ?? '',
      ident: map['ident'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      frequencyKhz: (map['frequency_khz'] ?? 0.0).toDouble(),
      position: LatLng(
        (map['latitude_deg'] ?? 0.0).toDouble(),
        (map['longitude_deg'] ?? 0.0).toDouble(),
      ),
      elevationFt: map['elevation_ft'] ?? 0,
      isoCountry: map['iso_country'] ?? '',
      dmeFrequencyKhz: (map['dme_frequency_khz'] ?? 0.0).toDouble(),
      dmeChannel: map['dme_channel'] ?? '',
      dmeLatitudeDeg: map['dme_latitude_deg'] ?? 0,
      dmeLongitudeDeg: map['dme_longitude_deg'] ?? 0,
      dmeElevationFt: map['dme_elevation_ft'] ?? 0,
      slavedVariationDeg: (map['slaved_variation_deg'] ?? 0.0).toDouble(),
      magneticVariationDeg: (map['magnetic_variation_deg'] ?? 0.0).toDouble(),
      usageType: map['usage_type'] ?? '',
      power: (map['power'] ?? 0.0).toDouble(),
      associatedAirport: map['associated_airport'] ?? '',
    );
  }

  /// Get frequency in MHz for display
  double get frequencyMhz => frequencyKhz / 1000.0;

  /// Get formatted display name for navaid type
  String get typeDisplay {
    switch (type.toUpperCase()) {
      case 'VOR':
        return 'VOR';
      case 'VORDME':
        return 'VOR/DME';
      case 'VORTAC':
        return 'VORTAC';
      case 'NDB':
        return 'NDB';
      case 'LOCATOR':
        return 'Locator';
      case 'TACAN':
        return 'TACAN';
      case 'DME':
        return 'DME';
      case 'ILS':
        return 'ILS';
      case 'LOC':
        return 'Localizer';
      case 'GS':
        return 'Glideslope';
      case 'OM':
        return 'Outer Marker';
      case 'MM':
        return 'Middle Marker';
      case 'IM':
        return 'Inner Marker';
      default:
        return type;
    }
  }

  /// Check if navaid has valid coordinates
  bool get hasValidPosition => position.latitude != 0.0 || position.longitude != 0.0;

  /// Get formatted elevation
  String get elevationFormatted => '$elevationFt ft';

  /// Check if navaid has DME
  bool get hasDme => dmeFrequencyKhz > 0 || dmeChannel.isNotEmpty;

  @override
  String toString() {
    return 'Navaid{ident: $ident, name: $name, type: $type, frequency: ${frequencyMhz}MHz}';
  }
}
