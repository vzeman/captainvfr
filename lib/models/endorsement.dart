import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'endorsement.g.dart';

@HiveType(typeId: 50)
class Endorsement extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final DateTime validFrom;

  @HiveField(4)
  final DateTime? validTo;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  Endorsement({
    String? id,
    required this.title,
    required this.description,
    required this.validFrom,
    this.validTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get isValid {
    final now = DateTime.now();
    if (now.isBefore(validFrom)) return false;
    if (validTo != null && now.isAfter(validTo!)) return false;
    return true;
  }

  bool get isExpired {
    if (validTo == null) return false;
    return DateTime.now().isAfter(validTo!);
  }

  bool willExpireWithinDays(int days) {
    if (validTo == null) return false;
    final warningDate = DateTime.now().add(Duration(days: days));
    return warningDate.isAfter(validTo!) && !isExpired;
  }

  int? get daysUntilExpiration {
    if (validTo == null) return null;
    final difference = validTo!.difference(DateTime.now());
    return difference.inDays;
  }

  String get expirationStatus {
    if (validTo == null) return 'No expiration';
    if (isExpired) {
      return 'Expired ${-daysUntilExpiration!} days ago';
    } else if (daysUntilExpiration! <= 30) {
      return 'Expires in $daysUntilExpiration days';
    } else {
      return 'Valid';
    }
  }

  Endorsement copyWith({
    String? title,
    String? description,
    DateTime? validFrom,
    DateTime? validTo,
  }) {
    return Endorsement(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'validFrom': validFrom.toIso8601String(),
      'validTo': validTo?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Endorsement.fromJson(Map<String, dynamic> json) {
    return Endorsement(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      validFrom: DateTime.parse(json['validFrom']),
      validTo: json['validTo'] != null ? DateTime.parse(json['validTo']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}