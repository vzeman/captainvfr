import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'openaip_runway.dart';
import '../utils/spatial_index.dart';

class Airport implements SpatialIndexable {
  final String icao;
  final String? iata;
  final String name;
  final String city;
  final String country;
  final LatLng position;
  final int elevation; // in feet

  // Additional details
  final String? website;
  final String? phone;
  final String? runways;
  final String? frequencies;
  final bool hasFuel;
  final bool hasCustoms;
  final String type; // small_airport, medium_airport, large_airport
  final String? icaoCode;
  final String? iataCode;
  final String? municipality;
  final String? region;
  final String? countryCode;
  final String? gpsCode;
  final String? localCode;

  Airport({
    required this.icao,
    this.iata,
    required this.name,
    required this.city,
    required this.country,
    required this.position,
    this.elevation = 0,
    this.website,
    this.phone,
    this.runways,
    this.frequencies,
    this.hasFuel = false,
    this.hasCustoms = false,
    this.type = 'small_airport',
    this.icaoCode,
    this.iataCode,
    this.municipality,
    this.region,
    this.countryCode,
    this.gpsCode,
    this.localCode,
  });

  // Position getters for compatibility with marker system
  double get latitude => position.latitude;
  double get longitude => position.longitude;

  @override
  String get uniqueId => icao;

  @override
  LatLngBounds? get boundingBox {
    // Airports are points, so create a small bounding box around the position
    const delta = 0.001; // Small delta for point features
    return LatLngBounds(
      LatLng(position.latitude - delta, position.longitude - delta),
      LatLng(position.latitude + delta, position.longitude + delta),
    );
  }

  @override
  bool containsPoint(LatLng point) {
    // For point features, check if the point is very close
    const tolerance = 0.001;
    return (point.latitude - position.latitude).abs() < tolerance &&
           (point.longitude - position.longitude).abs() < tolerance;
  }

  // Weather information
  String? rawMetar;
  String? taf;
  String? rawText; // For backward compatibility with marker system
  DateTime? lastWeatherUpdate;

  // Simple getters for common weather info
  String? get metarString => rawMetar;

  // Flight category (VFR, MVFR, IFR, LIFR) based on the METAR
  String? get flightCategory {
    if (rawMetar == null) return null;

    // First check for explicit flight category in the METAR
    if (rawMetar!.contains(' LIFR ')) return 'LIFR';
    if (rawMetar!.contains(' IFR ')) return 'IFR';
    if (rawMetar!.contains(' MVFR ')) return 'MVFR';
    if (rawMetar!.contains(' VFR ')) return 'VFR';

    // If not explicitly stated, try to determine from visibility and cloud cover
    final visibility = _parseVisibility();
    final cloudBase = _findLowestCloudBase();

    if (visibility != null && visibility < 1500) return 'LIFR';
    if ((visibility != null && visibility < 5000) ||
        (cloudBase != null && cloudBase < 1000)) {
      return 'IFR';
    }
    if ((visibility != null && visibility < 8000) ||
        (cloudBase != null && cloudBase < 3000)) {
      return 'MVFR';
    }

    return 'VFR';
  }

