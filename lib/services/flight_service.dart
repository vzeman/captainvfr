import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/flight.dart';
import '../models/flight_point.dart';
import 'barometer_service.dart';
import 'altitude_service.dart';
import 'flight_storage_service.dart';

// Constants for sensor data collection
const double _gravity = 9.80665; // Standard gravity (m/s²)

class FlightService with ChangeNotifier {
  final List<FlightPoint> _flightPath = [];
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription? _barometerSubscription;
  bool _isTracking = false;
  double? _currentHeading;
  double? _currentBaroAltitude;
  Position? _lastPosition;
  DateTime? _startTime;
  double _totalDistance = 0.0;
  double _averageSpeed = 0.0;
  
  // Services
  final BarometerService? _barometerService;
  final AltitudeService _altitudeService = AltitudeService();
  
  // Altitude tracking
  final List<double> _altitudeHistory = [];
  
  // Callback for when flight path updates
  final Function()? onFlightPathUpdated;
  
  // Getters
  List<FlightPoint> get flightPath => List.unmodifiable(_flightPath);
  bool get isTracking => _isTracking;
  
  // Flight history
  List<Flight> _flights = [];
  List<Flight> get flights => List.unmodifiable(_flights);
  
  // Sensor data streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  
  // Current sensor values
  double _currentXAccel = 0.0;
  double _currentYAccel = 0.0;
  double _currentZAccel = 0.0;
  double _currentXGyro = 0.0;
  double _currentYGyro = 0.0;
  double _currentZGyro = 0.0;
  
  // Compass subscription
  StreamSubscription<CompassEvent>? _compassSubscription;
  
  // Initialize with required services
  FlightService({this.onFlightPathUpdated, BarometerService? barometerService}) 
      : _barometerService = barometerService ?? BarometerService() {
    _initSensors();
    _initializeStorage();
  }
  
  Future<void> _initializeStorage() async {
    await FlightStorageService.init();
    await _loadFlights();
  }
  
