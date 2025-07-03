import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/manufacturer.dart';

class ManufacturerService with ChangeNotifier {
  static const String _boxName = 'manufacturers';
  Box<Manufacturer>? _box;
  List<Manufacturer> _manufacturers = [];

  List<Manufacturer> get manufacturers => List.unmodifiable(_manufacturers);

  Future<void> initialize() async {
    _box = await Hive.openBox<Manufacturer>(_boxName);
    await _loadManufacturers();
  }

  Future<void> _loadManufacturers() async {
    if (_box == null) return;

    final List<Manufacturer> validManufacturers = [];
    final List<String> corruptedKeys = [];

    // Load manufacturers one by one to handle corrupted data
    for (final key in _box!.keys) {
      try {
        final manufacturer = _box!.get(key);
        if (manufacturer != null) {
          // Check if this is a corrupted manufacturer with placeholder data
          if (manufacturer.id.startsWith('corrupted-') || manufacturer.name == 'Unknown Manufacturer') {
            debugPrint('Found corrupted manufacturer data for key $key: ${manufacturer.name}');
            corruptedKeys.add(key.toString());
          } else {
            validManufacturers.add(manufacturer);
          }
        }
      } catch (e) {
        debugPrint('Corrupted manufacturer data found for key $key: $e');
        corruptedKeys.add(key.toString());
      }
    }

    // Remove corrupted entries
    for (final key in corruptedKeys) {
      try {
        await _box!.delete(key);
        debugPrint('Removed corrupted manufacturer data for key $key');
      } catch (e) {
        debugPrint('Failed to remove corrupted manufacturer data for key $key: $e');
      }
    }

    _manufacturers = validManufacturers;
    _manufacturers.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();

    if (corruptedKeys.isNotEmpty) {
      debugPrint('Cleaned up ${corruptedKeys.length} corrupted manufacturer records');
    }
  }

  Future<void> addManufacturer(Manufacturer manufacturer) async {
    if (_box == null) throw Exception('ManufacturerService not initialized');

    await _box!.put(manufacturer.id, manufacturer);
    _manufacturers.add(manufacturer);
    _manufacturers.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateManufacturer(Manufacturer manufacturer) async {
    if (_box == null) throw Exception('ManufacturerService not initialized');

    final updatedManufacturer = manufacturer.copyWith(
      updatedAt: DateTime.now(),
    );

    await _box!.put(updatedManufacturer.id, updatedManufacturer);

    final index = _manufacturers.indexWhere((m) => m.id == updatedManufacturer.id);
    if (index != -1) {
      _manufacturers[index] = updatedManufacturer;
      _manufacturers.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  Future<void> deleteManufacturer(String id) async {
    if (_box == null) throw Exception('ManufacturerService not initialized');

    await _box!.delete(id);
    _manufacturers.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  Manufacturer? getManufacturerById(String id) {
    return _manufacturers.where((m) => m.id == id).firstOrNull;
  }

  List<Manufacturer> searchManufacturers(String query) {
    if (query.isEmpty) return manufacturers;

    final lowerQuery = query.toLowerCase();
    return _manufacturers
        .where((m) =>
            m.name.toLowerCase().contains(lowerQuery) ||
            (m.description?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  Future<void> addDefaultManufacturers() async {
    final defaultManufacturers = [
      Manufacturer(
        id: 'cessna',
        name: 'Cessna',
        description: 'American aircraft manufacturer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Manufacturer(
        id: 'piper',
        name: 'Piper',
        description: 'American aircraft manufacturer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Manufacturer(
        id: 'beechcraft',
        name: 'Beechcraft',
        description: 'American aircraft manufacturer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Manufacturer(
        id: 'cirrus',
        name: 'Cirrus',
        description: 'American aircraft manufacturer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Manufacturer(
        id: 'diamond',
        name: 'Diamond',
        description: 'Austrian aircraft manufacturer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final manufacturer in defaultManufacturers) {
      if (getManufacturerById(manufacturer.id) == null) {
        await addManufacturer(manufacturer);
      }
    }
  }

  @override
  void dispose() {
    _box?.close();
    super.dispose();
  }
}
