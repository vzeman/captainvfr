import 'package:uuid/uuid.dart';

class License {
  final String id;
  final String name;
  final String description;
  final DateTime issueDate;
  final DateTime expirationDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  License({
    String? id,
    required this.name,
    required this.description,
    required this.issueDate,
    required this.expirationDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Check if license is expired
  bool get isExpired => DateTime.now().isAfter(expirationDate);

  // Check if license will expire within given days
  bool willExpireWithinDays(int days) {
    final warningDate = DateTime.now().add(Duration(days: days));
    return warningDate.isAfter(expirationDate) && !isExpired;
  }

  // Get days until expiration
  int get daysUntilExpiration {
    final difference = expirationDate.difference(DateTime.now());
    return difference.inDays;
  }

  // Get expiration status text
  String get expirationStatus {
    if (isExpired) {
      return 'Expired ${-daysUntilExpiration} days ago';
    } else if (daysUntilExpiration <= 30) {
      return 'Expires in $daysUntilExpiration days';
    } else {
      return 'Valid';
    }
  }

  // Copy with method for updates
  License copyWith({
    String? name,
    String? description,
    DateTime? issueDate,
    DateTime? expirationDate,
  }) {
    return License(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      issueDate: issueDate ?? this.issueDate,
      expirationDate: expirationDate ?? this.expirationDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'issueDate': issueDate.toIso8601String(),
      'expirationDate': expirationDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory License.fromJson(Map<String, dynamic> json) {
    return License(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      issueDate: DateTime.parse(json['issueDate']),
      expirationDate: DateTime.parse(json['expirationDate']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}