import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'runway.dart';
import 'openaip_runway.dart';
import '../utils/runway_utils.dart';

/// Unified runway model that combines data from multiple sources
class UnifiedRunway {
  final String airportIdent;
  final String designation; // e.g., "04/22" or "13/31"
  final int lengthFt;
  final int? widthFt;
  final String surface;
  final bool lighted;
  final bool closed;
  
  // Low end (LE) data
  final String leIdent;
  final double? leLatitude;
  final double? leLongitude;
  final int? leElevationFt;
  final double? leHeadingDegT;
  
  // High end (HE) data
  final String heIdent;
  final double? heLatitude;
  final double? heLongitude;
  final int? heElevationFt;
  final double? heHeadingDegT;
  
  // Source tracking
  final String dataSource; // 'ourairports', 'openaip', or 'merged'
  final Map<String, dynamic>? additionalData; // Store source-specific data
  
  UnifiedRunway({
    required this.airportIdent,
    required this.designation,
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
    required this.heIdent,
    this.heLatitude,
    this.heLongitude,
    this.heElevationFt,
    this.heHeadingDegT,
    required this.dataSource,
    this.additionalData,
  });
  
  /// Create from OurAirports Runway model
  factory UnifiedRunway.fromOurAirports(Runway runway) {
    return UnifiedRunway(
      airportIdent: runway.airportIdent,
      designation: runway.designation,
      lengthFt: runway.lengthFt,
      widthFt: runway.widthFt,
      surface: runway.surface,
      lighted: runway.lighted,
      closed: runway.closed,
      leIdent: runway.leIdent,
      leLatitude: runway.leLatitude,
      leLongitude: runway.leLongitude,
      leElevationFt: runway.leElevationFt,
      leHeadingDegT: runway.leHeadingDegT,
      heIdent: runway.heIdent,
      heLatitude: runway.heLatitude,
      heLongitude: runway.heLongitude,
      heElevationFt: runway.heElevationFt,
      heHeadingDegT: runway.heHeadingDegT,
      dataSource: 'ourairports',
      additionalData: {
        'id': runway.id,
        'displaced_threshold_ft': {
          'le': runway.leDisplacedThresholdFt,
          'he': runway.heDisplacedThresholdFt,
        },
      },
    );
  }
  
  /// Create from OpenAIP runway data
  factory UnifiedRunway.fromOpenAIP(
    Map<String, dynamic> data,
    String airportIdent,
  ) {
    // Extract operations for LE/HE data
    final operations = data['operations'] as List? ?? [];
    Map<String, dynamic>? leOp, heOp;
    
    for (final op in operations) {
      final des = op['des'] as String? ?? '';
      final desNum = RunwayUtils.extractRunwayNumber(des) ?? 0;
      
      if (desNum <= 18 && leOp == null) {
        leOp = op as Map<String, dynamic>;
      } else if (desNum > 18 && heOp == null) {
        heOp = op as Map<String, dynamic>;
      }
    }
    
    // If we don't have both ends, try to infer
    if (leOp == null && heOp != null) {
      leOp = _inferOppositeEnd(heOp);
    } else if (heOp == null && leOp != null) {
      heOp = _inferOppositeEnd(leOp);
    }
    
    // Extract dimensions
    final lengthM = data['length_m'] as int?;
    final widthM = data['width_m'] as int?;
    
    // Convert to feet
    final lengthFt = lengthM != null ? (lengthM * 3.28084).round() : 0;
    final widthFt = widthM != null ? (widthM * 3.28084).round() : null;
    
    // Extract surface
    final surfaceData = data['surface'] as Map<String, dynamic>?;
    final surface = _convertOpenAIPSurface(surfaceData);
    
    // Build designation
    final leIdent = leOp?['des'] as String? ?? '';
    final heIdent = heOp?['des'] as String? ?? '';
    final designation = '$leIdent/$heIdent';
    
    return UnifiedRunway(
      airportIdent: airportIdent,
      designation: designation,
      lengthFt: lengthFt,
      widthFt: widthFt,
      surface: surface,
      lighted: data['pilotCtrlLighting'] as bool? ?? false, // Use actual lighting data
      closed: false, // Assume open unless marked otherwise
      leIdent: leIdent,
      leLatitude: data['le_latitude'] as double?,
      leLongitude: data['le_longitude'] as double?,
      leElevationFt: null, // Not provided by OpenAIP
      leHeadingDegT: (leOp?['hdg'] as num?)?.toDouble(),
      heIdent: heIdent,
      heLatitude: data['he_latitude'] as double?,
      heLongitude: data['he_longitude'] as double?,
      heElevationFt: null,
      heHeadingDegT: (heOp?['hdg'] as num?)?.toDouble(),
      dataSource: 'openaip',
      additionalData: data,
    );
  }
  
