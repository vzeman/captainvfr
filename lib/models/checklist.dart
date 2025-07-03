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
}