  factory Airport.fromJson(Map<String, dynamic> json) {
    return Airport(
      icao: (json['icao'] ?? json['ident'] ?? '').toString(),
      iata: json['iata']?.toString(),
      name: (json['name'] ?? 'Unknown Airport').toString(),
      city: (json['municipality'] ?? json['city'] ?? 'Unknown').toString(),
      country: (json['country_name'] ?? json['country'] ?? 'Unknown')
          .toString(),
      position: LatLng(
        (json['latitude_deg'] ?? json['latitude'] ?? 0.0).toDouble(),
        (json['longitude_deg'] ?? json['longitude'] ?? 0.0).toDouble(),
      ),
      elevation: (json['elevation_ft'] ?? json['elevation'] ?? 0).toInt(),
      website: json['home_link']?.toString() ?? json['website']?.toString(),
      phone: json['phone_number']?.toString() ?? json['phone']?.toString(),
      runways: json['runways']?.toString(),
      frequencies: json['frequencies']?.toString(),
      hasFuel:
          (json['fuel_types'] as String?)?.isNotEmpty ??
          json['fuel_available'] == true,
      hasCustoms:
          (json['customs'] as String?) == 'true' ||
          json['customs_airport'] == true,
      type: (json['type'] ?? 'small_airport').toString(),
      icaoCode: json['icao_code']?.toString(),
      iataCode: json['iata_code']?.toString(),
      municipality: json['municipality']?.toString(),
      region: (json['region_name'] ?? json['region'])?.toString(),
      countryCode: (json['iso_country'] ?? json['country_code'])?.toString(),
      gpsCode: json['gps_code']?.toString(),
      localCode: json['local_code']?.toString(),
    );
  }

  void updateWeather(String metar, {String? taf}) {
    rawMetar = metar;
    rawText = metar; // For backward compatibility
    this.taf = taf;
    lastWeatherUpdate = DateTime.now().toUtc();
  }

  // For backward compatibility with marker system
  bool get hasWeatherData => rawMetar != null || rawText != null;

