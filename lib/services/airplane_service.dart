import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/airplane.dart';

class AirplaneService with ChangeNotifier {
  static const String _boxName = 'airplanes';
  static const String _selectedAirplaneKey = 'selected_airplane_id';

  Box<Airplane>? _box;
  Box? _settingsBox;
  List<Airplane> _airplanes = [];
  String? _selectedAirplaneId;

  List<Airplane> get airplanes => List.unmodifiable(_airplanes);
  String? get selectedAirplaneId => _selectedAirplaneId;

  Airplane? get selectedAirplane {
    if (_selectedAirplaneId == null) return null;
    return getAirplaneById(_selectedAirplaneId!);
  }

  Future<void> initialize() async {
    _box = await Hive.openBox<Airplane>(_boxName);
    _settingsBox = await Hive.openBox('settings');
    await _loadAirplanes();
    _loadSelectedAirplane();
  }

  Future<void> _loadAirplanes() async {
    if (_box == null) return;
    _airplanes = _box!.values.toList();
    _airplanes.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void _loadSelectedAirplane() {
    _selectedAirplaneId = _settingsBox?.get(_selectedAirplaneKey);
    notifyListeners();
  }

  Future<void> addAirplane(Airplane airplane) async {
    if (_box == null) throw Exception('AirplaneService not initialized');

    await _box!.put(airplane.id, airplane);
    _airplanes.add(airplane);
    _airplanes.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateAirplane(Airplane airplane) async {
    if (_box == null) throw Exception('AirplaneService not initialized');

    final updatedAirplane = airplane.copyWith(
      updatedAt: DateTime.now(),
    );

    await _box!.put(updatedAirplane.id, updatedAirplane);

    final index = _airplanes.indexWhere((a) => a.id == updatedAirplane.id);
    if (index != -1) {
      _airplanes[index] = updatedAirplane;
      _airplanes.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  Future<void> deleteAirplane(String id) async {
    if (_box == null) throw Exception('AirplaneService not initialized');

    await _box!.delete(id);
    _airplanes.removeWhere((a) => a.id == id);

    // Clear selection if deleted airplane was selected
    if (_selectedAirplaneId == id) {
      await selectAirplane(null);
    }

    notifyListeners();
  }

  Future<void> selectAirplane(String? airplaneId) async {
    if (_settingsBox == null) throw Exception('AirplaneService not initialized');

    _selectedAirplaneId = airplaneId;
    if (airplaneId == null) {
      await _settingsBox!.delete(_selectedAirplaneKey);
    } else {
      await _settingsBox!.put(_selectedAirplaneKey, airplaneId);
    }
    notifyListeners();
  }

  Airplane? getAirplaneById(String id) {
    return _airplanes.where((a) => a.id == id).firstOrNull;
  }

  List<Airplane> getAirplanesByManufacturer(String manufacturerId) {
    return _airplanes
        .where((a) => a.manufacturerId == manufacturerId)
        .toList();
  }

  List<Airplane> getAirplanesByType(String airplaneTypeId) {
    return _airplanes
        .where((a) => a.airplaneTypeId == airplaneTypeId)
        .toList();
  }

  List<Airplane> searchAirplanes(String query) {
    if (query.isEmpty) return airplanes;

    final lowerQuery = query.toLowerCase();
    return _airplanes
        .where((a) =>
            a.name.toLowerCase().contains(lowerQuery) ||
            (a.registrationNumber?.toLowerCase().contains(lowerQuery) ?? false) ||
            (a.description?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  // Flight planning calculation methods
  double calculateFuelConsumption(double distanceNm, {double? cruiseSpeed}) {
    final airplane = selectedAirplane;
    if (airplane == null) return 0.0;

    final speed = cruiseSpeed ?? airplane.cruiseSpeed;
    final timeHours = distanceNm / speed;
    return timeHours * airplane.fuelConsumption;
  }

  Duration calculateFlightTime(double distanceNm, {double? cruiseSpeed}) {
    final airplane = selectedAirplane;
    if (airplane == null) return Duration.zero;

    final speed = cruiseSpeed ?? airplane.cruiseSpeed;
    final timeHours = distanceNm / speed;
    final minutes = (timeHours * 60).round();
    return Duration(minutes: minutes);
  }

  double calculateClimbTime(double altitudeChangeFt) {
    final airplane = selectedAirplane;
    if (airplane == null || altitudeChangeFt <= 0) return 0.0;

    return altitudeChangeFt / airplane.maximumClimbRate; // minutes
  }

  double calculateDescentTime(double altitudeChangeFt) {
    final airplane = selectedAirplane;
    if (airplane == null || altitudeChangeFt <= 0) return 0.0;

    return altitudeChangeFt / airplane.maximumDescentRate; // minutes
  }

  bool canReachAltitude(double targetAltitudeFt) {
    final airplane = selectedAirplane;
    if (airplane == null) return true;

    return targetAltitudeFt <= airplane.maximumAltitude;
  }

  Future<void> addDefaultAirplanes() async {
    final defaultAirplanes = [
      Airplane(
        id: 'default-cessna-172',
        name: 'N12345 (C172)',
        manufacturerId: 'cessna',
        airplaneTypeId: 'cessna-172',
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

    for (final airplane in defaultAirplanes) {
      await addAirplane(airplane);
    }
  }

  @override
  void dispose() {
    _box?.close();
    _settingsBox?.close();
    super.dispose();
  }
}
