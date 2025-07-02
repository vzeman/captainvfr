import 'package:hive/hive.dart';

part 'airplane_type.g.dart';

@HiveType(typeId: 24)
enum AirplaneCategory {
  @HiveField(0)
  singleEngine,
  @HiveField(1)
  multiEngine,
  @HiveField(2)
  jet,
  @HiveField(3)
  helicopter,
  @HiveField(4)
  glider,
  @HiveField(5)
  turboprop,
}

@HiveType(typeId: 22)
class AirplaneType extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String manufacturerId;

  @HiveField(3)
  AirplaneCategory category;

  @HiveField(4)
  int engineCount;

  @HiveField(5)
  int maxSeats;

  @HiveField(6)
  double typicalCruiseSpeed; // in knots

  @HiveField(7)
  double typicalServiceCeiling; // in feet

  @HiveField(8)
  String? description;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  AirplaneType({
    required this.id,
    required this.name,
    required this.manufacturerId,
    required this.category,
    required this.engineCount,
    required this.maxSeats,
    required this.typicalCruiseSpeed,
    required this.typicalServiceCeiling,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'manufacturer_id': manufacturerId,
      'category': category.index,
      'engine_count': engineCount,
      'max_seats': maxSeats,
      'typical_cruise_speed': typicalCruiseSpeed,
      'typical_service_ceiling': typicalServiceCeiling,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AirplaneType.fromMap(Map<String, dynamic> map) {
    return AirplaneType(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      manufacturerId: map['manufacturer_id'] ?? '',
      category: AirplaneCategory.values[map['category'] ?? 0],
      engineCount: map['engine_count'] ?? 1,
      maxSeats: map['max_seats'] ?? 2,
      typicalCruiseSpeed: (map['typical_cruise_speed'] ?? 0).toDouble(),
      typicalServiceCeiling: (map['typical_service_ceiling'] ?? 0).toDouble(),
      description: map['description'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  AirplaneType copyWith({
    String? id,
    String? name,
    String? manufacturerId,
    AirplaneCategory? category,
    int? engineCount,
    int? maxSeats,
    double? typicalCruiseSpeed,
    double? typicalServiceCeiling,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AirplaneType(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      category: category ?? this.category,
      engineCount: engineCount ?? this.engineCount,
      maxSeats: maxSeats ?? this.maxSeats,
      typicalCruiseSpeed: typicalCruiseSpeed ?? this.typicalCruiseSpeed,
      typicalServiceCeiling: typicalServiceCeiling ?? this.typicalServiceCeiling,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
