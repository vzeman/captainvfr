import 'package:latlong2/latlong.dart';

class Notam {
  final String id;
  final String notamId; // NOTAM ID (e.g., "A1234/23")
  final String icaoCode; // Airport ICAO code
  final String? series; // Series (A, B, C, etc.)
  final String? number; // Number within series
  final String? year; // Year of issue
  final String? type; // Type of NOTAM (N=New, R=Replace, C=Cancel)
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil; // Can be null for permanent NOTAMs
  final String schedule; // Schedule/timesheet info
  final String text; // Full NOTAM text
  final String? decodedText; // Human-readable decoded text
  final String? purpose; // Purpose codes (e.g., NBO, BO, M)
  final String? scope; // Scope codes (e.g., A, AE, AW)
  final String? traffic; // Traffic type (I=IFR, V=VFR, IV=Both)
  final String? lowerLimit; // Lower altitude limit
  final String? upperLimit; // Upper altitude limit
  final LatLng? coordinates; // Location coordinates if applicable
  final double? radius; // Radius in NM if applicable
  final DateTime fetchedAt; // When this NOTAM was fetched
  final String? category; // Category for grouping (runway, taxiway, navaid, etc.)
  
  // Importance level based on purpose/scope
  NotamImportance get importance {
    if (purpose?.contains('M') == true) return NotamImportance.critical;
    if (scope?.contains('A') == true) return NotamImportance.high;
    if (traffic == 'IV') return NotamImportance.medium;
    return NotamImportance.low;
  }
  
  // Check if NOTAM is currently active
  bool get isActive {
    final now = DateTime.now().toUtc();
    if (now.isBefore(effectiveFrom)) return false;
    if (effectiveUntil != null && now.isAfter(effectiveUntil!)) return false;
    return true;
  }
  
  // Check if NOTAM is expired
  bool get isExpired {
    if (effectiveUntil == null) return false;
    return DateTime.now().toUtc().isAfter(effectiveUntil!);
  }
  
  // Check if NOTAM is future
  bool get isFuture {
    return DateTime.now().toUtc().isBefore(effectiveFrom);
  }
  
  // Get status string
  String get status {
    if (isExpired) return 'Expired';
    if (isFuture) return 'Future';
    if (isActive) return 'Active';
    return 'Unknown';
  }

  Notam({
    required this.id,
    required this.notamId,
    required this.icaoCode,
    this.series,
    this.number,
    this.year,
    this.type,
    required this.effectiveFrom,
    this.effectiveUntil,
    required this.schedule,
    required this.text,
    this.decodedText,
    this.purpose,
    this.scope,
    this.traffic,
    this.lowerLimit,
    this.upperLimit,
    this.coordinates,
    this.radius,
    required this.fetchedAt,
    this.category,
  });

  factory Notam.fromJson(Map<String, dynamic> json) {
    return Notam(
      id: json['id'] ?? '',
      notamId: json['notamId'] ?? '',
      icaoCode: json['icaoCode'] ?? '',
      series: json['series'],
      number: json['number'],
      year: json['year'],
      type: json['type'],
      effectiveFrom: DateTime.parse(json['effectiveFrom']),
      effectiveUntil: json['effectiveUntil'] != null 
          ? DateTime.parse(json['effectiveUntil']) 
          : null,
      schedule: json['schedule'] ?? '',
      text: json['text'] ?? '',
      decodedText: json['decodedText'],
      purpose: json['purpose'],
      scope: json['scope'],
      traffic: json['traffic'],
      lowerLimit: json['lowerLimit'],
      upperLimit: json['upperLimit'],
      coordinates: json['coordinates'] != null 
          ? LatLng(
              json['coordinates']['latitude'],
              json['coordinates']['longitude'],
            )
          : null,
      radius: json['radius']?.toDouble(),
      fetchedAt: DateTime.parse(json['fetchedAt']),
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notamId': notamId,
      'icaoCode': icaoCode,
      'series': series,
      'number': number,
      'year': year,
      'type': type,
      'effectiveFrom': effectiveFrom.toIso8601String(),
      'effectiveUntil': effectiveUntil?.toIso8601String(),
      'schedule': schedule,
      'text': text,
      'decodedText': decodedText,
      'purpose': purpose,
      'scope': scope,
      'traffic': traffic,
      'lowerLimit': lowerLimit,
      'upperLimit': upperLimit,
      'coordinates': coordinates != null 
          ? {
              'latitude': coordinates!.latitude,
              'longitude': coordinates!.longitude,
            }
          : null,
      'radius': radius,
      'fetchedAt': fetchedAt.toIso8601String(),
      'category': category,
    };
  }
}

enum NotamImportance {
  critical, // Safety critical (mandatory)
  high,     // Important operational
  medium,   // Standard operational
  low,      // Informational
}

// Helper to categorize NOTAMs
class NotamCategory {
  static const String runway = 'Runway';
  static const String taxiway = 'Taxiway';
  static const String apron = 'Apron';
  static const String navaid = 'Navaid';
  static const String airspace = 'Airspace';
  static const String obstacle = 'Obstacle';
  static const String services = 'Services';
  static const String other = 'Other';
  
  static String categorizeFromText(String text) {
    final upperText = text.toUpperCase();
    
    if (upperText.contains('RWY') || upperText.contains('RUNWAY')) {
      return runway;
    } else if (upperText.contains('TWY') || upperText.contains('TAXIWAY')) {
      return taxiway;
    } else if (upperText.contains('APRON') || upperText.contains('STAND')) {
      return apron;
    } else if (upperText.contains('VOR') || upperText.contains('ILS') || 
               upperText.contains('NDB') || upperText.contains('DME')) {
      return navaid;
    } else if (upperText.contains('AIRSPACE') || upperText.contains('TMA') || 
               upperText.contains('CTR') || upperText.contains('ATZ')) {
      return airspace;
    } else if (upperText.contains('OBST') || upperText.contains('CRANE')) {
      return obstacle;
    } else if (upperText.contains('FUEL') || upperText.contains('CUSTOMS') || 
               upperText.contains('IMMIGRATION')) {
      return services;
    }
    
    return other;
  }
}