  // Get airport type as a display string
  // Runway information
  List<Map<String, dynamic>> get runwaysList {
    if (runways == null) {
      return [];
    }
    if (runways!.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(runways!);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
  
  // Get OpenAIP runway objects (combined from individual ends)
  List<OpenAIPRunway> get openAIPRunways {
    final list = runwaysList;
    
    // OpenAIP stores runway ends separately, we need to combine them
    final runwayEnds = list.map((r) => OpenAIPRunway.fromJson(r)).toList();
    final combinedRunways = <OpenAIPRunway>[];
    final processedDesignators = <String>{};
    
    for (final runway in runwayEnds) {
      final designator = runway.designator;
      if (processedDesignators.contains(designator)) continue;
      
      // Find the opposite end
      final oppositeDesignator = _getOppositeRunwayDesignator(designator);
      final oppositeEnd = runwayEnds.firstWhere(
        (r) => r.designator == oppositeDesignator,
        orElse: () => runway, // If no opposite found, use same runway
      );
      
      // Create combined runway with proper designation
      final combinedDesignator = _formatRunwayPair(designator, oppositeDesignator);
      
      // Use the maximum dimensions from both ends
      final maxLength = [runway.lengthM ?? 0, oppositeEnd.lengthM ?? 0]
          .reduce((a, b) => a > b ? a : b);
      final maxWidth = [runway.widthM ?? 0, oppositeEnd.widthM ?? 0]
          .reduce((a, b) => a > b ? a : b);
      
      // Determine which is the lower-numbered end for correct heading
      final num1 = int.tryParse(designator.replaceAll(RegExp(r'[LRC]$'), '')) ?? 99;
      final num2 = int.tryParse(oppositeDesignator.replaceAll(RegExp(r'[LRC]$'), '')) ?? 99;
      final lowerEndHeading = num1 <= num2 ? runway.trueHeading : oppositeEnd.trueHeading;
      
      combinedRunways.add(OpenAIPRunway(
        airportIdent: icao,
        designator: combinedDesignator,
        lengthM: maxLength > 0 ? maxLength : null,
        widthM: maxWidth > 0 ? maxWidth : null,
        surface: runway.surface ?? oppositeEnd.surface,
        trueHeading: lowerEndHeading,
        pilotCtrlLighting: runway.pilotCtrlLighting ?? oppositeEnd.pilotCtrlLighting,
      ));
      
      processedDesignators.add(designator);
      processedDesignators.add(oppositeDesignator);
    }
    
    return combinedRunways;
  }
  
  // Helper to get opposite runway designator
  String _getOppositeRunwayDesignator(String designator) {
    // Remove any suffix letters
    final numericPart = designator.replaceAll(RegExp(r'[LRC]$'), '');
    final suffix = designator.length > numericPart.length 
        ? designator.substring(numericPart.length) : '';
    
    // Parse the numeric part
    final number = int.tryParse(numericPart);
    if (number == null) return designator;
    
    // Calculate opposite (add 18, wrap at 36)
    final opposite = number <= 18 ? number + 18 : number - 18;
    
    // Handle suffix for parallel runways
    final oppositeSuffix = suffix == 'L' ? 'R' : (suffix == 'R' ? 'L' : suffix);
    
    return opposite.toString().padLeft(2, '0') + oppositeSuffix;
  }
  
  // Helper to format runway pair designation
  String _formatRunwayPair(String end1, String end2) {
    // Ensure lower number comes first
    final num1 = int.tryParse(end1.replaceAll(RegExp(r'[LRC]$'), '')) ?? 99;
    final num2 = int.tryParse(end2.replaceAll(RegExp(r'[LRC]$'), '')) ?? 99;
    
    if (num1 <= num2) {
      return '$end1/$end2';
    } else {
      return '$end2/$end1';
    }
  }

  // Communication frequencies
  List<Map<String, dynamic>> get frequenciesList {
    if (frequencies == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(frequencies!);
      // Convert OpenAIP format to expected format
      return decoded.cast<Map<String, dynamic>>().map((f) {
        // Handle OpenAIP format - convert type codes even if frequency_mhz already exists
        if (f['value'] != null && f['frequency_mhz'] == null) {
          // Original OpenAIP format with 'value' field
          return {
            'frequency_mhz': double.tryParse(f['value'].toString()) ?? 0.0,
            'type': _convertOpenAIPFrequencyType(f['type']),
            'description': f['name']?.toString(),
            ...f, // Keep original fields
          };
        } else if (f['type'] != null) {
          // Check if type is numeric and convert it
          final typeStr = f['type'].toString();
          if (RegExp(r'^\d+$').hasMatch(typeStr)) {
            final convertedType = _convertOpenAIPFrequencyType(f['type']);
            return {
              ...f,
              'type': convertedType,
            };
          }
          // If not numeric, return as-is
          return f;
        }
        // Already in expected format with text type
        return f;
      }).where((f) => f['frequency_mhz'] != null && f['frequency_mhz'] > 0).toList();
    } catch (e) {
      return [];
    }
  }
  
  // Convert OpenAIP frequency type codes to readable types
  String _convertOpenAIPFrequencyType(dynamic type) {
    if (type == null) return 'UNKNOWN';
    
    // Debug: Print the actual type value to understand what's being passed
    // print('Converting frequency type: $type (${type.runtimeType})');
    
    // OpenAIP frequency type codes (based on common aviation frequencies)
    // Updated mapping based on actual KSFO data
    switch (type.toString()) {
      case '0': return 'NORCAL APP';  // Approach Control (NORCAL for San Francisco area)
      case '1': return 'AWOS';
      case '2': return 'AWIB';
      case '3': return 'AWIS';
      case '4': return 'CTAF';
      case '5': return 'MULTICOM';
      case '6': return 'UNICOM';
      case '7': return 'DELIVERY';
      case '8': return 'GROUND';
      case '9': return 'TOWER';
      case '10': return 'APPROACH';
      case '11': return 'DEPARTURE';
      case '12': return 'CENTER';
      case '13': return 'FSS';
      case '14': return 'CLEARANCE';
      case '15': return 'ATIS';        // ATIS Information
      default: return 'OTHER';
    }
  }

  // Get main frequency by type (TWR, GND, ATIS, etc.)
  String? getFrequencyByType(String type) {
    final freq = frequenciesList.firstWhere(
      (f) => f['type']?.toString().toLowerCase() == type.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );

    if (freq.isEmpty) return null;
    final mhz = double.tryParse(freq['frequency_mhz']?.toString() ?? '') ?? 0;
    if (mhz == 0) return null;

    // Format frequency to 3 decimal places
    return mhz.toStringAsFixed(3);
  }

  String? get typeDisplay {
    switch (type) {
      case 'small_airport':
        return 'Small Airport';
      case 'medium_airport':
        return 'Medium Airport';
      case 'large_airport':
        return 'Large Airport';
      case 'heliport':
        return 'Heliport';
      case 'seaplane_base':
        return 'Seaplane Base';
      default:
        return 'Airport';
    }
  }

  // Weather information getters
  String? get metarText => rawMetar;
  String? get tafText => taf;
  DateTime? get observationTime => lastWeatherUpdate;

  // Get wind information from raw METAR string
  String? get windInfo {
    if (rawMetar == null) return null;

    // Look for wind pattern like 36010KT or 36010G20KT
    final windMatch = RegExp(
      r'\b(\d{3}|VRB)(\d{2,3})(G(\d{2,3}))?KT\b',
    ).firstMatch(rawMetar!);
    if (windMatch == null) return null;

    final direction = windMatch.group(1);
    final speed = windMatch.group(2);
    final gust = windMatch.group(4);

    if (direction == 'VRB') {
      if (gust != null) {
        return 'VRB${speed}G$gust kt';
      }
      return 'VRB$speed kt';
    }

    if (gust != null) {
      return '$direction°${speed}G$gust kt';
    }
    return '$direction°$speed kt';
  }

  // Get visibility from raw METAR string
  String? get visibilityInfo {
    if (rawMetar == null) return null;

    // Look for visibility pattern like 9999 or 10SM
    final visMatch = RegExp(r'\b(\d{4})\b|\b(\d+)(SM)').firstMatch(rawMetar!);

    if (visMatch?.group(1) != null) {
      // Visibility in meters (e.g., 9999 = 10km+)
      final meters = int.tryParse(visMatch!.group(1)!);
      if (meters == null) return null;

      if (meters >= 10000) return '10km+';
      if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
      return '$meters m';
    } else if (visMatch?.group(2) != null && visMatch?.group(3) == 'SM') {
      // Visibility in statute miles (e.g., 10SM)
      return '${visMatch!.group(2)} SM';
    }

    return null;
  }

  // Get cloud cover information from raw METAR string
  String? get cloudCover {
    if (rawMetar == null) return null;

    final cloudMatches = RegExp(
      r'\b(FEW|SCT|BKN|OVC|NSC|NCD|VV)(\d{3}|///)\b',
    ).allMatches(rawMetar!);

    if (cloudMatches.isEmpty) return 'Clear';

    final cloudList = <String>[];

    for (final match in cloudMatches) {
      final type = match.group(1);
      final height = match.group(2);

      if (type == 'NSC' || type == 'NCD') {
        return 'No significant clouds';
      }

      if (type == 'VV') {
        if (height == '///') {
          cloudList.add('Vertical visibility unknown');
        } else {
          final heightFt = (int.tryParse(height!) ?? 0) * 100;
          cloudList.add('Vertical visibility $heightFt ft');
        }
        continue;
      }

      if (height == '///') continue;

      final heightFt = (int.tryParse(height!) ?? 0) * 100;
      String cloudType;

      switch (type) {
        case 'FEW':
          cloudType = 'Few';
          break;
        case 'SCT':
          cloudType = 'Scattered';
          break;
        case 'BKN':
          cloudType = 'Broken';
          break;
        case 'OVC':
          cloudType = 'Overcast';
          break;
        default:
          continue;
      }

      cloudList.add('$cloudType at $heightFt ft');
    }

    return cloudList.isEmpty ? 'Clear' : cloudList.join(', ');
  }

  // Get temperature from raw METAR string
  String? get temperature {
    if (rawMetar == null) return null;

    // Look for temperature pattern like 25/12 or M05/M10
    final tempMatch = RegExp(r'\b(M?\d{2})/(M?\d{2})\b').firstMatch(rawMetar!);
    if (tempMatch == null) return null;

    final tempStr = tempMatch.group(1)?.replaceAll('M', '-') ?? '';
    final temp = int.tryParse(tempStr);

    return temp != null ? '$temp°C' : null;
  }

  // Get dew point from raw METAR string
  String? get dewPoint {
    if (rawMetar == null) return null;

    // Look for temperature/dew point pattern like 25/12 or M05/M10
    final dpMatch = RegExp(r'\b(M?\d{2})/(M?\d{2})\b').firstMatch(rawMetar!);
    if (dpMatch == null || dpMatch.groupCount < 2) return null;

    final dpStr = (dpMatch.group(2) ?? '').replaceAll('M', '-');
    final dp = int.tryParse(dpStr);

    return dp != null ? '$dp°C' : null;
  }

  // Get altimeter setting from raw METAR string
  String? get altimeter {
    if (rawMetar == null) return null;

    // Look for QNH (hPa) or altimeter (inHg) setting
    final qnhMatch = RegExp(r'\bQ(\d{4})\b').firstMatch(rawMetar!);
    if (qnhMatch != null) {
      final hpa = int.tryParse(qnhMatch.group(1) ?? '');
      if (hpa != null) {
        final inHg = (hpa * 0.02953).toStringAsFixed(2);
        return 'Q$hpa ($inHg")';
      }
    }

    final altMatch = RegExp(r'\bA(\d{4})\b').firstMatch(rawMetar!);
    if (altMatch != null) {
      final inHg =
          '${altMatch.group(1)?.substring(0, 2)}.${altMatch.group(1)?.substring(2)}';
      final hpa = (double.tryParse(inHg) ?? 0) / 0.02953;
      return '${hpa.toStringAsFixed(0)} hPa ($inHg")';
    }

    return null;
  }

  // Get icon based on airport type
  String get iconAsset {
    switch (type) {
      case 'large_airport':
        return 'assets/icons/airport_large.png';
      case 'medium_airport':
        return 'assets/icons/airport_medium.png';
      case 'heliport':
        return 'assets/icons/heliport.png';
      case 'seaplane_base':
        return 'assets/icons/seaplane_base.png';
      case 'small_airport':
      default:
        return 'assets/icons/airport_small.png';
    }
  }

  // Helper method to parse visibility from METAR
  int? _parseVisibility() {
    if (rawMetar == null) return null;

    // Look for visibility pattern like 9999 or 10SM
    final visMatch = RegExp(r'\b(\d{4})\b|\b(\d+)(SM)').firstMatch(rawMetar!);

    if (visMatch?.group(1) != null) {
      // Visibility in meters (e.g., 9999 = 10km+)
      return int.tryParse(visMatch!.group(1)!);
    } else if (visMatch?.group(2) != null && visMatch?.group(3) == 'SM') {
      // Convert statute miles to meters (1 SM = 1609.34 m)
      final sm = int.tryParse(visMatch!.group(2)!);
      return sm != null ? (sm * 1609.34).round() : null;
    }

    return null;
  }

  // Helper method to find the lowest cloud base in feet
  int? _findLowestCloudBase() {
    if (rawMetar == null) return null;

    final cloudMatches = RegExp(
      r'\b(FEW|SCT|BKN|OVC)(\d{3})\b',
    ).allMatches(rawMetar!);
    if (cloudMatches.isEmpty) return null;

    int? lowestBase;

    for (final match in cloudMatches) {
      final heightStr = match.group(2);
      if (heightStr == null) continue;

      final height = int.tryParse(heightStr);
      if (height == null) continue;

      final heightFt = height * 100; // Convert to feet
      if (lowestBase == null || heightFt < lowestBase) {
        lowestBase = heightFt;
      }
    }

    return lowestBase;
  }

  // Check if weather data is stale (older than 1 hour)
  bool get isWeatherStale {
    if (lastWeatherUpdate == null) return true;
    return DateTime.now().difference(lastWeatherUpdate!) >
        const Duration(hours: 1);
  }
}
