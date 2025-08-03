import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../constants/map_constants.dart';

class MapStateController extends ChangeNotifier {

  // Location and map state
  Position? _currentPosition;
  LatLng? _selectedWaypoint;
  
  // Auto-centering control
  bool _autoCenteringEnabled = false;
  Timer? _autoCenteringTimer;
  Timer? _countdownTimer;
  int _autoCenteringCountdown = 0;
  
  // Position tracking control
  bool _positionTrackingEnabled = false;
  Timer? _positionUpdateTimer;
  
  // UI state
  bool _locationLoading = true;
  bool _isDraggingWaypoint = false;
  
  // Layer visibility states
  bool _showNavaids = false;
  bool _showMetar = true;  // Default to showing weather
  bool _showStats = false;
  bool _showHeliports = false;
  bool _showAirspaces = true;  // Default to showing airspaces
  bool _showObstacles = false;
  bool _showHotspots = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  LatLng? get selectedWaypoint => _selectedWaypoint;
  bool get autoCenteringEnabled => _autoCenteringEnabled;
  int get autoCenteringCountdown => _autoCenteringCountdown;
  bool get positionTrackingEnabled => _positionTrackingEnabled;
  bool get locationLoading => _locationLoading;
  bool get isDraggingWaypoint => _isDraggingWaypoint;
  
  // Layer visibility getters
  bool get showNavaids => _showNavaids;
  bool get showMetar => _showMetar;
  bool get showStats => _showStats;
  bool get showHeliports => _showHeliports;
  bool get showAirspaces => _showAirspaces;
  bool get showObstacles => _showObstacles;
  bool get showHotspots => _showHotspots;

  // Update current position
  void updatePosition(Position position) {
    _currentPosition = position;
    _locationLoading = false;
    notifyListeners();
  }

  // Set selected waypoint
  void setSelectedWaypoint(LatLng? waypoint) {
    _selectedWaypoint = waypoint;
    notifyListeners();
  }

  // Set dragging waypoint state
  void setDraggingWaypoint(bool isDragging) {
    _isDraggingWaypoint = isDragging;
    notifyListeners();
  }

  // Toggle layer visibility
  void toggleNavaids() {
    _showNavaids = !_showNavaids;
    notifyListeners();
  }

  void toggleMetar() {
    _showMetar = !_showMetar;
    notifyListeners();
  }

  void toggleStats() {
    _showStats = !_showStats;
    notifyListeners();
  }

  void toggleHeliports() {
    _showHeliports = !_showHeliports;
    notifyListeners();
  }

  void toggleAirspaces() {
    _showAirspaces = !_showAirspaces;
    notifyListeners();
  }

  void toggleObstacles() {
    _showObstacles = !_showObstacles;
    notifyListeners();
  }

  void toggleHotspots() {
    _showHotspots = !_showHotspots;
    notifyListeners();
  }

  // Auto-centering methods
  void enableAutoCentering() {
    _autoCenteringEnabled = true;
    _autoCenteringCountdown = 0;
    _cancelAutoCenteringTimers();
    notifyListeners();
  }

  void disableAutoCentering() {
    _autoCenteringEnabled = false;
    notifyListeners();
  }

  void startAutoCenteringCountdown() {
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    
    // Start countdown
    _autoCenteringCountdown = MapConstants.autoCenteringDelay.inSeconds;
    notifyListeners();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_autoCenteringCountdown > 0) {
        _autoCenteringCountdown--;
        notifyListeners();
      }
    });
    
    // Enable auto-centering after delay
    _autoCenteringTimer = Timer(MapConstants.autoCenteringDelay, () {
      enableAutoCentering();
    });
  }

  void _cancelAutoCenteringTimers() {
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    _autoCenteringTimer = null;
    _countdownTimer = null;
  }

  // Position tracking methods
  void enablePositionTracking() {
    _positionTrackingEnabled = true;
    _autoCenteringEnabled = true;
    notifyListeners();
  }

  void disablePositionTracking() {
    _positionTrackingEnabled = false;
    _autoCenteringEnabled = false;
    _cancelAutoCenteringTimers();
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;
    notifyListeners();
  }

  void togglePositionTracking() {
    if (_positionTrackingEnabled) {
      disablePositionTracking();
    } else {
      enablePositionTracking();
    }
  }

  void pauseAllTimers() {
    _positionUpdateTimer?.cancel();
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
  }

  void resumeAllTimers() {
    // Resume timers if they were active
    if (_positionTrackingEnabled && _positionUpdateTimer == null) {
      // Restart position update timer
      // Note: The actual timer setup should be handled by the map screen
    }
    if (_autoCenteringCountdown > 0) {
      startAutoCenteringCountdown();
    }
  }

  @override
  void dispose() {
    _cancelAutoCenteringTimers();
    _positionUpdateTimer?.cancel();
    super.dispose();
  }
}