  /// Create from OpenAIPRunway model (simplified version)
  factory UnifiedRunway.fromOpenAIPRunway(
    OpenAIPRunway runway,
    String airportIdent,
    {double? airportLat, double? airportLon}
  ) {
    // Extract runway ends from designator
    final parts = runway.designator.split('/');
    final leIdent = parts.isNotEmpty ? parts[0] : '';
    final heIdent = parts.length > 1 ? parts[1] : '';
    
    // Use actual heading if available, otherwise calculate from identifiers
    final leHeading = runway.trueHeading?.toDouble() ?? 
                      RunwayUtils.getHeadingFromDesignator(leIdent);
    final heHeading = leHeading != null ? (leHeading + 180) % 360 : 
                      RunwayUtils.getHeadingFromDesignator(heIdent);
    
    // Calculate runway end positions if we have airport position and runway length
    double? leLatitude = airportLat;
    double? leLongitude = airportLon;
    double? heLatitude;
    double? heLongitude;
    
    if (airportLat != null && airportLon != null && runway.lengthM != null && leHeading != null) {
      // Calculate runway endpoints from center
      // Assuming airport position is roughly at runway center
      const metersPerDegreeLat = 111319.0;
      final metersPerDegreeLon = 111319.0 * math.cos(airportLat * (math.pi / 180));
      
      final halfLengthM = runway.lengthM! / 2.0;
      final headingRad = leHeading * (math.pi / 180);
      
      // Calculate LE position (half runway length backwards from center)
      final leOffsetN = -halfLengthM * math.cos(headingRad) / metersPerDegreeLat;
      final leOffsetE = -halfLengthM * math.sin(headingRad) / metersPerDegreeLon;
      leLatitude = airportLat + leOffsetN;
      leLongitude = airportLon + leOffsetE;
      
      // Calculate HE position (half runway length forward from center)
      final heOffsetN = halfLengthM * math.cos(headingRad) / metersPerDegreeLat;
      final heOffsetE = halfLengthM * math.sin(headingRad) / metersPerDegreeLon;
      heLatitude = airportLat + heOffsetN;
      heLongitude = airportLon + heOffsetE;
    }
    
    return UnifiedRunway(
      airportIdent: airportIdent,
      designation: runway.designator,
      lengthFt: runway.lengthFt,
      widthFt: runway.widthFt,
      surface: runway.surfaceDescription,
      lighted: runway.pilotCtrlLighting ?? false, // Use actual lighting data, default to false if unknown
      closed: false, // Assume open
      leIdent: leIdent,
      leLatitude: leLatitude,
      leLongitude: leLongitude,
      leElevationFt: null,
      leHeadingDegT: leHeading,
      heIdent: heIdent,
      heLatitude: heLatitude,
      heLongitude: heLongitude,
      heElevationFt: null,
      heHeadingDegT: heHeading,
      dataSource: 'openaip_simple',
      additionalData: {
        'surface_details': runway.surface?.toJson(),
      },
    );
  }
  
  /// Merge data from multiple sources, preferring more complete data
  factory UnifiedRunway.merge(UnifiedRunway primary, UnifiedRunway secondary) {
    return UnifiedRunway(
      airportIdent: primary.airportIdent,
      designation: primary.designation,
      lengthFt: primary.lengthFt > 0 ? primary.lengthFt : secondary.lengthFt,
      widthFt: primary.widthFt ?? secondary.widthFt,
      surface: primary.surface.isNotEmpty ? primary.surface : secondary.surface,
      lighted: primary.lighted || secondary.lighted,
      closed: primary.closed && secondary.closed,
      leIdent: primary.leIdent,
      leLatitude: primary.leLatitude ?? secondary.leLatitude,
      leLongitude: primary.leLongitude ?? secondary.leLongitude,
      leElevationFt: primary.leElevationFt ?? secondary.leElevationFt,
      leHeadingDegT: primary.leHeadingDegT ?? secondary.leHeadingDegT,
      heIdent: primary.heIdent,
      heLatitude: primary.heLatitude ?? secondary.heLatitude,
      heLongitude: primary.heLongitude ?? secondary.heLongitude,
      heElevationFt: primary.heElevationFt ?? secondary.heElevationFt,
      heHeadingDegT: primary.heHeadingDegT ?? secondary.heHeadingDegT,
      dataSource: 'merged',
      additionalData: {
        'primary_source': primary.dataSource,
        'secondary_source': secondary.dataSource,
        'primary_data': primary.additionalData,
        'secondary_data': secondary.additionalData,
      },
    );
  }
  
