import 'package:hive/hive.dart';
import 'model.dart';

part 'aircraft.g.dart';

@HiveType(typeId: 23)
class Aircraft extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // Can be call sign

  @HiveField(2)
  String manufacturerId;

  @HiveField(3)
  String modelId;

  @HiveField(4)
  int cruiseSpeed; // in knots

  @HiveField(5)
  double fuelConsumption; // gallons per hour

  @HiveField(6)
  int maximumAltitude; // in feet

  @HiveField(7)
  int maximumClimbRate; // feet per minute

  @HiveField(8)
  int maximumDescentRate; // feet per minute

  @HiveField(9)
  int maxTakeoffWeight; // in pounds

  @HiveField(10)
  int maxLandingWeight; // in pounds

  @HiveField(11)
  int fuelCapacity; // in gallons

  @HiveField(12)
  String? registrationNumber; // N-number or other registration

  @HiveField(13)
  String? description;

  @HiveField(14)
  DateTime createdAt;

  @HiveField(15)
  DateTime updatedAt;

  @HiveField(16)
  String? callSign;

  @HiveField(17)
  String? registration;

  @HiveField(18)
  String? manufacturer; // Manufacturer name for display

  @HiveField(19)
  String? model; // Model name for display

  @HiveField(20)
  AircraftCategory? category;

  // Convenience getters for backward compatibility
  double get maxAltitude => maximumAltitude.toDouble();
  double get maxClimbRate => maximumClimbRate.toDouble();
  double get maxDescentRate => maximumDescentRate.toDouble();

  Aircraft({
    required this.id,
    required this.name,
    required this.manufacturerId,
    required this.modelId,
    required this.cruiseSpeed,
    required this.fuelConsumption,
    required this.maximumAltitude,
    required this.maximumClimbRate,
    required this.maximumDescentRate,
    required this.maxTakeoffWeight,
    required this.maxLandingWeight,
    required this.fuelCapacity,
    required this.createdAt,
    required this.updatedAt,
    this.registrationNumber,
    this.description,
    this.callSign,
    this.registration,
    this.manufacturer,
    this.model,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'manufacturer_id': manufacturerId,
      'model_id': modelId,
      'cruise_speed': cruiseSpeed,
      'fuel_consumption': fuelConsumption,
      'maximum_altitude': maximumAltitude,
      'maximum_climb_rate': maximumClimbRate,
      'maximum_descent_rate': maximumDescentRate,
      'max_takeoff_weight': maxTakeoffWeight,
      'max_landing_weight': maxLandingWeight,
      'fuel_capacity': fuelCapacity,
      'registration_number': registrationNumber,
      'description': description,
      'call_sign': callSign,
      'registration': registration,
      'manufacturer': manufacturer,
      'model': model,
      'category': category?.index,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Aircraft.fromMap(Map<String, dynamic> map) {
    return Aircraft(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      manufacturerId: map['manufacturer_id'] ?? '',
      modelId: map['model_id'] ?? '',
      cruiseSpeed: map['cruise_speed']?.toInt() ?? 0,
      fuelConsumption: (map['fuel_consumption'] ?? 0).toDouble(),
      maximumAltitude: map['maximum_altitude']?.toInt() ?? 0,
      maximumClimbRate: map['maximum_climb_rate']?.toInt() ?? 0,
      maximumDescentRate: map['maximum_descent_rate']?.toInt() ?? 0,
      maxTakeoffWeight: map['max_takeoff_weight']?.toInt() ?? 0,
      maxLandingWeight: map['max_landing_weight']?.toInt() ?? 0,
      fuelCapacity: map['fuel_capacity']?.toInt() ?? 0,
      registrationNumber: map['registration_number'],
      description: map['description'],
      callSign: map['call_sign'],
      registration: map['registration'],
      manufacturer: map['manufacturer'],
      model: map['model'],
      category: map['category'] != null ? AircraftCategory.values[map['category']] : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Aircraft copyWith({
    String? id,
    String? name,
    String? manufacturerId,
    String? modelId,
    int? cruiseSpeed,
    double? fuelConsumption,
    int? maximumAltitude,
    int? maximumClimbRate,
    int? maximumDescentRate,
    int? maxTakeoffWeight,
    int? maxLandingWeight,
    int? fuelCapacity,
    String? registrationNumber,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? callSign,
    String? registration,
    String? manufacturer,
    String? model,
    AircraftCategory? category,
  }) {
    return Aircraft(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      modelId: modelId ?? this.modelId,
      cruiseSpeed: cruiseSpeed ?? this.cruiseSpeed,
      fuelConsumption: fuelConsumption ?? this.fuelConsumption,
      maximumAltitude: maximumAltitude ?? this.maximumAltitude,
      maximumClimbRate: maximumClimbRate ?? this.maximumClimbRate,
      maximumDescentRate: maximumDescentRate ?? this.maximumDescentRate,
      maxTakeoffWeight: maxTakeoffWeight ?? this.maxTakeoffWeight,
      maxLandingWeight: maxLandingWeight ?? this.maxLandingWeight,
      fuelCapacity: fuelCapacity ?? this.fuelCapacity,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      callSign: callSign ?? this.callSign,
      registration: registration ?? this.registration,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      category: category ?? this.category,
    );
  }
}
