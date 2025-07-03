import 'package:hive/hive.dart';

part 'manufacturer.g.dart';

@HiveType(typeId: 21)
class Manufacturer extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(3)
  String? website;

  @HiveField(4)
  List<String> airplaneTypes; // List of airplane type IDs

  @HiveField(5)
  String? description; // Add description field

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  Manufacturer({
    required this.id,
    required this.name,
    this.website,
    this.description, // Add description parameter
    List<String>? airplaneTypes,
    required this.createdAt,
    required this.updatedAt,
  }) : airplaneTypes = airplaneTypes ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'website': website,
      'airplane_types': airplaneTypes.join(','),
      'description': description, // Include description in toMap
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Manufacturer.fromMap(Map<String, dynamic> map) {
    return Manufacturer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      website: map['website'],
      description: map['description'], // Extract description from map
      airplaneTypes: map['airplane_types']?.split(',') ?? [],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Manufacturer copyWith({
    String? id,
    String? name,
    String? website,
    String? description, // Add description to copyWith
    List<String>? airplaneTypes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Manufacturer(
      id: id ?? this.id,
      name: name ?? this.name,
      website: website ?? this.website,
      description: description ?? this.description, // Include description in copyWith
      airplaneTypes: airplaneTypes ?? this.airplaneTypes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Add empty constructor for safe fallback
  factory Manufacturer.empty() {
    return Manufacturer(
      id: '',
      name: 'Unknown',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
