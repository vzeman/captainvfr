import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/airplane_type.dart';

class AirplaneTypeService with ChangeNotifier {
  static const String _boxName = 'airplane_types';
  Box<AirplaneType>? _box;
  List<AirplaneType> _airplaneTypes = [];

  List<AirplaneType> get airplaneTypes => List.unmodifiable(_airplaneTypes);

  Future<void> initialize() async {
    _box = await Hive.openBox<AirplaneType>(_boxName);
    await _loadAirplaneTypes();
  }

  Future<void> _loadAirplaneTypes() async {
    if (_box == null) return;
    _airplaneTypes = _box!.values.toList();
    _airplaneTypes.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> addAirplaneType(AirplaneType airplaneType) async {
    if (_box == null) throw Exception('AirplaneTypeService not initialized');

    await _box!.put(airplaneType.id, airplaneType);
    _airplaneTypes.add(airplaneType);
    _airplaneTypes.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateAirplaneType(AirplaneType airplaneType) async {
    if (_box == null) throw Exception('AirplaneTypeService not initialized');

    final updatedType = airplaneType.copyWith(
      updatedAt: DateTime.now(),
    );

    await _box!.put(updatedType.id, updatedType);

    final index = _airplaneTypes.indexWhere((t) => t.id == updatedType.id);
    if (index != -1) {
      _airplaneTypes[index] = updatedType;
      _airplaneTypes.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  Future<void> deleteAirplaneType(String id) async {
    if (_box == null) throw Exception('AirplaneTypeService not initialized');

    await _box!.delete(id);
    _airplaneTypes.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  AirplaneType? getAirplaneTypeById(String id) {
    return _airplaneTypes.where((t) => t.id == id).firstOrNull;
  }

  List<AirplaneType> getAirplaneTypesByManufacturer(String manufacturerId) {
    return _airplaneTypes
        .where((t) => t.manufacturerId == manufacturerId)
        .toList();
  }

  List<AirplaneType> getAirplaneTypesByCategory(AirplaneCategory category) {
    return _airplaneTypes
        .where((t) => t.category == category)
        .toList();
  }

  List<AirplaneType> searchAirplaneTypes(String query) {
    if (query.isEmpty) return airplaneTypes;

    final lowerQuery = query.toLowerCase();
    return _airplaneTypes
        .where((t) =>
            t.name.toLowerCase().contains(lowerQuery) ||
            (t.description?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  Future<void> addDefaultAirplaneTypes() async {
    final defaultTypes = [
      // Cessna aircraft
      AirplaneType(
        id: 'cessna-172',
        name: 'Cessna 172',
        manufacturerId: 'cessna',
        category: AirplaneCategory.singleEngine,
        engineCount: 1,
        maxSeats: 4,
        typicalCruiseSpeed: 122.0,
        typicalServiceCeiling: 14000.0,
        description: 'Popular training aircraft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      AirplaneType(
        id: 'cessna-182',
        name: 'Cessna 182',
        manufacturerId: 'cessna',
        category: AirplaneCategory.singleEngine,
        engineCount: 1,
        maxSeats: 4,
        typicalCruiseSpeed: 145.0,
        typicalServiceCeiling: 18000.0,
        description: 'High-performance single engine',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      AirplaneType(
        id: 'cessna-310',
        name: 'Cessna 310',
        manufacturerId: 'cessna',
        category: AirplaneCategory.multiEngine,
        engineCount: 2,
        maxSeats: 6,
        typicalCruiseSpeed: 220.0,
        typicalServiceCeiling: 20000.0,
        description: 'Light twin engine',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      // Piper aircraft
      AirplaneType(
        id: 'piper-pa28',
        name: 'Piper PA-28',
        manufacturerId: 'piper',
        category: AirplaneCategory.singleEngine,
        engineCount: 1,
        maxSeats: 4,
        typicalCruiseSpeed: 125.0,
        typicalServiceCeiling: 14000.0,
        description: 'Cherokee series aircraft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      AirplaneType(
        id: 'piper-seneca',
        name: 'Piper Seneca',
        manufacturerId: 'piper',
        category: AirplaneCategory.multiEngine,
        engineCount: 2,
        maxSeats: 6,
        typicalCruiseSpeed: 195.0,
        typicalServiceCeiling: 25000.0,
        description: 'Twin engine aircraft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      // Jet aircraft
      AirplaneType(
        id: 'citation-mustang',
        name: 'Citation Mustang',
        manufacturerId: 'cessna',
        category: AirplaneCategory.jet,
        engineCount: 2,
        maxSeats: 4,
        typicalCruiseSpeed: 340.0,
        typicalServiceCeiling: 41000.0,
        description: 'Very light jet',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final type in defaultTypes) {
      await addAirplaneType(type);
    }
  }

  @override
  void dispose() {
    _box?.close();
    super.dispose();
  }
}
