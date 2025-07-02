import 'package:hive/hive.dart';
import 'airplane_type.dart';

part 'airplane.g.dart';

@HiveType(typeId: 23)
class Airplane extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name; // Can be call sign

  @HiveField(2)
  String manufacturerId;

  @HiveField(3)
  String airplaneTypeId;

  @HiveField(4)
  double cruiseSpeed; // in knots

  @HiveField(5)
  double fuelConsumption; // gallons per hour

  @HiveField(6)
  double maximumAltitude; // in feet

  @HiveField(7)
  double maximumClimbRate; // feet per minute

  @HiveField(8)
  double maximumDescentRate; // feet per minute

  @HiveField(9)
  double maxTakeoffWeight; // in pounds

  @HiveField(10)
  double maxLandingWeight; // in pounds

  @HiveField(11)
  double fuelCapacity; // in gallons

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
  AirplaneCategory? category;

  // Convenience getters for backward compatibility
  double get maxAltitude => maximumAltitude;
  double get maxClimbRate => maximumClimbRate;
  double get maxDescentRate => maximumDescentRate;

  Airplane({
    required this.id,
    required this.name,
    required this.manufacturerId,
    required this.airplaneTypeId,
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
      'airplane_type_id': airplaneTypeId,
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

  factory Airplane.fromMap(Map<String, dynamic> map) {
    return Airplane(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      manufacturerId: map['manufacturer_id'] ?? '',
      airplaneTypeId: map['airplane_type_id'] ?? '',
      cruiseSpeed: (map['cruise_speed'] ?? 0).toDouble(),
      fuelConsumption: (map['fuel_consumption'] ?? 0).toDouble(),
      maximumAltitude: (map['maximum_altitude'] ?? 0).toDouble(),
      maximumClimbRate: (map['maximum_climb_rate'] ?? 0).toDouble(),
      maximumDescentRate: (map['maximum_descent_rate'] ?? 0).toDouble(),
      maxTakeoffWeight: (map['max_takeoff_weight'] ?? 0).toDouble(),
      maxLandingWeight: (map['max_landing_weight'] ?? 0).toDouble(),
      fuelCapacity: (map['fuel_capacity'] ?? 0).toDouble(),
      registrationNumber: map['registration_number'],
      description: map['description'],
      callSign: map['call_sign'],
      registration: map['registration'],
      manufacturer: map['manufacturer'],
      model: map['model'],
      category: map['category'] != null ? AirplaneCategory.values[map['category']] : null,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Airplane copyWith({
    String? id,
    String? name,
    String? manufacturerId,
    String? airplaneTypeId,
    double? cruiseSpeed,
    double? fuelConsumption,
    double? maximumAltitude,
    double? maximumClimbRate,
    double? maximumDescentRate,
    double? maxTakeoffWeight,
    double? maxLandingWeight,
    double? fuelCapacity,
    String? registrationNumber,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? callSign,
    String? registration,
    String? manufacturer,
    String? model,
    AirplaneCategory? category,
  }) {
    return Airplane(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      airplaneTypeId: airplaneTypeId ?? this.airplaneTypeId,
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
