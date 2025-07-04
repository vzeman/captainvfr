import 'package:hive/hive.dart';
import 'checklist_item.dart';

part 'checklist.g.dart';

@HiveType(typeId: 26)
class Checklist extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String manufacturerId;

  @HiveField(4)
  String modelId;

  @HiveField(5)
  List<ChecklistItem> items;

  Checklist({
    required this.id,
    required this.name,
    this.description,
    required this.manufacturerId,
    required this.modelId,
    List<ChecklistItem>? items,
  }) : items = items ?? [];
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'manufacturerId': manufacturerId,
      'modelId': modelId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
  
  // Create from JSON
  factory Checklist.fromJson(Map<String, dynamic> json) {
    return Checklist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      manufacturerId: json['manufacturerId'] ?? '',
      modelId: json['modelId'] ?? '',
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => ChecklistItem.fromJson(item))
          .toList() ?? [],
    );
  }
}
