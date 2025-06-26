import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
// latlong2 is used via flight_point.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flight.dart';
import '../models/flight_point.dart';
import 'barometer_service.dart';
import 'altitude_service.dart';

const String _flightKey = 'saved_flights';

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
  
  // Initialize with required services
  FlightService({required BarometerService barometerService, this.onFlightPathUpdated}) 
    : _barometerService = barometerService;
  
  Future<void> initialize() async {
    debugPrint('FlightService initialized');
    await _loadFlights();
  }
  
  // Load saved flights from storage
  Future<void> _loadFlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? flightsJson = prefs.getString(_flightKey);
      
      if (flightsJson != null) {
        final List<dynamic> decoded = jsonDecode(flightsJson);
        _flights = decoded.map((item) => Flight.fromMap(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading flights: $e');
    }
  }
  
  // Save flights to storage
  Future<void> _saveFlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = jsonEncode(
        _flights.map((flight) => flight.toMap()).toList(),
      );
      await prefs.setString(_flightKey, encodedData);
    } catch (e) {
      debugPrint('Error saving flights: $e');
    }
  }
  
  // Get all flights
  Future<List<Flight>> getFlights() async {
    await _loadFlights(); // Ensure we have the latest data
    return _flights;
  }
  
  // Add a completed flight
  Future<void> addFlight(Flight flight) async {
    _flights.insert(0, flight); // Add new flights at the beginning
    await _saveFlights();
    notifyListeners();
  }
  
  // Clear all flight history
  Future<void> clearFlights() async {
    _flights.clear();
    await _saveFlights();
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
    ).listen((position) {
      final now = DateTime.now();
      final point = FlightPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: _currentBaroAltitude ?? position.altitude, // Use baro altitude if available
        speed: position.speed,
        heading: _currentHeading ?? 0,
        timestamp: now,
      );
      
      _addFlightPoint(point);
    });
    
    // Start listening to compass updates
    FlutterCompass.events?.listen((event) {
      _currentHeading = event.heading;
      notifyListeners();
    });
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
  
  // Create a new Flight from the current flight path
  Flight _createFlight() {
    if (_flightPath.isEmpty) {
      throw StateError('Cannot create flight from empty flight path');
    }

    final startTime = _flightPath.first.timestamp;
    final endTime = _flightPath.last.timestamp;
    
    // Calculate max altitude
    final maxAltitude = _flightPath
        .map((point) => point.altitude)
        .reduce((a, b) => a > b ? a : b);
    
    // Calculate speeds between points
    final speeds = <double>[];
    for (var i = 1; i < _flightPath.length; i++) {
      final p1 = _flightPath[i - 1];
      final p2 = _flightPath[i];
      final distance = Geolocator.distanceBetween(
        p1.position.latitude,
        p1.position.longitude,
        p2.position.latitude,
        p2.position.longitude,
      );
      final timeDiff = p2.timestamp.difference(p1.timestamp).inMilliseconds / 1000.0;
      speeds.add(timeDiff > 0 ? distance / timeDiff : 0);
    }
    
    // Calculate max speed
    final maxSpeed = speeds.isNotEmpty 
        ? speeds.reduce((a, b) => a > b ? a : b)
        : 0.0;
    
    // Calculate moving time (time spent moving > 1 m/s)
    final movingTime = speeds.fold<Duration>(
      Duration.zero,
      (total, speed) => speed > 1.0 
          ? total + Duration(seconds: 1) 
          : total,
    );
    
    return Flight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: endTime,
      path: _flightPath.map((point) => LatLng(
        point.position.latitude,
        point.position.longitude,
      )).toList(),
      maxAltitude: maxAltitude,
      distanceTraveled: _totalDistance,
      movingTime: movingTime,
      maxSpeed: maxSpeed,
      averageSpeed: _averageSpeed,
      timestamps: _flightPath.map((p) => p.timestamp).toList(),
      speeds: speeds,
      altitudes: _flightPath.map((p) => p.altitude).toList(),
    );
  }

  // Clear the current flight path
  void clearFlightPath() {
    _flightPath.clear();
    onFlightPathUpdated?.call();
  }
  
  // Add a new position to the flight path
  void _addFlightPoint(FlightPoint point) {
    _flightPath.add(point);
    
    // Calculate distance from last point if available
    if (_flightPath.length > 1) {
      final prevPoint = _flightPath[_flightPath.length - 2];
      final distance = Geolocator.distanceBetween(
        prevPoint.position.latitude,
        prevPoint.position.longitude,
        point.position.latitude,
        point.position.longitude,
      );
      _totalDistance += distance;
      
      // Calculate speed based on distance and time
      final timeDiff = point.timestamp.difference(prevPoint.timestamp);
      final seconds = timeDiff.inMilliseconds / 1000.0;
      
      if (seconds > 0) {
        final currentSpeed = distance / seconds;
        _averageSpeed = _flightPath.length > 1 
            ? ((_averageSpeed * (_flightPath.length - 2)) + currentSpeed) / (_flightPath.length - 1)
            : currentSpeed;
      }
    }
    
    _lastPosition = Position(
      latitude: point.position.latitude,
      longitude: point.position.longitude,
      timestamp: point.timestamp,
      accuracy: 0,
      altitude: point.altitude,
      heading: point.heading,
      speed: point.speed,
      speedAccuracy: 0,
      headingAccuracy: 0,
      altitudeAccuracy: 0,
    );
    
    // Notify listeners
    notifyListeners();
  }
  
  // Get the duration of the current flight
  Duration get flightDuration {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }
  
  // Get the total distance of the current flight in meters
  double get flightDistance => _totalDistance;
  
  // Get the average speed in meters per second
  double get averageSpeed {
    final duration = flightDuration;
    if (duration.inSeconds == 0) return 0.0;
    return _totalDistance / duration.inSeconds;
  }
  
  // Get the current flight time as a formatted string (HH:MM:SS)
  String get formattedFlightTime {
    final duration = flightDuration;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
  
  // Calculate total distance of the flight path in meters
  double getTotalDistance() {
    if (_flightPath.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    for (int i = 1; i < _flightPath.length; i++) {
      final prev = _flightPath[i - 1];
      final current = _flightPath[i];
      totalDistance += Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );
    }
    
    return totalDistance;
  }
  
  // Calculate average speed in km/h
  double getAverageSpeed() {
    if (_flightPath.isEmpty) return 0.0;
    
    final totalSpeed = _flightPath
        .map((point) => point.speed)
        .reduce((a, b) => a + b);
    
    return (totalSpeed / _flightPath.length) * 3.6; // Convert m/s to km/h
  }
  
  // Clean up resources
  @override
  void dispose() {
    _barometerSubscription?.cancel();
    _barometerService?.dispose();
    _positionSubscription?.cancel();
    _isTracking = false;
    _flightPath.clear();
    super.dispose();
  }
  
  // Get current barometric altitude if available
  double? get barometricAltitude => _currentBaroAltitude;
  
  // Get current barometric pressure if available
  double? get barometricPressure => _barometerService?.pressureHPa;
  
  // Get current speed in m/s
  double get currentSpeed => _lastPosition?.speed ?? 0.0;
  
  // Get current heading in degrees
  double? get currentHeading => _currentHeading;
  
  // Calculate vertical speed in m/s
  double get verticalSpeed {
    if (_flightPath.length < 2) return 0.0;
    
    final currentPoint = _flightPath.last;
    final previousPoint = _flightPath[_flightPath.length - 2];
    final altitudeDiff = currentPoint.altitude - previousPoint.altitude;
    final timeDiff = currentPoint.timestamp.difference(previousPoint.timestamp).inSeconds;
    
    return timeDiff > 0 ? altitudeDiff / timeDiff : 0.0;
  }
}
