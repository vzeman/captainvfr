import 'package:hive/hive.dart';

part 'checklist_item.g.dart';

@HiveType(typeId: 25)
class ChecklistItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String? targetValue;

  ChecklistItem({
    required this.id,
    required this.name,
    this.description,
    this.targetValue,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'targetValue': targetValue,
    };
  }

  // Create from JSON
  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      targetValue: json['targetValue'],
    );
  }
}
