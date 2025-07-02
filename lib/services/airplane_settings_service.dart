import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/airplane.dart';
import '../models/airplane_type.dart';
import '../models/manufacturer.dart';
import 'manufacturer_service.dart';
import 'airplane_type_service.dart';
import 'airplane_service.dart';

class AirplaneSettingsService with ChangeNotifier {
  static final _instance = AirplaneSettingsService._internal();
  factory AirplaneSettingsService() => _instance;
  AirplaneSettingsService._internal();

  final ManufacturerService _manufacturerService = ManufacturerService();
  final AirplaneTypeService _airplaneTypeService = AirplaneTypeService();
  final AirplaneService _airplaneService = AirplaneService();

  bool _isInitialized = false;
  final Uuid _uuid = const Uuid();

  // Getters for individual services
  ManufacturerService get manufacturerService => _manufacturerService;
  AirplaneTypeService get airplaneTypeService => _airplaneTypeService;
  AirplaneService get airplaneService => _airplaneService;

  // Combined getters
  List<Manufacturer> get manufacturers => _manufacturerService.manufacturers;
  List<AirplaneType> get airplaneTypes => _airplaneTypeService.airplaneTypes;
  List<Airplane> get airplanes => _airplaneService.airplanes;
  Airplane? get selectedAirplane => _airplaneService.selectedAirplane;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize all services
      await _manufacturerService.initialize();
      await _airplaneTypeService.initialize();
      await _airplaneService.initialize();

      // Add default data if collections are empty
      if (_manufacturerService.manufacturers.isEmpty) {
        await _addDefaultManufacturers();
      }

      if (_airplaneTypeService.airplaneTypes.isEmpty) {
        await _addDefaultAirplaneTypes();
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing airplane settings service: $e');
      rethrow;
    }
  }

  // Manufacturer CRUD methods
  Future<void> addManufacturer(String name, {String? country, String? website}) async {
    final manufacturer = Manufacturer(
      id: _uuid.v4(),
      name: name,
      country: country,
      website: website,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _manufacturerService.addManufacturer(manufacturer);
    notifyListeners();
  }

  Future<void> updateManufacturer(Manufacturer manufacturer) async {
    await _manufacturerService.updateManufacturer(manufacturer);
    notifyListeners();
  }

  Future<void> deleteManufacturer(String id) async {
    await _manufacturerService.deleteManufacturer(id);
    notifyListeners();
  }

  // Airplane Type CRUD methods
  Future<void> addAirplaneType(
    String name,
    String manufacturerId,
    AirplaneCategory category, {
    int engineCount = 1,
    int maxSeats = 2,
    double typicalCruiseSpeed = 100.0,
    double typicalServiceCeiling = 10000.0,
    String? description,
  }) async {
    final airplaneType = AirplaneType(
      id: _uuid.v4(),
      name: name,
      manufacturerId: manufacturerId,
      category: category,
      engineCount: engineCount,
      maxSeats: maxSeats,
      typicalCruiseSpeed: typicalCruiseSpeed,
      typicalServiceCeiling: typicalServiceCeiling,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _airplaneTypeService.addAirplaneType(airplaneType);
    notifyListeners();
  }

  Future<void> updateAirplaneType(AirplaneType airplaneType) async {
    await _airplaneTypeService.updateAirplaneType(airplaneType);
    notifyListeners();
  }

  Future<void> deleteAirplaneType(String id) async {
    await _airplaneTypeService.deleteAirplaneType(id);
    notifyListeners();
  }

  // Airplane CRUD methods
  Future<void> addAirplane(Airplane airplane) async {
    await _airplaneService.addAirplane(airplane);
    notifyListeners();
  }

  Future<void> updateAirplane(Airplane airplane) async {
    await _airplaneService.updateAirplane(airplane);
    notifyListeners();
  }

  Future<void> deleteAirplane(String id) async {
    await _airplaneService.deleteAirplane(id);
    notifyListeners();
  }

  // Helper methods
  List<AirplaneType> getAirplaneTypesForManufacturer(String manufacturerId) {
    return _airplaneTypeService.airplaneTypes
        .where((type) => type.manufacturerId == manufacturerId)
        .toList();
  }

  List<Airplane> getAirplanesForType(String airplaneTypeId) {
    return _airplanes.where((airplane) => airplane.airplaneTypeId == airplaneTypeId).toList();
  }

  List<Airplane> get _airplanes => _airplaneService.airplanes;

  // Default data methods
  Future<void> _addDefaultManufacturers() async {
    final defaultManufacturers = [
      {'name': 'Cessna', 'country': 'USA'},
      {'name': 'Piper', 'country': 'USA'},
      {'name': 'Beechcraft', 'country': 'USA'},
      {'name': 'Cirrus', 'country': 'USA'},
      {'name': 'Diamond', 'country': 'Austria'},
      {'name': 'Mooney', 'country': 'USA'},
    ];

    for (final mfg in defaultManufacturers) {
      await addManufacturer(mfg['name']!, country: mfg['country']);
    }
  }

  Future<void> _addDefaultAirplaneTypes() async {
    // Add some default airplane types for common manufacturers
    final cessnaId = manufacturers.firstWhere((m) => m.name == 'Cessna').id;
    final piperId = manufacturers.firstWhere((m) => m.name == 'Piper').id;

    await addAirplaneType('C172', cessnaId, AirplaneCategory.singleEngine,
        engineCount: 1, maxSeats: 4, typicalCruiseSpeed: 122, typicalServiceCeiling: 14000);
    await addAirplaneType('C182', cessnaId, AirplaneCategory.singleEngine,
        engineCount: 1, maxSeats: 4, typicalCruiseSpeed: 145, typicalServiceCeiling: 18000);
    await addAirplaneType('PA-28', piperId, AirplaneCategory.singleEngine,
        engineCount: 1, maxSeats: 4, typicalCruiseSpeed: 125, typicalServiceCeiling: 14000);
  }

  @override
  void dispose() {
    _manufacturerService.dispose();
    _airplaneTypeService.dispose();
    _airplaneService.dispose();
    super.dispose();
  }
}
