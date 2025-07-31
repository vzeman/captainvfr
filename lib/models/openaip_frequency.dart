/// Frequency model for OpenAIP data
class OpenAIPFrequency {
  final String airportIdent;
  final String type;
  final String? description;
  final double frequencyMhz;
  final String dataSource = 'openaip';
  
  OpenAIPFrequency({
    required this.airportIdent,
    required this.type,
    this.description,
    required this.frequencyMhz,
  });
  
  factory OpenAIPFrequency.fromJson(Map<String, dynamic> json, String airportIdent) {
    // OpenAIP frequency structure from airport details API
    return OpenAIPFrequency(
      airportIdent: airportIdent,
      type: _mapFrequencyType(json['type'] ?? ''),
      description: json['name'] ?? json['description'],
      frequencyMhz: _parseFrequency(json['frequency']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'airport_ident': airportIdent,
      'type': type,
      'description': description,
      'frequency_mhz': frequencyMhz,
      'data_source': dataSource,
    };
  }
  
  String get frequencyFormatted {
    return '${frequencyMhz.toStringAsFixed(3)} MHz';
  }
  
  /// Map OpenAIP frequency types to standard types used in the app
  static String _mapFrequencyType(String openAipType) {
    // Map OpenAIP frequency types to standard types
    // Based on OpenAIP documentation
    switch (openAipType.toUpperCase()) {
      case 'AFIS':
        return 'AFIS';
      case 'APP':
      case 'APPROACH':
        return 'APP';
      case 'ATIS':
        return 'ATIS';
      case 'AWOS':
        return 'AWOS';
      case 'CTR':
      case 'CONTROL':
        return 'CTR';
      case 'DEL':
      case 'DELIVERY':
        return 'DEL';
      case 'DEP':
      case 'DEPARTURE':
        return 'DEP';
      case 'FIS':
        return 'FIS';
      case 'FSS':
        return 'FSS';
      case 'GND':
      case 'GROUND':
        return 'GND';
      case 'INFO':
        return 'INFO';
      case 'MULTICOM':
        return 'MULTICOM';
      case 'RADAR':
        return 'RADAR';
      case 'RADIO':
        return 'RADIO';
      case 'TML':
      case 'TERMINAL':
        return 'TML';
      case 'TWR':
      case 'TOWER':
        return 'TWR';
      case 'UNICOM':
        return 'UNICOM';
      default:
        return openAipType.toUpperCase();
    }
  }
  
  /// Parse frequency from various formats (OpenAIP may provide as number or string)
  static double _parseFrequency(dynamic frequency) {
    if (frequency == null) return 0.0;
    
    if (frequency is num) {
      return frequency.toDouble();
    }
    
    if (frequency is String) {
      // Remove any non-numeric characters except decimal point
      final cleaned = frequency.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    
    return 0.0;
  }
  
  @override
  String toString() {
    return 'OpenAIPFrequency(airportIdent: $airportIdent, type: $type, description: $description, frequencyMhz: $frequencyMhz)';
  }
}