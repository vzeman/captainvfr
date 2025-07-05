/// Utility functions for converting OpenAIP airspace numeric values to human-readable text
class AirspaceUtils {
  /// Convert numeric airspace type to human-readable text
  static String getAirspaceTypeName(String? type) {
    if (type == null) return 'Unknown';
    
    // If it's already a string name, return it
    if (!RegExp(r'^\d+$').hasMatch(type)) {
      return type;
    }
    
    // Convert numeric values to airspace types
    // Note: These mappings are based on common OpenAIP conventions
    // The exact mapping should be verified with OpenAIP documentation
    switch (type) {
      case '0':
        return 'CTR'; // Control Zone
      case '1':
        return 'TMA'; // Terminal Maneuvering Area
      case '2':
        return 'TMZ'; // Transponder Mandatory Zone
      case '3':
        return 'RMZ'; // Radio Mandatory Zone
      case '4':
        return 'ATZ'; // Aerodrome Traffic Zone
      case '5':
        return 'DANGER'; // Danger Area
      case '6':
        return 'PROHIBITED'; // Prohibited Area
      case '7':
        return 'RESTRICTED'; // Restricted Area
      case '8':
        return 'GLIDING'; // Gliding Area
      case '9':
        return 'WAVE'; // Wave Area
      case '10':
        return 'TSA'; // Temporary Segregated Area
      case '11':
        return 'TRA'; // Temporary Reserved Area
      case '12':
        return 'MATZ'; // Military Aerodrome Traffic Zone
      case '13':
        return 'AERIAL_SPORTING_RECREATIONAL';
      case '14':
        return 'WARNING';
      case '15':
        return 'TRAINING';
      case '16':
        return 'INFO'; // Flight Information Region
      default:
        return 'Type $type';
    }
  }

  /// Convert numeric ICAO class to letter designation
  static String getIcaoClassName(String? icaoClass) {
    if (icaoClass == null) return 'Unclassified';
    
    // If it's already a letter, return it
    if (!RegExp(r'^\d+$').hasMatch(icaoClass)) {
      return icaoClass;
    }
    
    // Convert numeric values to ICAO classes
    switch (icaoClass) {
      case '0':
        return 'A';
      case '1':
        return 'B';
      case '2':
        return 'C';
      case '3':
        return 'D';
      case '4':
        return 'E';
      case '5':
        return 'F';
      case '6':
        return 'G';
      default:
        return 'Class $icaoClass';
    }
  }

  /// Convert numeric activity type to human-readable text
  static String getActivityName(String? activity) {
    if (activity == null) return 'No specific activity';
    
    // If it's already a string name, return it
    if (!RegExp(r'^\d+$').hasMatch(activity)) {
      return activity;
    }
    
    // Convert numeric values to activity types
    // Note: These are estimated based on common aviation activities
    switch (activity) {
      case '0':
        return 'None';
      case '1':
        return 'Parachuting';
      case '2':
        return 'Hang gliding';
      case '3':
        return 'Paragliding';
      case '4':
        return 'Ballooning';
      case '5':
        return 'Gliding';
      case '6':
        return 'Aerobatics';
      case '7':
        return 'Model flying';
      case '8':
        return 'UAV/Drone operations';
      case '9':
        return 'Military operations';
      case '10':
        return 'Training';
      case '11':
        return 'Test flying';
      case '12':
        return 'Other aerial work';
      default:
        return 'Activity $activity';
    }
  }

  /// Get a description for the airspace type
  static String getAirspaceTypeDescription(String? type) {
    final typeName = getAirspaceTypeName(type);
    
    switch (typeName) {
      case 'CTR':
        return 'Control Zone - Controlled airspace around an airport';
      case 'TMA':
        return 'Terminal Maneuvering Area - Controlled airspace for approach/departure';
      case 'TMZ':
        return 'Transponder Mandatory Zone - Transponder required';
      case 'RMZ':
        return 'Radio Mandatory Zone - Radio contact required';
      case 'ATZ':
        return 'Aerodrome Traffic Zone - Traffic pattern area';
      case 'DANGER':
        return 'Danger Area - Activities dangerous to aircraft';
      case 'PROHIBITED':
        return 'Prohibited Area - Flight prohibited';
      case 'RESTRICTED':
        return 'Restricted Area - Permission required';
      case 'GLIDING':
        return 'Gliding Area - Glider operations';
      case 'WAVE':
        return 'Wave Area - Mountain wave soaring';
      case 'TSA':
        return 'Temporary Segregated Area';
      case 'TRA':
        return 'Temporary Reserved Area';
      case 'MATZ':
        return 'Military Aerodrome Traffic Zone';
      default:
        return typeName;
    }
  }

  /// Get the display name for altitude reference
  static String getAltitudeReferenceName(String? reference) {
    if (reference == null) return '';
    
    switch (reference.toUpperCase()) {
      case 'MSL':
      case '0':
      case '1':
        return 'MSL'; // Mean Sea Level
      case 'AGL':
      case '2':
        return 'AGL'; // Above Ground Level
      case 'FL':
      case '3':
        return 'FL'; // Flight Level
      default:
        return reference;
    }
  }
}