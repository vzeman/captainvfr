import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'pilot.g.dart';

@HiveType(typeId: 51)
class Pilot extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final DateTime? birthdate;

  @HiveField(3)
  final List<String> endorsementIds;

  @HiveField(4)
  final List<String> licenseIds;

  @HiveField(5)
  final bool isCurrentUser;

  @HiveField(6)
  final String? email;

  @HiveField(7)
  final String? phone;

  @HiveField(8)
  final String? certificateNumber;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final DateTime updatedAt;

  Pilot({
    String? id,
    required this.name,
    this.birthdate,
    List<String>? endorsementIds,
    List<String>? licenseIds,
    this.isCurrentUser = false,
    this.email,
    this.phone,
    this.certificateNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       endorsementIds = endorsementIds ?? [],
       licenseIds = licenseIds ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int? get age {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthdate!.year;
    if (now.month < birthdate!.month ||
        (now.month == birthdate!.month && now.day < birthdate!.day)) {
      age--;
    }
    return age;
  }

  Pilot copyWith({
    String? name,
    DateTime? birthdate,
    List<String>? endorsementIds,
    List<String>? licenseIds,
    bool? isCurrentUser,
    String? email,
    String? phone,
    String? certificateNumber,
  }) {
    return Pilot(
      id: id,
      name: name ?? this.name,
      birthdate: birthdate ?? this.birthdate,
      endorsementIds: endorsementIds ?? this.endorsementIds,
      licenseIds: licenseIds ?? this.licenseIds,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'birthdate': birthdate?.toIso8601String(),
      'endorsementIds': endorsementIds,
      'licenseIds': licenseIds,
      'isCurrentUser': isCurrentUser,
      'email': email,
      'phone': phone,
      'certificateNumber': certificateNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Pilot.fromJson(Map<String, dynamic> json) {
    return Pilot(
      id: json['id'],
      name: json['name'],
      birthdate: json['birthdate'] != null ? DateTime.parse(json['birthdate']) : null,
      endorsementIds: json['endorsementIds'] != null
          ? List<String>.from(json['endorsementIds'])
          : null,
      licenseIds: json['licenseIds'] != null
          ? List<String>.from(json['licenseIds'])
          : null,
      isCurrentUser: json['isCurrentUser'] ?? false,
      email: json['email'],
      phone: json['phone'],
      certificateNumber: json['certificateNumber'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}