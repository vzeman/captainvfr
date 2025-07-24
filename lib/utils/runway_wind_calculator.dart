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
  /// Prioritizes headwind over crosswind with non-linear penalties
  double get score {
    // Penalize tailwind more heavily than we reward headwind
    final tailwindPenalty = isHeadwind ? 0 : headwindAbs * 2;
    
    // Non-linear crosswind penalty (squared) - more severe as crosswind increases
    // Normalize by 10 knots as a reference
    final crosswindPenalty = math.pow(crosswind / 10, 2).toDouble();
    
    // Calculate final score
    return headwind - (crosswindPenalty * 5) - tailwindPenalty;
  }
}

class RunwayWindCalculator {
  
  /// Calculate wind components for all runway directions at an airport
  static List<WindComponents> calculateWindComponentsForRunways(
    List<Runway> runways,
    double windDirection,
    double windSpeed,
  ) {
    // Validate inputs
    if (windSpeed < 0) {
      throw ArgumentError('Wind speed cannot be negative');
    }
    if (windDirection < 0 || windDirection > 360) {
      throw ArgumentError('Wind direction must be between 0 and 360 degrees');
    }
    
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
    
    // Convert to radians (keep the sign for proper calculation)
    double angleRad = angle * (math.pi / 180);
    
    // Calculate components
    double headwindComponent = windSpeed * math.cos(angleRad);
    double crosswindComponent = windSpeed * math.sin(angleRad);
    
    return WindComponents(
      headwind: headwindComponent,
      crosswind: crosswindComponent.abs(), // Make positive for display
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
      return {'direction': 0, 'speed': 0, 'gust': 0};
    }
    
    // Parse wind format: 12008KT or VRB05KT or 12008G18KT
    RegExp windRegex = RegExp(r'^(\d{3}|VRB)(\d{2,3})(G(\d{2,3}))?KT$');
    Match? match = windRegex.firstMatch(windString);
    
    if (match != null) {
      String direction = match.group(1)!;
      String speed = match.group(2)!;
      String? gust = match.group(4);
      
      // Variable wind direction - return -1 for direction
      if (direction == 'VRB') {
        return {
          'direction': -1, 
          'speed': double.parse(speed),
          'gust': gust != null ? double.parse(gust) : double.parse(speed),
        };
      }
      
      return {
        'direction': double.parse(direction),
        'speed': double.parse(speed),
        'gust': gust != null ? double.parse(gust) : double.parse(speed),
      };
    }
    
    return null;
  }
}