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
}
