import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/flight.dart';
import '../models/flight_point.dart';
import '../models/aircraft.dart';
import '../models/flight_segment.dart';
import 'barometer_service.dart';
import 'watch_connectivity_service.dart';
import 'flight/helpers/analytics_wrapper.dart';
import 'flight/models/flight_state.dart';
import 'flight/models/flight_constants.dart';
import 'flight/sensors/sensor_manager.dart';
import 'flight/calculations/flight_calculator.dart';
import 'flight/tracking/location_tracker.dart';
import 'flight/tracking/segment_tracker.dart';
import 'flight/storage/flight_history_manager.dart';
import 'logbook_service.dart';
import 'settings_service.dart';

class FlightService with ChangeNotifier {
  // Core components
  final FlightState _flightState = FlightState();
  late final SensorManager _sensorManager;
  late final LocationTracker _locationTracker;
  late final SegmentTracker _segmentTracker;
  final FlightHistoryManager _historyManager = FlightHistoryManager();
  
  // Services
  final BarometerService? _barometerService;
  final LogBookService? _logBookService;
  final WatchConnectivityService _watchService = WatchConnectivityService();
  
  // Subscriptions
  StreamSubscription? _barometerSubscription;
  StreamSubscription<bool>? _watchTrackingSubscription;
  
  // Throttling
  DateTime? _lastNotifyTime;
  Timer? _notifyTimer;
  
  // Callback for flight path updates
  final Function()? onFlightPathUpdated;
  
  // Initialize method for compatibility
  Future<void> initialize() async {
    await _initializeStorage();
  }
  
  // Constructor
  FlightService({
    this.onFlightPathUpdated,
    BarometerService? barometerService,
    LogBookService? logBookService,
  }) : _barometerService = barometerService ?? BarometerService(),
       _logBookService = logBookService {
    _initializeComponents();
    _initializeStorage();
    _initializeWatchConnectivity();
  }
  
  void _initializeComponents() {
    // Initialize sensor manager
    _sensorManager = SensorManager(
      onHeadingChanged: (heading) {
        _flightState.setCurrentHeading(heading);
      },
      onSensorDataUpdated: () {
        _throttledNotifyListeners();
      },
    );
    
    // Initialize location tracker
    _locationTracker = LocationTracker(
      onLocationUpdate: (flightPoint) {
        _handleLocationUpdate(flightPoint);
      },
      onError: (error) {
        debugPrint('Location error: $error');
      },
    );
    
    // Initialize segment tracker
    _segmentTracker = SegmentTracker(flightState: _flightState);
  }
  
  Future<void> _initializeStorage() async {
    await _historyManager.initialize();
    notifyListeners();
  }
  
  void _initializeWatchConnectivity() {
    if (!kIsWeb && Platform.isIOS) {
      _watchTrackingSubscription = _watchService.trackingStateStream.listen((shouldTrack) {
        if (shouldTrack && !_flightState.isTracking) {
          startTracking();
        } else if (!shouldTrack && _flightState.isTracking) {
          stopTracking();
        }
      });
    }
  }
  
  // Public getters delegating to components
  List<FlightPoint> get flightPath => _flightState.flightPath;
  List<Flight> get flights => _historyManager.flights;
  bool get isTracking => _flightState.isTracking;
  double get fuelUsed => FlightCalculator.calculateFuelUsed(
    _flightState.selectedAircraft,
    movingTime,
  );
  
  // Additional getters for compatibility
  List<FlightSegment> get flightSegments => _flightState.flightSegments;
  String get formattedFlightTime => formattedMovingTime;
  
  // Time and duration getters
  Duration get flightDuration => movingTime;
  Duration get movingTime => FlightCalculator.calculateMovingTime(
    _flightState.startTime,
    _flightState.flightPath,
    _flightState.isTracking,
  );
  String get formattedMovingTime => FlightCalculator.formatDuration(movingTime);
  
  // Speed and distance getters
  double get totalDistance => FlightCalculator.calculateTotalDistance(_flightState.flightPath);
  double get maxSpeed => FlightCalculator.getMaxSpeed(_flightState.flightPath);
  double get currentSpeed => _flightState.flightPath.isEmpty ? 0.0 : _flightState.flightPath.last.speed;
  double get averageSpeed => FlightCalculator.calculateAverageSpeed(_flightState.flightPath);
  double get verticalSpeed => FlightCalculator.calculateVerticalSpeed(_flightState.flightPath);
  
  // Sensor data getters
  double? get currentHeading => _flightState.currentHeading;
  double? get barometricAltitude => _flightState.currentBaroAltitude;
  double? get barometricPressure => _barometerService?.pressureHPa;
  double get currentGForce => _sensorManager.currentGForce;
  double get currentPressure => _barometerService?.lastPressure ?? FlightConstants.defaultPressureHPa;
  
  // Aircraft management
  void setAircraft(Aircraft aircraft) {
    _flightState.setAircraft(aircraft);
  }
  
  // Flight tracking control
  Future<void> startTracking() async {
    if (_flightState.isTracking) return;
    
    // Enable wakelock to keep screen on
    WakelockPlus.enable();
    
    // Reset state
    _flightState.reset();
    
    // Set tracking state
    _flightState.setTracking(true);
    _flightState.setStartTime(DateTime.now());
    _flightState.setRecordingStarted(DateTime.now().toUtc());
    
    // Start sensors
    _sensorManager.startSensors();
    
    // Start barometer
    if (_barometerService != null) {
      await _barometerService.initialize();
      _barometerSubscription = _barometerService.onBarometerUpdate.listen((reading) {
        _flightState.setCurrentBaroAltitude(reading.altitude);
        _flightState.setCurrentPressure(reading.pressure);
        _throttledNotifyListeners();
      });
    }
    
    // Start location tracking
    await _locationTracker.startTracking();
    
    // Notify listeners
    notifyListeners();
    
    // Track analytics
    AnalyticsWrapper.track('flight_tracking_started');
  }
  
