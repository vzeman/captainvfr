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

  @HiveField(21)
  List<String>? photosPaths; // Paths to stored photos

  @HiveField(22)
  List<String>? documentsPaths; // Paths to stored documents

  // Performance data fields
  @HiveField(23)
  int? takeoffGroundRoll50ft; // in feet at sea level standard conditions

  @HiveField(24)
  int? takeoffOver50ft; // in feet at sea level standard conditions

  @HiveField(25)
  int? landingGroundRoll50ft; // in feet at sea level standard conditions

  @HiveField(26)
  int? landingOver50ft; // in feet at sea level standard conditions

  @HiveField(27)
  double? stallSpeedClean; // in knots (Vs1)

  @HiveField(28)
  double? stallSpeedLanding; // in knots (Vs0)

  @HiveField(29)
  int? serviceAboveCeiling; // in feet

  @HiveField(30)
  double? bestGlideSpeed; // in knots

  @HiveField(31)
  double? bestGlideRatio; // glide ratio (distance/altitude)

  @HiveField(32)
  double? vx; // best angle of climb speed in knots

  @HiveField(33)
  double? vy; // best rate of climb speed in knots

  @HiveField(34)
  double? va; // maneuvering speed in knots

  @HiveField(35)
  double? vno; // maximum structural cruising speed in knots

  @HiveField(36)
  double? vne; // never exceed speed in knots

  @HiveField(37)
  int? emptyWeight; // in pounds

  @HiveField(38)
  double? emptyWeightCG; // empty weight CG location in inches from datum

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
    this.photosPaths,
    this.documentsPaths,
    this.takeoffGroundRoll50ft,
    this.takeoffOver50ft,
    this.landingGroundRoll50ft,
    this.landingOver50ft,
    this.stallSpeedClean,
    this.stallSpeedLanding,
    this.serviceAboveCeiling,
    this.bestGlideSpeed,
    this.bestGlideRatio,
    this.vx,
    this.vy,
    this.va,
    this.vno,
    this.vne,
    this.emptyWeight,
    this.emptyWeightCG,
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
      'photos_paths': photosPaths,
      'documents_paths': documentsPaths,
      'takeoff_ground_roll_50ft': takeoffGroundRoll50ft,
      'takeoff_over_50ft': takeoffOver50ft,
      'landing_ground_roll_50ft': landingGroundRoll50ft,
      'landing_over_50ft': landingOver50ft,
      'stall_speed_clean': stallSpeedClean,
      'stall_speed_landing': stallSpeedLanding,
      'service_above_ceiling': serviceAboveCeiling,
      'best_glide_speed': bestGlideSpeed,
      'best_glide_ratio': bestGlideRatio,
      'vx': vx,
      'vy': vy,
      'va': va,
      'vno': vno,
      'vne': vne,
      'empty_weight': emptyWeight,
      'empty_weight_cg': emptyWeightCG,
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
      category: map['category'] != null
          ? AircraftCategory.values[map['category']]
          : null,
      photosPaths: (map['photos_paths'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      documentsPaths: (map['documents_paths'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      takeoffGroundRoll50ft: map['takeoff_ground_roll_50ft']?.toInt(),
      takeoffOver50ft: map['takeoff_over_50ft']?.toInt(),
      landingGroundRoll50ft: map['landing_ground_roll_50ft']?.toInt(),
      landingOver50ft: map['landing_over_50ft']?.toInt(),
      stallSpeedClean: (map['stall_speed_clean'] ?? 0).toDouble(),
      stallSpeedLanding: (map['stall_speed_landing'] ?? 0).toDouble(),
      serviceAboveCeiling: map['service_above_ceiling']?.toInt(),
      bestGlideSpeed: (map['best_glide_speed'] ?? 0).toDouble(),
      bestGlideRatio: (map['best_glide_ratio'] ?? 0).toDouble(),
      vx: (map['vx'] ?? 0).toDouble(),
      vy: (map['vy'] ?? 0).toDouble(),
      va: (map['va'] ?? 0).toDouble(),
      vno: (map['vno'] ?? 0).toDouble(),
      vne: (map['vne'] ?? 0).toDouble(),
      emptyWeight: map['empty_weight']?.toInt(),
      emptyWeightCG: (map['empty_weight_cg'] ?? 0).toDouble(),
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
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
    List<String>? photosPaths,
    List<String>? documentsPaths,
    int? takeoffGroundRoll50ft,
    int? takeoffOver50ft,
    int? landingGroundRoll50ft,
    int? landingOver50ft,
    double? stallSpeedClean,
    double? stallSpeedLanding,
    int? serviceAboveCeiling,
    double? bestGlideSpeed,
    double? bestGlideRatio,
    double? vx,
    double? vy,
    double? va,
    double? vno,
    double? vne,
    int? emptyWeight,
    double? emptyWeightCG,
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
      photosPaths: photosPaths ?? this.photosPaths,
      documentsPaths: documentsPaths ?? this.documentsPaths,
      takeoffGroundRoll50ft:
          takeoffGroundRoll50ft ?? this.takeoffGroundRoll50ft,
      takeoffOver50ft: takeoffOver50ft ?? this.takeoffOver50ft,
      landingGroundRoll50ft:
          landingGroundRoll50ft ?? this.landingGroundRoll50ft,
      landingOver50ft: landingOver50ft ?? this.landingOver50ft,
      stallSpeedClean: stallSpeedClean ?? this.stallSpeedClean,
      stallSpeedLanding: stallSpeedLanding ?? this.stallSpeedLanding,
      serviceAboveCeiling: serviceAboveCeiling ?? this.serviceAboveCeiling,
      bestGlideSpeed: bestGlideSpeed ?? this.bestGlideSpeed,
      bestGlideRatio: bestGlideRatio ?? this.bestGlideRatio,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      va: va ?? this.va,
      vno: vno ?? this.vno,
      vne: vne ?? this.vne,
      emptyWeight: emptyWeight ?? this.emptyWeight,
      emptyWeightCG: emptyWeightCG ?? this.emptyWeightCG,
    );
  }
}
