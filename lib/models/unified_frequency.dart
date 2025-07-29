import 'frequency.dart';
import 'openaip_frequency.dart';

/// Unified frequency model that can represent data from multiple sources
class UnifiedFrequency {
  final String airportIdent;
  final String type;
  final String? description;
  final double frequencyMhz;
  final Set<String> dataSources;
  
  // Additional metadata
  final int? id; // From OurAirports
  final String? ourAirportsDescription;
  final String? openAIPDescription;
  
  UnifiedFrequency({
    required this.airportIdent,
    required this.type,
    this.description,
    required this.frequencyMhz,
    required this.dataSources,
    this.id,
    this.ourAirportsDescription,
    this.openAIPDescription,
  });
  
  /// Create from OurAirports frequency
  factory UnifiedFrequency.fromOurAirports(Frequency frequency) {
    return UnifiedFrequency(
      airportIdent: frequency.airportIdent,
      type: frequency.type,
      description: frequency.description,
      frequencyMhz: frequency.frequencyMhz,
      dataSources: {'ourairports'},
      id: frequency.id,
      ourAirportsDescription: frequency.description,
    );
  }
  
  /// Create from OpenAIP frequency
  factory UnifiedFrequency.fromOpenAIP(OpenAIPFrequency frequency) {
    return UnifiedFrequency(
      airportIdent: frequency.airportIdent,
      type: frequency.type,
      description: frequency.description,
      frequencyMhz: frequency.frequencyMhz,
      dataSources: {'openaip'},
      openAIPDescription: frequency.description,
    );
  }
  
  /// Merge two unified frequencies (preferring OurAirports data)
  static UnifiedFrequency merge(UnifiedFrequency primary, UnifiedFrequency secondary) {
    return UnifiedFrequency(
      airportIdent: primary.airportIdent,
      type: primary.type,
      description: primary.description ?? secondary.description,
      frequencyMhz: primary.frequencyMhz,
      dataSources: {...primary.dataSources, ...secondary.dataSources},
      id: primary.id ?? secondary.id,
      ourAirportsDescription: primary.ourAirportsDescription ?? secondary.ourAirportsDescription,
      openAIPDescription: primary.openAIPDescription ?? secondary.openAIPDescription,
    );
  }
  
  /// Check if two frequencies match (same type and frequency)
  bool matches(UnifiedFrequency other) {
    // Frequencies match if they have the same type and frequency (within tolerance)
    return type.toUpperCase() == other.type.toUpperCase() &&
           (frequencyMhz - other.frequencyMhz).abs() < 0.01;
  }
  
  /// Convert to standard Frequency model
  Frequency toFrequency() {
    return Frequency(
      id: id ?? 0,
      airportIdent: airportIdent,
      type: type,
      description: description,
      frequencyMhz: frequencyMhz,
    );
  }
  
  /// Get display description with data source indicators
  String get displayDescription {
    final desc = description ?? '';
    if (dataSources.length > 1) {
      return '$desc (${dataSources.join(', ')})';
    }
    return desc;
  }
  
  /// Get data source icon
  String get dataSourceIcon {
    if (dataSources.contains('ourairports') && dataSources.contains('openaip')) {
      return '🔄'; // Merged data
    } else if (dataSources.contains('openaip')) {
      return '🌐'; // OpenAIP
    } else {
      return '✈️'; // OurAirports
    }
  }
  
  @override
  String toString() {
    return 'UnifiedFrequency(airportIdent: $airportIdent, type: $type, frequencyMhz: $frequencyMhz, sources: ${dataSources.join(", ")})';
  }
}