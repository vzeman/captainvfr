import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';
import '../models/flight_plan.dart';
import '../models/airport.dart';
import '../models/navaid.dart';

class FlightPlanService extends ChangeNotifier {
  FlightPlan? _currentFlightPlan;
  bool _isPlanning = false;
  int _waypointCounter = 1;
  List<FlightPlan> _savedFlightPlans = [];
  Box<FlightPlan>? _flightPlanBox;

  FlightPlan? get currentFlightPlan => _currentFlightPlan;
  bool get isPlanning => _isPlanning;
  List<Waypoint> get waypoints => _currentFlightPlan?.waypoints ?? [];
  List<FlightPlan> get savedFlightPlans => _savedFlightPlans;

  // Initialize Hive box for flight plans
  Future<void> initialize() async {
    try {
      _flightPlanBox = await Hive.openBox<FlightPlan>('flight_plans');
      _loadSavedFlightPlans();
    } catch (e) {
      debugPrint('Error initializing flight plan service: $e');
    }
  }

  // Load saved flight plans from storage
  void _loadSavedFlightPlans() {
    if (_flightPlanBox != null) {
      _savedFlightPlans = _flightPlanBox!.values.toList();
      _savedFlightPlans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }
  }

  // Save current flight plan to storage
  Future<void> saveCurrentFlightPlan({String? customName}) async {
    if (_currentFlightPlan == null || _flightPlanBox == null) return;

    if (customName != null && customName.isNotEmpty) {
      _currentFlightPlan!.name = customName;
    }

    _currentFlightPlan!.modifiedAt = DateTime.now();

    try {
      await _flightPlanBox!.put(_currentFlightPlan!.id, _currentFlightPlan!);
      _loadSavedFlightPlans();
      debugPrint('Flight plan saved: ${_currentFlightPlan!.name}');
    } catch (e) {
      debugPrint('Error saving flight plan: $e');
    }
  }

  // Load a flight plan from storage
  void loadFlightPlan(String flightPlanId) {
    final flightPlan = _savedFlightPlans.firstWhere(
      (fp) => fp.id == flightPlanId,
      orElse: () => throw Exception('Flight plan not found'),
    );

    _currentFlightPlan = flightPlan;
    _isPlanning = true;
    _waypointCounter = flightPlan.waypoints.length + 1;
    notifyListeners();
  }

  // Delete a flight plan from storage
  Future<void> deleteFlightPlan(String flightPlanId) async {
    if (_flightPlanBox == null) return;

    try {
      await _flightPlanBox!.delete(flightPlanId);
      _loadSavedFlightPlans();

      // If the deleted flight plan is currently loaded, clear it
      if (_currentFlightPlan?.id == flightPlanId) {
        clearFlightPlan();
      }

      debugPrint('Flight plan deleted: $flightPlanId');
    } catch (e) {
      debugPrint('Error deleting flight plan: $e');
    }
  }

  // Duplicate a flight plan
  Future<void> duplicateFlightPlan(String flightPlanId) async {
    final originalPlan = _savedFlightPlans.firstWhere(
      (fp) => fp.id == flightPlanId,
      orElse: () => throw Exception('Flight plan not found'),
    );

    final duplicatedPlan = FlightPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${originalPlan.name} (Copy)',
      createdAt: DateTime.now(),
      waypoints: originalPlan.waypoints.map((wp) => Waypoint(
        id: DateTime.now().millisecondsSinceEpoch.toString() + wp.id,
        latitude: wp.latitude,
        longitude: wp.longitude,
        altitude: wp.altitude,
        name: wp.name,
        notes: wp.notes,
        type: wp.type,
      )).toList(),
      aircraftId: originalPlan.aircraftId,
      cruiseSpeed: originalPlan.cruiseSpeed,
    );

