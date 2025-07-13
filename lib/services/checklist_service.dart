import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/checklist.dart';

/// Service to manage checklists using Hive for persistence.
class ChecklistService extends ChangeNotifier {
  static const _boxName = 'checklists';
  late Box<Checklist> _box;

  /// All stored checklists.
  List<Checklist> get checklists => _box.values.toList();

  /// Initialize Hive box for checklists.
  Future<void> initialize() async {
    _box = await Hive.openBox<Checklist>(_boxName);
  }

  /// Add or update a checklist.
  Future<void> saveChecklist(Checklist checklist) async {
    await _box.put(checklist.id, checklist);
    notifyListeners();
  }

  /// Delete checklist by id.
  Future<void> deleteChecklist(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  /// Get checklists for a specific model
  List<Checklist> getChecklistsForModel(String modelId) {
    return checklists.where((c) => c.modelId == modelId).toList();
  }

  /// Get checklists for a specific aircraft (by model ID)
  List<Checklist> getChecklistsForAircraft(String aircraftModelId) {
    return getChecklistsForModel(aircraftModelId);
  }
}