  // Initialize sensor subscriptions
  void _initSensors() {
    // Accelerometer
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Convert from m/s² to g's if needed
      _currentXAccel = event.x / _gravity;
      _currentYAccel = event.y / _gravity;
      _currentZAccel = event.z / _gravity;
    });
    
    // Gyroscope
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _currentXGyro = event.x;
      _currentYGyro = event.y;
      _currentZGyro = event.z;
    });
  }
  
  Future<void> initialize() async {
    debugPrint('FlightService initialized');
    await _loadFlights();
  }
  
  // Load saved flights from storage
  Future<void> _loadFlights() async {
    try {
      _flights = await FlightStorageService.getAllFlights();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading flights: $e');
    }
  }
  

  
  // Get all flights
  Future<List<Flight>> getFlights() async {
    await _loadFlights(); // Ensure we have the latest data
    return _flights;
  }
  
  // Add a new flight to the history
  Future<void> addFlight(Flight flight) async {
    _flights.add(flight);
    await FlightStorageService.saveFlight(flight);
    notifyListeners();
  }
  
  // Clear all flight history
  Future<void> clearFlights() async {
    // Delete all flights from storage
    for (final flight in _flights) {
      await FlightStorageService.deleteFlight(flight.id);
    }
    _flights.clear();
    notifyListeners();
  }
  
  // Start tracking flight
  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _flightPath.clear();
    _altitudeHistory.clear();
    _startTime = DateTime.now();
    _lastPosition = null;
    _totalDistance = 0.0;
    _averageSpeed = 0.0;
    
    // Start barometer service if available
    _barometerService?.startListening();
    _altitudeService.startTracking();
    
    // Listen to barometer updates
    _barometerSubscription = _barometerService?.onBarometerUpdate.listen((_) {
      _currentBaroAltitude = _barometerService?.altitudeMeters;
      notifyListeners();
    });
    
    // Listen to altitude updates
    _altitudeService.altitudeStream.listen((altitude) {
      _altitudeHistory.add(altitude);
      // Keep the history at a reasonable size
      if (_altitudeHistory.length > 1000) {
        _altitudeHistory.removeAt(0);
      }
    });
    
    // Start listening to position updates
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // meters
      ),
    ).listen(_onPositionChanged);
  }
  
  void _onPositionChanged(Position position) {
    if (!_isTracking) return;

    final point = FlightPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      heading: _currentHeading ?? 0.0,
      accuracy: position.accuracy,
      verticalAccuracy: 0.0, // position.verticalAccuracy not available in current geolocator
      speedAccuracy: position.speedAccuracy,
      headingAccuracy: 0.0, // position.headingAccuracy not available in current geolocator
      xAcceleration: _currentXAccel,
      yAcceleration: _currentYAccel,
      zAcceleration: _currentZAccel,
      xGyro: _currentXGyro,
      yGyro: _currentYGyro,
      zGyro: _currentZGyro,
      pressure: _barometerService?.lastPressure ?? 0.0,
    );

    _flightPath.add(point);
    _updateFlightStats();
    onFlightPathUpdated?.call();
  }
  
  // Stop tracking flight
  Future<void> stopTracking() async {
    if (!_isTracking) return;
    _isTracking = false;
    _positionSubscription?.cancel();
    _barometerSubscription?.cancel();
    _barometerService?.stopListening();
    _altitudeService.stopTracking();
    
    // Calculate flight metrics
    if (_flightPath.isNotEmpty) {
      // Calculate max speed and moving time
      double maxSpeed = 0;
      Duration movingTime = Duration.zero;
      
      // Calculate speeds between points and moving time
      final speeds = <double>[];
      final altitudes = <double>[];
      final timestamps = <DateTime>[];
      
      for (int i = 1; i < _flightPath.length; i++) {
        final p1 = _flightPath[i-1];
        final p2 = _flightPath[i];
        
        final distance = Geolocator.distanceBetween(
          p1.position.latitude, p1.position.longitude,
          p2.position.latitude, p2.position.longitude,
        );
        
        final timeDiff = p2.timestamp.difference(p1.timestamp);
        final seconds = timeDiff.inMilliseconds / 1000.0;
        
        if (seconds > 0) {
          final speed = distance / seconds;
          speeds.add(speed);
          
          if (speed > 1.0) { // Consider moving if speed > 1 m/s
            movingTime += timeDiff;
          }
        }
        
        altitudes.add(p2.altitude);
        timestamps.add(p2.timestamp);
      }
      
      // Create a flight from the current path
      Flight flight = _createFlight();
      
      await addFlight(flight);
    }
    
    // Reset tracking state
    _flightPath.clear();
    _lastPosition = null;
    _totalDistance = 0.0;
    _averageSpeed = 0.0;
    
    notifyListeners();
  }
  
  // Create a flight from the current tracking data
  Flight _createFlight() {
    if (_flightPath.isEmpty) {
      throw Exception('No flight data to save');
    }
    
    final startTime = _flightPath.first.timestamp;
    final endTime = _flightPath.last.timestamp;
    
    // Calculate max altitude and speed
    double maxAltitude = 0.0;
    double maxSpeed = 0.0;
    
    // Convert flight path to FlightPoint objects
    final flightPoints = <FlightPoint>[];
    
    // Add first point
    if (_flightPath.isNotEmpty) {
      final firstPoint = _flightPath.first;
      flightPoints.add(FlightPoint(
        latitude: firstPoint.position.latitude,
        longitude: firstPoint.position.longitude,
        altitude: firstPoint.altitude,
        speed: 0.0, // Initial speed is 0
        heading: 0.0, // Will be updated with next point
        timestamp: firstPoint.timestamp,
        accuracy: firstPoint.accuracy,
        verticalAccuracy: 0.0, // Not available from Position
        speedAccuracy: 0.0, // Not available from Position
        headingAccuracy: 0.0, // Not available from Position
        xAcceleration: 0.0, // Will be updated by sensor service
        yAcceleration: 0.0, // Will be updated by sensor service
        zAcceleration: 0.0, // Will be updated by sensor service
        xGyro: 0.0, // Will be updated by sensor service
        yGyro: 0.0, // Will be updated by sensor service
        zGyro: 0.0, // Will be updated by sensor service
        pressure: 0.0, // Will be updated by barometer service
      ));
    }
    
    // Process subsequent points
    for (var i = 1; i < _flightPath.length; i++) {
      final prevPoint = _flightPath[i - 1];
      final currPoint = _flightPath[i];
      
      // Calculate distance between points
      final distance = Geolocator.distanceBetween(
        prevPoint.position.latitude,
        prevPoint.position.longitude,
        currPoint.position.latitude,
        currPoint.position.longitude,
      );
      
      // Calculate time difference in seconds
      final timeDiff = currPoint.timestamp.difference(prevPoint.timestamp).inSeconds.toDouble();
      final speed = timeDiff > 0 ? distance / timeDiff : 0.0; // m/s
      
      // Calculate heading (bearing) between points
      final heading = Geolocator.bearingBetween(
        prevPoint.position.latitude,
        prevPoint.position.longitude,
        currPoint.position.latitude,
        currPoint.position.longitude,
      );
      
      maxSpeed = math.max(maxSpeed, speed);
      maxAltitude = math.max(maxAltitude, currPoint.altitude);
      
      // Add the flight point with calculated data
      flightPoints.add(FlightPoint(
        latitude: currPoint.position.latitude,
        longitude: currPoint.position.longitude,
        altitude: currPoint.altitude,
        speed: speed,
        heading: heading,
        timestamp: currPoint.timestamp,
        accuracy: currPoint.accuracy,
        verticalAccuracy: 0.0, // Not available from Position
        speedAccuracy: 0.0, // Not available from Position
        headingAccuracy: 0.0, // Not available from Position
        xAcceleration: 0.0, // Will be updated by sensor service
        yAcceleration: 0.0, // Will be updated by sensor service
        zAcceleration: 0.0, // Will be updated by sensor service
        xGyro: 0.0, // Will be updated by sensor service
        yGyro: 0.0, // Will be updated by sensor service
        zGyro: 0.0, // Will be updated by sensor service
        pressure: 0.0, // Will be updated by barometer service
      ));
    }
    
    // Calculate moving time (time spent moving > 1 m/s)
    final movingTime = flightPoints.fold<Duration>(
      Duration.zero,
      (total, point) => point.speed > 1.0 
          ? total + Duration(seconds: 1) 
          : total,
    );
    
    return Flight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: endTime,
      path: flightPoints,
      maxAltitude: maxAltitude,
      distanceTraveled: _totalDistance,
      movingTime: movingTime,
      maxSpeed: maxSpeed,
      averageSpeed: _averageSpeed,
    );
  }

  // Clear the current flight path
  void clearFlightPath() {
    _flightPath.clear();
    onFlightPathUpdated?.call();
  }
  
  // Update flight statistics
  void _updateFlightStats() {
    // Calculate distance from last point if available
    if (_flightPath.length > 1) {
      final prevPoint = _flightPath[_flightPath.length - 2];
      final currentPoint = _flightPath.last;
      final distance = Geolocator.distanceBetween(
        prevPoint.position.latitude,
        prevPoint.position.longitude,
        currentPoint.position.latitude,
        currentPoint.position.longitude,
      );
      _totalDistance += distance;
      
      // Calculate speed based on distance and time
      final timeDiff = currentPoint.timestamp.difference(prevPoint.timestamp);
      final seconds = timeDiff.inMilliseconds / 1000.0;
      
      if (seconds > 0) {
        final currentSpeed = distance / seconds;
        _averageSpeed = _flightPath.length > 1 
            ? ((_averageSpeed * (_flightPath.length - 2)) + currentSpeed) / (_flightPath.length - 1)
            : currentSpeed;
      }
    }
    
    _lastPosition = Position(
      latitude: _flightPath.last.position.latitude,
      longitude: _flightPath.last.position.longitude,
      timestamp: _flightPath.last.timestamp,
      accuracy: _flightPath.last.accuracy,
      altitude: _flightPath.last.altitude,
      heading: _flightPath.last.heading,
      speed: _flightPath.last.speed,
      speedAccuracy: _flightPath.last.speedAccuracy,
      headingAccuracy: _flightPath.last.headingAccuracy,
      altitudeAccuracy: _flightPath.last.verticalAccuracy,
    );
    
    // Notify listeners
    notifyListeners();
  }
  
  // Format duration as HH:MM:SS
  String get formattedFlightTime {
    final duration = movingTime;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
  
  // Get the maximum speed from the current flight in m/s
  double get maxSpeed {
    if (_flightPath.isEmpty) return 0.0;
    return _flightPath.map((p) => p.speed).reduce((a, b) => a > b ? a : b);
  }
  
  // Get the current speed in m/s
  double get currentSpeed => _flightPath.isEmpty ? 0.0 : _flightPath.last.speed;
  
  // Get the current heading in degrees
  double? get currentHeading => _currentHeading;
  
  // Get the barometric altitude in meters
  double? get barometricAltitude => _currentBaroAltitude;
  
  // Get the barometric pressure in hPa if available
  double? get barometricPressure => _barometerService?.pressureHPa;
  
  // Get the total distance of the flight in meters
  double get totalDistance {
    if (_flightPath.length < 2) return 0.0;
    
    double distance = 0.0;
    for (int i = 1; i < _flightPath.length; i++) {
      final prev = _flightPath[i - 1];
      final current = _flightPath[i];
      distance += Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );
    }
    return distance;
  }
  
  // Initialize compass
  void _initCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      _currentHeading = event.heading;
      notifyListeners();
    });
  }
  
  // Get the total moving time of the current flight
  Duration get movingTime {
    if (_startTime == null) return Duration.zero;
    final endTime = _isTracking ? DateTime.now() : _flightPath.last.timestamp;
    return endTime.difference(_startTime!);
  }
  
  // Get the flight duration as a Duration object (alias for movingTime)
  Duration get flightDuration => movingTime;
  
  // Get the vertical speed in m/s
  double get verticalSpeed {
    if (_flightPath.length < 2) return 0.0;
    
    final currentPoint = _flightPath.last;
    final previousPoint = _flightPath[_flightPath.length - 2];
    final altitudeDiff = currentPoint.altitude - previousPoint.altitude;
    final timeDiff = currentPoint.timestamp.difference(previousPoint.timestamp).inSeconds;
    
    return timeDiff > 0 ? altitudeDiff / timeDiff : 0.0;
  }

  // Clean up resources
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _barometerSubscription?.cancel();
    _compassSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _barometerService?.dispose();
    _isTracking = false;
    _flightPath.clear();
    super.dispose();
  }
}
