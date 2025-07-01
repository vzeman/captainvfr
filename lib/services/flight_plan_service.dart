import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/flight_plan.dart';
import '../models/airport.dart';
import '../models/navaid.dart';

class FlightPlanService extends ChangeNotifier {
  FlightPlan? _currentFlightPlan;
  bool _isPlanning = false;
  int _waypointCounter = 1;

  FlightPlan? get currentFlightPlan => _currentFlightPlan;
  bool get isPlanning => _isPlanning;
  List<Waypoint> get waypoints => _currentFlightPlan?.waypoints ?? [];

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
