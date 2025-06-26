import 'dart:convert';

class Frequency {
  final int id;
  final String airportIdent;
  final String type;
  final String? description;
  final double frequencyMhz;

  Frequency({
    required this.id,
    required this.airportIdent,
    required this.type,
    this.description,
    required this.frequencyMhz,
  });

  factory Frequency.fromCsv(String csvLine) {
    final values = csvLine.split(',');

    return Frequency(
      id: int.tryParse(values[0]) ?? 0,
      airportIdent: values[1].replaceAll('"', '').trim(),
      type: values[2].replaceAll('"', '').trim(),
      description: values.length > 3 && values[3].isNotEmpty
        ? values[3].replaceAll('"', '').trim()
        : null,
      frequencyMhz: double.tryParse(values[4]) ?? 0.0,
    );
  }

  factory Frequency.fromMap(Map<String, dynamic> map) {
    return Frequency(
      id: map['id'] ?? 0,
      airportIdent: map['airport_ident'] ?? '',
      type: map['type'] ?? '',
      description: map['description'],
      frequencyMhz: map['frequency_mhz']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'airport_ident': airportIdent,
      'type': type,
      'description': description,
      'frequency_mhz': frequencyMhz,
    };
  }

  String get frequencyFormatted {
    return '${frequencyMhz.toStringAsFixed(3)} MHz';
  }

  String toJson() => json.encode(toMap());

  factory Frequency.fromJson(String source) =>
      Frequency.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Frequency(id: $id, airportIdent: $airportIdent, type: $type, description: $description, frequencyMhz: $frequencyMhz)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Frequency &&
      other.id == id &&
      other.airportIdent == airportIdent &&
      other.type == type &&
      other.description == description &&
      other.frequencyMhz == frequencyMhz;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      airportIdent.hashCode ^
      type.hashCode ^
      description.hashCode ^
      frequencyMhz.hashCode;
  }
}
