import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/aircraft.dart';

class AircraftService with ChangeNotifier {
  static const String _boxName = 'aircrafts';
  static const String _selectedAircraftKey = 'selected_aircraft_id';

  Box<Aircraft>? _box;
  Box? _settingsBox;
  List<Aircraft> _aircrafts = [];
  String? _selectedAircraftId;

  List<Aircraft> get aircrafts => List.unmodifiable(_aircrafts);
  String? get selectedAircraftId => _selectedAircraftId;

  Aircraft? get selectedAircraft {
    if (_selectedAircraftId == null) return null;
    return getAircraftById(_selectedAircraftId!);
  }

  Future<void> initialize() async {
    _box = await Hive.openBox<Aircraft>(_boxName);
    _settingsBox = await Hive.openBox('settings');
    await _loadAircrafts();
    _loadSelectedAircraft();
  }

  Future<void> _loadAircrafts() async {
    if (_box == null) return;
    _aircrafts = _box!.values.toList();
    _aircrafts.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void _loadSelectedAircraft() {
    _selectedAircraftId = _settingsBox?.get(_selectedAircraftKey);
    notifyListeners();
  }

  Future<void> addAircraft(Aircraft aircraft) async {
    if (_box == null) throw Exception('AircraftService not initialized');

    await _box!.put(aircraft.id, aircraft);
    _aircrafts.add(aircraft);
    _aircrafts.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateAircraft(Aircraft aircraft) async {
    if (_box == null) throw Exception('AircraftService not initialized');

    final updatedAircraft = aircraft.copyWith(
      updatedAt: DateTime.now(),
    );

    await _box!.put(updatedAircraft.id, updatedAircraft);

    final index = _aircrafts.indexWhere((a) => a.id == updatedAircraft.id);
    if (index != -1) {
      _aircrafts[index] = updatedAircraft;
      _aircrafts.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  Future<void> deleteAircraft(String id) async {
    if (_box == null) throw Exception('AircraftService not initialized');

    await _box!.delete(id);
    _aircrafts.removeWhere((a) => a.id == id);

    // Clear selection if deleted aircraft was selected
    if (_selectedAircraftId == id) {
      await selectAircraft(null);
    }

    notifyListeners();
  }

  Future<void> selectAircraft(String? aircraftId) async {
    if (_settingsBox == null) throw Exception('AircraftService not initialized');

    _selectedAircraftId = aircraftId;
    if (aircraftId == null) {
      await _settingsBox!.delete(_selectedAircraftKey);
    } else {
      await _settingsBox!.put(_selectedAircraftKey, aircraftId);
    }
    notifyListeners();
  }

  Aircraft? getAircraftById(String id) {
    return _aircrafts.where((a) => a.id == id).firstOrNull;
  }

  List<Aircraft> getAircraftsByManufacturer(String manufacturerId) {
    return _aircrafts
        .where((a) => a.manufacturerId == manufacturerId)
        .toList();
  }

  List<Aircraft> getAircraftsByModel(String modelId) {
    return _aircrafts
        .where((a) => a.modelId == modelId)
        .toList();
  }

  List<Aircraft> searchAircrafts(String query) {
    if (query.isEmpty) return aircrafts;

    final lowerQuery = query.toLowerCase();
    return _aircrafts
        .where((a) =>
            a.name.toLowerCase().contains(lowerQuery) ||
            (a.registrationNumber?.toLowerCase().contains(lowerQuery) ?? false) ||
            (a.description?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  // Flight planning calculation methods
  double calculateFuelConsumption(double distanceNm, {double? cruiseSpeed}) {
    final aircraft = selectedAircraft;
    if (aircraft == null) return 0.0;

    final speed = cruiseSpeed ?? aircraft.cruiseSpeed;
    final timeHours = distanceNm / speed;
    return timeHours * aircraft.fuelConsumption;
  }

  Duration calculateFlightTime(double distanceNm, {double? cruiseSpeed}) {
    final aircraft = selectedAircraft;
    if (aircraft == null) return Duration.zero;

    final speed = cruiseSpeed ?? aircraft.cruiseSpeed;
    final timeHours = distanceNm / speed;
    final minutes = (timeHours * 60).round();
    return Duration(minutes: minutes);
  }

  double calculateClimbTime(double altitudeChangeFt) {
    final aircraft = selectedAircraft;
    if (aircraft == null || altitudeChangeFt <= 0) return 0.0;

    return altitudeChangeFt / aircraft.maximumClimbRate; // minutes
  }

  double calculateDescentTime(double altitudeChangeFt) {
    final aircraft = selectedAircraft;
    if (aircraft == null || altitudeChangeFt <= 0) return 0.0;

    return altitudeChangeFt / aircraft.maximumDescentRate; // minutes
  }

  bool canReachAltitude(double targetAltitudeFt) {
    final aircraft = selectedAircraft;
    if (aircraft == null) return true;

    return targetAltitudeFt <= aircraft.maximumAltitude;
  }

  Future<void> addDefaultAircrafts() async {
    final defaultAircrafts = [
      Aircraft(
        id: 'default-cessna-172',
        name: 'N12345 (C172)',
        manufacturerId: 'cessna',
        modelId: 'cessna-172',
        cruiseSpeed: 110, // knots
        fuelConsumption: 8.5, // gph
        maximumAltitude: 14000, // feet
        maximumClimbRate: 645, // fpm
        maximumDescentRate: 500, // fpm
        maxTakeoffWeight: 2450, // lbs
        maxLandingWeight: 2450, // lbs
        fuelCapacity: 56, // gallons
        registrationNumber: 'N12345',
        description: 'Default Cessna 172',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    for (final aircraft in defaultAircrafts) {
      await addAircraft(aircraft);
    }
  }

  @override
  void dispose() {
    _box?.close();
    _settingsBox?.close();
    super.dispose();
  }
}