  Future<void> stopTracking() async {
    if (!_flightState.isTracking) return;
    
    // Disable wakelock
    WakelockPlus.disable();
    
    // Set recording stopped time
    _flightState.setRecordingStopped(DateTime.now().toUtc());
    
    // Complete any open segments
    final lastPoint = _flightState.flightPath.isNotEmpty ? _flightState.flightPath.last : null;
    _segmentTracker.completeOpenSegments(lastPoint);
    
    // Stop tracking
    _locationTracker.stopTracking();
    _sensorManager.stopSensors();
    _barometerSubscription?.cancel();
    _barometerSubscription = null;
    
    _flightState.setTracking(false);
    
    // Save flight if there's data
    if (_flightState.flightPath.length > 1) {
      await _saveCurrentFlight();
    }
    
    notifyListeners();
    
    // Track analytics
    AnalyticsWrapper.track('flight_tracking_stopped');
  }
  
  void _handleLocationUpdate(FlightPoint point) {
    if (!_flightState.isTracking) return;
    
    // Update pressure if available
    if (_barometerService != null) {
      point = FlightPoint(
        latitude: point.latitude,
        longitude: point.longitude,
        altitude: point.altitude,
        speed: point.speed,
        heading: point.heading,
        timestamp: point.timestamp,
        accuracy: point.accuracy,
        pressure: _barometerService.lastPressure ?? 0.0,
      );
    }
    
    // Add point to flight path
    _flightState.addFlightPoint(point);
    
    // Process segments
    _segmentTracker.processFlightPoint(point);
    
    // Calculate vertical speed for watch
    final verticalSpeedMps = _flightState.flightPath.length > 1
        ? (point.altitude - _flightState.flightPath[_flightState.flightPath.length - 2].altitude) /
          point.timestamp.difference(_flightState.flightPath[_flightState.flightPath.length - 2].timestamp).inSeconds
        : 0.0;
    
    // Send data to watch
    _sendDataToWatch(point, verticalSpeedMps);
    
    // Notify listeners
    _throttledNotifyListeners();
    onFlightPathUpdated?.call();
  }
  
  Future<void> _saveCurrentFlight() async {
    if (_flightState.flightPath.isEmpty) return;
    
    final flight = Flight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: _flightState.startTime!,
      endTime: DateTime.now(),
      path: _flightState.flightPath,
      distanceTraveled: totalDistance,
      movingTime: movingTime,
      averageSpeed: averageSpeed,
      maxSpeed: maxSpeed,
      maxAltitude: _flightState.flightPath.map((p) => p.altitude).reduce((a, b) => a > b ? a : b),
      recordingStartedZulu: _flightState.recordingStartedZulu!,
      recordingStoppedZulu: _flightState.recordingStoppedZulu,
      movingStartedZulu: _flightState.movingStartedZulu,
      movingStoppedZulu: _flightState.movingStoppedZulu,
      movingSegments: _flightState.movingSegments,
      flightSegments: _flightState.flightSegments,
    );
    
    await _historyManager.saveFlight(flight);
    
    // Create logbook entry from flight if option is enabled
    try {
      final settingsService = SettingsService();
      if (settingsService.autoCreateLogbookEntry) {
        // This will be injected from the app's provider context
        if (_logBookService != null) {
          await _logBookService.createEntryFromFlight(flight);
        }
      }
    } catch (e) {
      debugPrint('Failed to create logbook entry: $e');
    }
  }
  
  // Flight history management
  Future<void> deleteFlight(int index) async {
    await _historyManager.deleteFlight(index);
    notifyListeners();
  }
  
  Future<String> exportFlight(Flight flight, {String format = 'gpx'}) async {
    return _historyManager.exportFlight(flight, format: format);
  }
  
  void _sendDataToWatch(FlightPoint point, double verticalSpeed) {
    // Convert units for watch display
    final altitudeFeet = point.altitude * FlightConstants.metersToFeet;
    final speedKnots = point.speed * FlightConstants.metersPerSecondToKnots;
    final verticalSpeedFpm = verticalSpeed * FlightConstants.metersPerSecondToFeetPerMinute;
    final pressureInHg = point.pressure * FlightConstants.hPaToInHg;
    
    _watchService.sendFlightData(
      altitude: altitudeFeet,
      groundSpeed: speedKnots,
      heading: point.heading,
      track: point.heading,
      verticalSpeed: verticalSpeedFpm,
      pressure: pressureInHg,
    );
  }
  
  void _throttledNotifyListeners() {
    final now = DateTime.now();
    if (_lastNotifyTime == null ||
        now.difference(_lastNotifyTime!).inMilliseconds > FlightConstants.notifyThrottleMs) {
      _lastNotifyTime = now;
      notifyListeners();
    } else {
      // Schedule a delayed notification if we're throttling
      _notifyTimer?.cancel();
      _notifyTimer = Timer(
        const Duration(milliseconds: FlightConstants.notifyThrottleMs),
        () {
          _lastNotifyTime = DateTime.now();
          notifyListeners();
        },
      );
    }
  }
  
  @override
  void dispose() {
    _sensorManager.dispose();
    _locationTracker.dispose();
    _barometerSubscription?.cancel();
    _barometerService?.dispose();
    _notifyTimer?.cancel();
    _watchTrackingSubscription?.cancel();
    _watchService.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}