import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/model.dart';

class ModelService with ChangeNotifier {
  static const String _boxName = 'models';
  Box<Model>? _box;
  List<Model> _models = [];

  List<Model> get models => List.unmodifiable(_models);

  Future<void> initialize() async {
    _box = await Hive.openBox<Model>(_boxName);
    await _loadModels();
  }

  Future<void> _loadModels() async {
    if (_box == null) return;

    final List<Model> validModels = [];
    final List<String> corruptedKeys = [];

    // Load models one by one to handle corrupted data
    for (final key in _box!.keys) {
      try {
        final model = _box!.get(key);
        if (model != null) {
          // Check if this is a corrupted model with placeholder data
          if (model.id.startsWith('corrupted-') || model.name == 'Unknown Model') {
            debugPrint('Found corrupted model data for key $key: ${model.name}');
            corruptedKeys.add(key.toString());
          } else {
            validModels.add(model);
          }
        }
      } catch (e) {
        debugPrint('Corrupted model data found for key $key: $e');
        corruptedKeys.add(key.toString());
      }
    }

    // Remove corrupted entries
    for (final key in corruptedKeys) {
      try {
        await _box!.delete(key);
        debugPrint('Removed corrupted model data for key $key');
      } catch (e) {
        debugPrint('Failed to remove corrupted model data for key $key: $e');
      }
    }

    _models = validModels;
    _models.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();

    if (corruptedKeys.isNotEmpty) {
      debugPrint('Cleaned up ${corruptedKeys.length} corrupted model records');
    }
  }

  Future<void> addModel(Model model) async {
    if (_box == null) throw Exception('ModelService not initialized');

    await _box!.put(model.id, model);
    _models.add(model);
    _models.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateModel(Model model) async {
    if (_box == null) throw Exception('ModelService not initialized');

    final updatedModel = model.copyWith(
      updatedAt: DateTime.now(),
    );

    await _box!.put(updatedModel.id, updatedModel);

    final index = _models.indexWhere((m) => m.id == updatedModel.id);
    if (index != -1) {
      _models[index] = updatedModel;
      _models.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  Future<void> deleteModel(String id) async {
    if (_box == null) throw Exception('ModelService not initialized');

    await _box!.delete(id);
    _models.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  Model? getModelById(String id) {
    return _models.where((m) => m.id == id).firstOrNull;
  }

  List<Model> getModelsByManufacturer(String manufacturerId) {
    return _models
        .where((m) => m.manufacturerId == manufacturerId)
        .toList();
  }

  List<Model> getModelsByCategory(AircraftCategory category) {
    return _models
        .where((m) => m.category == category)
        .toList();
  }

  List<Model> searchModels(String query) {
    if (query.isEmpty) return models;

    final lowerQuery = query.toLowerCase();
    return _models
        .where((m) =>
            m.name.toLowerCase().contains(lowerQuery) ||
            (m.description?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  Future<void> addDefaultModels() async {
    final defaultModels = [
      // Cessna aircraft
      Model(
        id: 'cessna-172',
        name: 'Cessna 172',
        manufacturerId: 'cessna',
        category: AircraftCategory.singleEngine,
        engineCount: 1,
        maxSeats: 4,
        typicalCruiseSpeed: 122,
        typicalServiceCeiling: 14000,
        description: 'Popular training aircraft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Model(
        id: 'cessna-182',
        name: 'Cessna 182',
        manufacturerId: 'cessna',
        category: AircraftCategory.singleEngine,
        engineCount: 1,
        maxSeats: 4,
        typicalCruiseSpeed: 145,
        typicalServiceCeiling: 18000,
        description: 'High-performance single engine',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Model(
        id: 'cessna-310',
        name: 'Cessna 310',
        manufacturerId: 'cessna',
        category: AircraftCategory.multiEngine,
        engineCount: 2,
        maxSeats: 6,
        typicalCruiseSpeed: 220,
        typicalServiceCeiling: 20000,
        description: 'Light twin engine',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      // Piper aircraft
      Model(
        id: 'piper-pa28',
        name: 'Piper PA-28',
        manufacturerId: 'piper',
        category: AircraftCategory.singleEngine,
        engineCount: 1,
        maxSeats: 4,
        typicalCruiseSpeed: 125,
        typicalServiceCeiling: 14000,
        description: 'Cherokee series aircraft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Model(
        id: 'piper-seneca',
        name: 'Piper Seneca',
        manufacturerId: 'piper',
        category: AircraftCategory.multiEngine,
        engineCount: 2,
        maxSeats: 6,
        typicalCruiseSpeed: 195,
        typicalServiceCeiling: 25000,
        description: 'Twin engine aircraft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      // Jet aircraft
      Model(
        id: 'citation-mustang',
        name: 'Citation Mustang',
        manufacturerId: 'cessna',
        category: AircraftCategory.jet,
        engineCount: 2,
        maxSeats: 4,
        typicalCruiseSpeed: 340,
        typicalServiceCeiling: 41000,
        description: 'Very light jet',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final model in defaultModels) {
      await addModel(model);
    }
  }

  @override
  void dispose() {
    _box?.close();
    super.dispose();
  }
}