  /// Check if this runway matches another (for deduplication)
  bool matches(UnifiedRunway other) {
    // Check if designations match (accounting for reversed order)
    final thisEnds = {leIdent, heIdent};
    final otherEnds = {other.leIdent, other.heIdent};
    
    if (thisEnds.intersection(otherEnds).length < 2) {
      return false;
    }
    
    // Check if lengths are similar (within 10%)
    final lengthDiff = (lengthFt - other.lengthFt).abs();
    final avgLength = (lengthFt + other.lengthFt) / 2;
    
    return lengthDiff / avgLength < 0.1;
  }
  
  /// Get position of runway center
  LatLng? get centerPosition {
    if (leLatitude != null && leLongitude != null) {
      if (heLatitude != null && heLongitude != null) {
        // Average of both ends
        return LatLng(
          (leLatitude! + heLatitude!) / 2,
          (leLongitude! + heLongitude!) / 2,
        );
      } else if (leHeadingDegT != null && lengthFt > 0) {
        // Calculate from LE position and heading
        const metersPerDegreeLat = 111319.0;
        final metersPerDegreeLon = 111319.0 * 
            math.cos((leLatitude != null ? leLatitude!.clamp(-89.9, 89.9) : 0.0).abs().toRadians());
        
        final lengthM = lengthFt * 0.3048;
        final headingRad = leHeadingDegT! * (3.14159 / 180);
        
        final offsetN = (lengthM / 2) * math.cos(headingRad) / metersPerDegreeLat;
        final offsetE = (lengthM / 2) * math.sin(headingRad) / metersPerDegreeLon;
        
        return LatLng(
          leLatitude! + offsetN,
          leLongitude! + offsetE,
        );
      }
    }
    return null;
  }
  
  /// Check if runway has position data
  bool get hasPosition => leLatitude != null && leLongitude != null;
  
  /// Check if runway has complete data
  bool get hasCompleteData => 
      hasPosition && 
      leHeadingDegT != null && 
      lengthFt > 0;
  
  /// Get formatted surface description
  String get surfaceDescription {
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
      case 'bit':
        return 'Bituminous';
      case 'tar':
        return 'Tarmac';
      default:
        return surface.isNotEmpty ? surface : 'Unknown';
    }
  }
  
  /// Convert to OurAirports Runway format
  Runway toRunway() {
    return Runway(
      id: additionalData?['id'] ?? designation.hashCode,
      airportRef: '',
      airportIdent: airportIdent,
      lengthFt: lengthFt,
      widthFt: widthFt,
      surface: surface,
      lighted: lighted,
      closed: closed,
      leIdent: leIdent,
      leLatitude: leLatitude,
      leLongitude: leLongitude,
      leElevationFt: leElevationFt,
      leHeadingDegT: leHeadingDegT,
      leDisplacedThresholdFt: additionalData?['displaced_threshold_ft']?['le'],
      heIdent: heIdent,
      heLatitude: heLatitude,
      heLongitude: heLongitude,
      heElevationFt: heElevationFt,
      heHeadingDegT: heHeadingDegT,
      heDisplacedThresholdFt: additionalData?['displaced_threshold_ft']?['he'],
    );
  }
  
  // Helper methods
  
  static Map<String, dynamic> _inferOppositeEnd(Map<String, dynamic> op) {
    final des = op['des'] as String? ?? '';
    final hdg = op['hdg'] as num?;
    
    // Calculate opposite designator (optimized)
    final oppositeDes = RunwayUtils.getOppositeDesignator(des);
    
    // Calculate opposite heading
    final oppositeHdg = hdg != null ? (hdg + 180) % 360 : null;
    
    return {
      'des': oppositeDes,
      'hdg': oppositeHdg,
    };
  }
  
  static String _convertOpenAIPSurface(Map<String, dynamic>? surfaceData) {
    if (surfaceData == null) return 'Unknown';
    
    final mainComposite = surfaceData['mainComposite'] as int? ?? 0;
    
    // Map OpenAIP codes to OurAirports-style surface descriptions
    switch (mainComposite) {
      case 1: return 'ASP'; // Asphalt
      case 2: return 'CON'; // Concrete
      case 3: return 'GRS'; // Grass
      case 4: return 'GRV'; // Gravel
      case 5: return 'DIRT'; // Packed dirt
      case 6: return 'WATER';
      case 7: return 'BIT'; // Bituminous
      case 20: return 'TAR'; // Tarmac
      default: return 'Unknown';
    }
  }
}

extension on double {
  double toRadians() => this * (3.14159 / 180);
}