import 'dart:math' as math;
import '../models/runway.dart';

/// Represents wind components for a specific runway direction
class WindComponents {
  final double headwind; // Positive = headwind, Negative = tailwind
  final double crosswind; // Always positive
  final bool isHeadwind;
  final String runwayDesignation;
  final double runwayHeading;
  
  WindComponents({
    required this.headwind,
    required this.crosswind,
    required this.isHeadwind,
    required this.runwayDesignation,
    required this.runwayHeading,
  });
  
  /// Get the absolute headwind/tailwind value
  double get headwindAbs => headwind.abs();
  
  /// Get a score for runway selection (higher is better)
  /// Prioritizes headwind over crosswind
  double get score {
    // Headwind is good (positive score), tailwind is bad (negative score)
    // Crosswind always reduces the score
    return headwind - (crosswind * 0.5);
  }
}

class RunwayWindCalculator {
  
  /// Calculate wind components for all runway directions at an airport
  static List<WindComponents> calculateWindComponentsForRunways(
    List<Runway> runways,
    double windDirection,
    double windSpeed,
  ) {
    List<WindComponents> components = [];
    
    for (final runway in runways) {
      // Calculate for both runway directions
      if (runway.leHeadingDegT != null) {
        final leComponents = calculateWindComponents(
          runway.leHeadingDegT!,
          windDirection,
          windSpeed,
          runway.leIdent,
        );
        components.add(leComponents);
      }
      
      if (runway.heHeadingDegT != null) {
        final heComponents = calculateWindComponents(
          runway.heHeadingDegT!,
          windDirection,
          windSpeed,
          runway.heIdent,
        );
        components.add(heComponents);
      }
    }
    
    // Sort by score (best runway first)
    components.sort((a, b) => b.score.compareTo(a.score));
    
    return components;
  }
  
  /// Calculate wind components for a specific runway heading
  static WindComponents calculateWindComponents(
    double runwayHeading,
    double windDirection,
    double windSpeed,
    String runwayDesignation,
  ) {
    // Calculate the angle between runway and wind direction
    double angle = windDirection - runwayHeading;
    
    // Normalize to [-180, 180]
    while (angle > 180) {
      angle -= 360;
    }
    while (angle < -180) {
      angle += 360;
    }
    
    // Take absolute value for calculation
    angle = angle.abs();
    
    // Convert to radians
    double angleRad = angle * (math.pi / 180);
    
    // Calculate components
    double headwindComponent = windSpeed * math.cos(angleRad);
    double crosswindComponent = windSpeed * math.sin(angleRad).abs();
    
    return WindComponents(
      headwind: headwindComponent,
      crosswind: crosswindComponent,
      isHeadwind: headwindComponent > 0,
      runwayDesignation: runwayDesignation,
      runwayHeading: runwayHeading,
    );
  }
  
  /// Find the best runway for landing based on wind conditions
  static WindComponents? findBestRunway(
    List<Runway> runways,
    double windDirection,
    double windSpeed,
  ) {
    final components = calculateWindComponentsForRunways(
      runways,
      windDirection,
      windSpeed,
    );
    
    return components.isNotEmpty ? components.first : null;
  }
  
  /// Parse wind direction and speed from METAR wind string
  static Map<String, double>? parseMetarWind(String windString) {
    // Handle calm winds
    if (windString == '00000KT') {
      return {'direction': 0, 'speed': 0};
    }
    
    // Parse wind format: 12008KT or VRB05KT
    RegExp windRegex = RegExp(r'^(\d{3}|VRB)(\d{2,3})(G(\d{2,3}))?KT$');
    Match? match = windRegex.firstMatch(windString);
    
    if (match != null) {
      String direction = match.group(1)!;
      String speed = match.group(2)!;
      
      // Variable wind direction - return null for direction
      if (direction == 'VRB') {
        return {'direction': -1, 'speed': double.parse(speed)};
      }
      
      return {
        'direction': double.parse(direction),
        'speed': double.parse(speed),
      };
    }
    
    return null;
  }
}