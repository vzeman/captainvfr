/// Runway model for OpenAIP data
class OpenAIPRunway {
  final String designator;
  final int? lengthM; // Length in meters
  final int? widthM; // Width in meters
  final RunwaySurface? surface;
  
  OpenAIPRunway({
    required this.designator,
    this.lengthM,
    this.widthM,
    this.surface,
  });
  
  factory OpenAIPRunway.fromJson(Map<String, dynamic> json) {
    return OpenAIPRunway(
      designator: json['des'] ?? '',
      lengthM: json['len'],
      widthM: json['wid'],
      surface: json['surf'] != null 
          ? RunwaySurface.fromJson(json['surf'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'des': designator,
      if (lengthM != null) 'len': lengthM,
      if (widthM != null) 'wid': widthM,
      if (surface != null) 'surf': surface!.toJson(),
    };
  }
  
  // Convert to feet for compatibility
  int get lengthFt => lengthM != null ? (lengthM! * 3.28084).round() : 0;
  int get widthFt => widthM != null ? (widthM! * 3.28084).round() : 0;
  
  String get lengthFormatted {
    if (lengthM == null) return 'N/A';
    if (lengthFt >= 1000) {
      return '${(lengthFt / 1000).toStringAsFixed(1)}k ft';
    }
    return '$lengthFt ft';
  }
  
  String get surfaceDescription => surface?.description ?? 'Unknown';
  
  // Extract heading from designator (e.g., "18" -> 180°, "36" -> 360°)
  int? get headingDegrees {
    final num = int.tryParse(designator.replaceAll(RegExp(r'[^0-9]'), ''));
    return num != null ? num * 10 : null;
  }
}

class RunwaySurface {
  final List<int> composition;
  final int mainComposite;
  final int condition;
  
  RunwaySurface({
    required this.composition,
    required this.mainComposite,
    required this.condition,
  });
  
  factory RunwaySurface.fromJson(Map<String, dynamic> json) {
    return RunwaySurface(
      composition: List<int>.from(json['composition'] ?? []),
      mainComposite: json['mainComposite'] ?? 0,
      condition: json['condition'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'composition': composition,
      'mainComposite': mainComposite,
      'condition': condition,
    };
  }
  
  String get description {
    // Map OpenAIP surface codes to descriptions
    switch (mainComposite) {
      case 1: return 'Asphalt';
      case 2: return 'Concrete';
      case 3: return 'Turf/Grass';
      case 4: return 'Gravel';
      case 5: return 'Packed dirt';
      case 6: return 'Water';
      case 7: return 'Bituminous';
      case 8: return 'Brick';
      case 9: return 'Macadam';
      case 10: return 'Stone';
      case 11: return 'Coral';
      case 12: return 'Clay';
      case 13: return 'Laterite';
      case 14: return 'Graded earth';
      case 15: return 'Snow';
      case 16: return 'Ice';
      case 17: return 'Salt';
      case 18: return 'Sand';
      case 19: return 'Shale';
      case 20: return 'Tarmac';
      case 21: return 'Treated';
      default: return 'Unknown';
    }
  }
  
  bool get isHardSurface {
    return [1, 2, 7, 8, 9, 10, 20].contains(mainComposite);
  }
}