    if (_flightPlanBox != null) {
      try {
        await _flightPlanBox!.put(duplicatedPlan.id, duplicatedPlan);
        _loadSavedFlightPlans();
        debugPrint('Flight plan duplicated: ${duplicatedPlan.name}');
      } catch (e) {
        debugPrint('Error duplicating flight plan: $e');
      }
    }
  }

  // Start creating a new flight plan
  void startNewFlightPlan({String? name}) {
    _currentFlightPlan = FlightPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name ?? 'Flight Plan ${DateTime.now().day}/${DateTime.now().month}',
      createdAt: DateTime.now(),
      waypoints: [],
    );
    _isPlanning = true;
    _waypointCounter = 1;
    notifyListeners();
  }

  // Add a waypoint by clicking on the map
  void addWaypoint(LatLng position, {double altitude = 3000.0}) {
    if (_currentFlightPlan == null) {
      startNewFlightPlan();
    }

    final waypoint = Waypoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: altitude,
      name: 'WP${_waypointCounter++}',
      type: WaypointType.user,
    );

    _currentFlightPlan!.waypoints.add(waypoint);
    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Add waypoint from airport
  void addAirportWaypoint(Airport airport, {double altitude = 3000.0}) {
    if (_currentFlightPlan == null) {
      startNewFlightPlan();
    }

    final waypoint = Waypoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: airport.position.latitude,
      longitude: airport.position.longitude,
      altitude: altitude,
      name: airport.icaoCode?.isNotEmpty == true ? airport.icaoCode! : (airport.iataCode ?? airport.icao),
      notes: airport.name,
      type: WaypointType.airport,
    );

    _currentFlightPlan!.waypoints.add(waypoint);
    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Add waypoint from navaid
  void addNavaidWaypoint(Navaid navaid, {double altitude = 3000.0}) {
    if (_currentFlightPlan == null) {
      startNewFlightPlan();
    }

    final waypoint = Waypoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: navaid.position.latitude,
      longitude: navaid.position.longitude,
      altitude: altitude,
      name: navaid.ident,
      notes: navaid.name,
      type: WaypointType.navaid,
    );

    _currentFlightPlan!.waypoints.add(waypoint);
    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Remove a waypoint by index
  void removeWaypoint(int index) {
    if (_currentFlightPlan != null &&
        index >= 0 &&
        index < _currentFlightPlan!.waypoints.length) {
      _currentFlightPlan!.waypoints.removeAt(index);
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Update waypoint altitude
  void updateWaypointAltitude(int index, double altitude) {
    if (_currentFlightPlan != null &&
        index >= 0 &&
        index < _currentFlightPlan!.waypoints.length) {
      _currentFlightPlan!.waypoints[index].altitude = altitude;
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Update cruise speed
  void updateCruiseSpeed(double speed) {
    if (_currentFlightPlan != null) {
      _currentFlightPlan!.cruiseSpeed = speed;
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Clear current flight plan
  void clearFlightPlan() {
    _currentFlightPlan = null;
    _isPlanning = false;
    _waypointCounter = 1;
    notifyListeners();
  }

  // Toggle planning mode
  void togglePlanningMode() {
    _isPlanning = !_isPlanning;
    if (!_isPlanning && (_currentFlightPlan?.waypoints.isEmpty ?? true)) {
      clearFlightPlan();
    }
    notifyListeners();
  }

  // Get formatted flight plan summary
  String getFlightPlanSummary() {
    if (_currentFlightPlan == null || _currentFlightPlan!.waypoints.isEmpty) {
      return 'No flight plan';
    }

    final distance = _currentFlightPlan!.totalDistance;
    final time = _currentFlightPlan!.totalFlightTime;

    String summary = '${_currentFlightPlan!.waypoints.length} waypoints, ';
    summary += '${distance.toStringAsFixed(1)} NM';

    if (time > 0) {
      final hours = (time / 60).floor();
      final minutes = (time % 60).round();
      summary += ', ${hours}h ${minutes}m';
    }

    return summary;
  }

  // Reorder waypoints (for drag and drop functionality)
  void reorderWaypoints(int oldIndex, int newIndex) {
    if (_currentFlightPlan != null &&
        oldIndex >= 0 && oldIndex < _currentFlightPlan!.waypoints.length &&
        newIndex >= 0 && newIndex < _currentFlightPlan!.waypoints.length) {
      final waypoint = _currentFlightPlan!.waypoints.removeAt(oldIndex);
      _currentFlightPlan!.waypoints.insert(newIndex, waypoint);
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }
}
