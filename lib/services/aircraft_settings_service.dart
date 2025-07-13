import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/aircraft.dart';
import '../models/model.dart';
import '../models/manufacturer.dart';
import 'manufacturer_service.dart';
import 'model_service.dart';
import 'aircraft_service.dart';

class AircraftSettingsService with ChangeNotifier {
  static final _instance = AircraftSettingsService._internal();
  factory AircraftSettingsService() => _instance;
  AircraftSettingsService._internal();

  final ManufacturerService _manufacturerService = ManufacturerService();
  final ModelService _modelService = ModelService();
  final AircraftService _aircraftService = AircraftService();

  bool _isInitialized = false;
  final Uuid _uuid = const Uuid();

  // Getters for individual services
  ManufacturerService get manufacturerService => _manufacturerService;
  ModelService get modelService => _modelService;
  AircraftService get aircraftService => _aircraftService;

  // Combined getters
  List<Manufacturer> get manufacturers => _manufacturerService.manufacturers;
  List<Model> get models => _modelService.models;
  List<Aircraft> get aircrafts => _aircraftService.aircrafts;
  Aircraft? get selectedAircraft => _aircraftService.selectedAircraft;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize all services
      await _manufacturerService.initialize();
      await _modelService.initialize();
      await _aircraftService.initialize();

      // Add default data if collections are empty
      if (_manufacturerService.manufacturers.isEmpty) {
        await _addDefaultManufacturers();
      }

      if (_modelService.models.isEmpty) {
        await _addDefaultModels();
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // debugPrint('Error initializing aircraft settings service: $e');
      rethrow;
    }
  }

  // Manufacturer CRUD methods
  Future<void> addManufacturer(String name, {String? website}) async {
    final manufacturer = Manufacturer(
      id: _uuid.v4(),
      name: name,
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

  // Model CRUD methods
  Future<void> addModel(
    String name,
    String manufacturerId,
    AircraftCategory category, {
    int engineCount = 1,
    int maxSeats = 2,
    int typicalCruiseSpeed = 100,
    int typicalServiceCeiling = 10000,
    String? description,
    double? fuelConsumption,
    int? maximumClimbRate,
    int? maximumDescentRate,
    int? maxTakeoffWeight,
    int? maxLandingWeight,
    int? fuelCapacity,
  }) async {
    final model = Model(
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
      fuelConsumption: fuelConsumption,
      maximumClimbRate: maximumClimbRate,
      maximumDescentRate: maximumDescentRate,
      maxTakeoffWeight: maxTakeoffWeight,
      maxLandingWeight: maxLandingWeight,
      fuelCapacity: fuelCapacity,
    );

    // Add the model to the service
    await _modelService.addModel(model);

    // Update the manufacturer's models list
    final manufacturer = _manufacturerService.manufacturers.firstWhere(
      (m) => m.id == manufacturerId,
    );

    if (!manufacturer.models.contains(model.id)) {
      manufacturer.models.add(model.id);
      await _manufacturerService.updateManufacturer(manufacturer);
    }

    notifyListeners();
  }

  Future<void> updateModel(Model model) async {
    await _modelService.updateModel(model);
    notifyListeners();
  }

  Future<void> deleteModel(String id) async {
    await _modelService.deleteModel(id);
    notifyListeners();
  }

  // Aircraft CRUD methods
  Future<void> addAircraft(Aircraft aircraft) async {
    await _aircraftService.addAircraft(aircraft);
    notifyListeners();
  }

  Future<void> updateAircraft(Aircraft aircraft) async {
    await _aircraftService.updateAircraft(aircraft);
    notifyListeners();
  }

  Future<void> deleteAircraft(String id) async {
    await _aircraftService.deleteAircraft(id);
    notifyListeners();
  }

  // Helper methods
  List<Model> getModelsForManufacturer(String manufacturerId) {
    return _modelService.models
        .where((model) => model.manufacturerId == manufacturerId)
        .toList();
  }

  List<Aircraft> getAircraftsForModel(String modelId) {
    return _aircrafts.where((aircraft) => aircraft.modelId == modelId).toList();
  }

  List<Aircraft> get _aircrafts => _aircraftService.aircrafts;

  // Default data methods
  Future<void> _addDefaultManufacturers() async {
    final defaultManufacturers = [
      'Cessna',
      'Piper',
      'Beechcraft',
      'Cirrus',
      'Diamond',
      'Mooney',
    ];

    for (final name in defaultManufacturers) {
      await addManufacturer(name);
    }
  }

  Future<void> _addDefaultModels() async {
    // Make sure we have manufacturers before trying to add models
    if (manufacturers.isEmpty) {
      // debugPrint('No manufacturers found, skipping default models');
      return;
    }

    // Add some default models for common manufacturers
    final cessna = manufacturers.firstWhere(
      (m) => m.name == 'Cessna',
      orElse: () => manufacturers
          .first, // Fallback to first manufacturer if Cessna not found
    );
    final piper = manufacturers.firstWhere(
      (m) => m.name == 'Piper',
      orElse: () => manufacturers
          .first, // Fallback to first manufacturer if Piper not found
    );

    try {
      await addModel(
        'C172',
        cessna.id,
        AircraftCategory.singleEngine,
        engineCount: 1,
        maxSeats: 4,
        typicalCruiseSpeed: 122,
        typicalServiceCeiling: 14000,
      );
      await addModel(
        'C182',
        cessna.id,
        AircraftCategory.singleEngine,
        engineCount: 1,
        maxSeats: 4,
        typicalCruiseSpeed: 145,
        typicalServiceCeiling: 18000,
      );
      await addModel(
        'PA-28',
        piper.id,
        AircraftCategory.singleEngine,
        engineCount: 1,
        maxSeats: 4,
        typicalCruiseSpeed: 125,
        typicalServiceCeiling: 14000,
      );
    } catch (e) {
      // debugPrint('Error adding default models: $e');
    }
  }

  @override
  void dispose() {
    _manufacturerService.dispose();
    _modelService.dispose();
    _aircraftService.dispose();
    super.dispose();
  }
}
