import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/flight.dart';
import '../models/flight_point.dart';
import '../models/aircraft.dart';
import '../models/flight_segment.dart';
import '../models/moving_segment.dart';
import 'barometer_service.dart';
import 'altitude_service.dart';
import 'flight_storage_service.dart';

// Constants for sensor data collection
const double _gravity = 9.80665; // Standard gravity (m/s²)

class FlightService with ChangeNotifier {
  final List<FlightPoint> _flightPath = [];
  final List<FlightSegment> _flightSegments = [];
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription? _barometerSubscription;
  bool _isTracking = false;
  double? _currentHeading;
  double? _currentBaroAltitude;
  DateTime? _startTime;
  double _totalDistance = 0.0;
  double _averageSpeed = 0.0;
  
  // New comprehensive time tracking variables
  DateTime? _recordingStartedZulu;
  DateTime? _recordingStoppedZulu;
  DateTime? _movingStartedZulu;
  DateTime? _movingStoppedZulu;
  final List<MovingSegment> _movingSegments = [];
  bool _isCurrentlyMoving = false;
  DateTime? _currentMovingSegmentStart;
  double _currentMovingSegmentDistance = 0.0;
  final List<double> _currentMovingSegmentSpeeds = [];
  final List<double> _currentMovingSegmentHeadings = [];
  final List<double> _currentMovingSegmentAltitudes = [];
  FlightPoint? _currentMovingSegmentStartPoint;
  final List<FlightPoint> _pausePoints = [];

  // Flight segment tracking
  FlightPoint? _lastSegmentPoint;

  // Constants
  static const double _movingSpeedThreshold = 1.0 / 3.6; // 1 km/h in m/s
  static const double _minSegmentDistance = 25.0; // Minimum 250m segment length
  static const double _significantHeadingChange = 10.0; // 15 degrees
  static const double _significantAltitudeChange = 30.0; // 30 meters

  // Services
  final BarometerService? _barometerService;
  final AltitudeService _altitudeService = AltitudeService();
  
  // Altitude tracking
  final List<double> _altitudeHistory = [];
  
  // Callback for when flight path updates
  final Function()? onFlightPathUpdated;
  

  // Selected aircraft (for fuel consumption)
  Aircraft? _selectedAircraft;

  /// Set the aircraft used for this flight (for fuel calc).
  void setAircraft(Aircraft aircraft) {
    _selectedAircraft = aircraft;
    notifyListeners();
  }

  // Getters
  List<FlightPoint> get flightPath => List.unmodifiable(_flightPath);
  List<FlightSegment> get flightSegments => List.unmodifiable(_flightSegments);
  bool get isTracking => _isTracking;

  /// Total fuel consumed so far (gal) based on moving time and aircraft rate.
  double get fuelUsed {
    if (_selectedAircraft == null) return 0;
    final hrs = movingTime.inMilliseconds / 3600000.0;
    return _selectedAircraft!.fuelConsumption * hrs;
  }
  
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
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Convert from m/s² to g's if needed
      _currentXAccel = event.x / _gravity;
      _currentYAccel = event.y / _gravity;
      _currentZAccel = event.z / _gravity;
    });
    
    // Gyroscope
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
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
  
  // Delete a specific flight from the history
  Future<void> deleteFlight(Flight flight) async {
    _flights.remove(flight);
    await FlightStorageService.deleteFlight(flight.id);
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
    _totalDistance = 0.0;
    _averageSpeed = 0.0;
    
    // Initialize comprehensive time tracking
    _recordingStartedZulu = DateTime.now().toUtc();
    _recordingStoppedZulu = null;
    _movingStartedZulu = null;
    _movingStoppedZulu = null;
    _movingSegments.clear();
    _isCurrentlyMoving = false;
    _currentMovingSegmentStart = null;
    _currentMovingSegmentDistance = 0.0;
    _currentMovingSegmentSpeeds.clear();
    _currentMovingSegmentHeadings.clear();
    _currentMovingSegmentAltitudes.clear();
    _currentMovingSegmentStartPoint = null;
    _pausePoints.clear();

    // Start barometer service if available
    _barometerService?.startListening();
    _altitudeService.startTracking();
    
    // Listen to barometer updates
    _barometerSubscription = _barometerService?.onBarometerUpdate.listen((_) {
      _currentBaroAltitude = _barometerService.altitudeMeters;
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

    // Get the best available altitude measurement
    final bestAltitude = _getBestAltitude(position.altitude);

    final point = FlightPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: bestAltitude,
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

    // Handle moving segment tracking
    _updateMovingSegments(point);

    // Handle flight segment tracking
    _updateFlightSegments(point);

    _updateFlightStats();
    onFlightPathUpdated?.call();
  }

  /// Get the best available altitude measurement by combining GPS and barometric data
  double _getBestAltitude(double gpsAltitude) {
    final barometricAltitude = _barometerService?.altitudeMeters;
    final altitudeFromService = _altitudeService.currentAltitude;

    // Priority order:
    // 1. Altitude service (if available and seems reliable)
    // 2. Barometric altitude (if available and seems reasonable)
    // 3. GPS altitude (fallback)

    if (altitudeFromService != null && _isAltitudeReasonable(altitudeFromService)) {
      return altitudeFromService;
    }

    if (barometricAltitude != null && _isAltitudeReasonable(barometricAltitude)) {
      // If we have both GPS and barometric, use weighted average favoring barometric
      // Barometric is typically more accurate for relative changes
      if (_isAltitudeReasonable(gpsAltitude)) {
        // Weight: 70% barometric, 30% GPS for better accuracy
        return (barometricAltitude * 0.7) + (gpsAltitude * 0.3);
      }
      return barometricAltitude;
    }

    // Fallback to GPS altitude
    return gpsAltitude;
  }

  /// Check if altitude value seems reasonable (basic sanity check)
  bool _isAltitudeReasonable(double altitude) {
    // Basic sanity check: altitude between -500m (Dead Sea level) and 15000m (reasonable aircraft altitude)
    return altitude >= -500.0 && altitude <= 15000.0;
  }

  /// Update moving segments based on current speed
  void _updateMovingSegments(FlightPoint point) {
    final isMoving = point.speed > _movingSpeedThreshold;
    final now = DateTime.now().toUtc();

    if (isMoving && !_isCurrentlyMoving) {
      // Started moving
      _isCurrentlyMoving = true;
      _currentMovingSegmentStart = now;
      _currentMovingSegmentDistance = 0.0;
      _currentMovingSegmentSpeeds.clear();
      _currentMovingSegmentHeadings.clear();
      _currentMovingSegmentAltitudes.clear();
      _currentMovingSegmentStartPoint = point;

      _movingStartedZulu ??= now;
    } else if (!isMoving && _isCurrentlyMoving) {
      // Stopped moving
      _isCurrentlyMoving = false;
      _movingStoppedZulu = now;

      // Finalize the current moving segment
      if (_currentMovingSegmentStart != null && _currentMovingSegmentStartPoint != null) {
        // Calculate averages for the segment
        final avgSpeed = _currentMovingSegmentSpeeds.isNotEmpty
            ? _currentMovingSegmentSpeeds.reduce((a, b) => a + b) / _currentMovingSegmentSpeeds.length
            : 0.0;
        final avgHeading = _currentMovingSegmentHeadings.isNotEmpty
            ? _currentMovingSegmentHeadings.reduce((a, b) => a + b) / _currentMovingSegmentHeadings.length
            : 0.0;
        final avgAltitude = _currentMovingSegmentAltitudes.isNotEmpty
            ? _currentMovingSegmentAltitudes.reduce((a, b) => a + b) / _currentMovingSegmentAltitudes.length
            : _currentMovingSegmentStartPoint!.altitude;

        // Calculate min/max altitudes
        final maxAlt = _currentMovingSegmentAltitudes.isNotEmpty
            ? _currentMovingSegmentAltitudes.reduce((a, b) => a > b ? a : b)
            : _currentMovingSegmentStartPoint!.altitude;
        final minAlt = _currentMovingSegmentAltitudes.isNotEmpty
            ? _currentMovingSegmentAltitudes.reduce((a, b) => a < b ? a : b)
            : _currentMovingSegmentStartPoint!.altitude;

        final segment = MovingSegment(
          start: _currentMovingSegmentStart!,
          end: now,
          duration: now.difference(_currentMovingSegmentStart!),
          distance: _currentMovingSegmentDistance,
          averageSpeed: avgSpeed,
          averageHeading: avgHeading,
          startAltitude: _currentMovingSegmentStartPoint!.altitude,
          endAltitude: point.altitude,
          averageAltitude: avgAltitude,
          maxAltitude: maxAlt,
          minAltitude: minAlt,
        );
        _movingSegments.add(segment);
      }

      // Add pause point
      _pausePoints.add(point);
    }

    if (_isCurrentlyMoving) {
      // Update current segment data
      _currentMovingSegmentSpeeds.add(point.speed);
      _currentMovingSegmentHeadings.add(point.heading);
      _currentMovingSegmentAltitudes.add(point.altitude);

      // Calculate distance if we have a previous point
      if (_flightPath.length > 1) {
        final prevPoint = _flightPath[_flightPath.length - 2];
        final distance = Geolocator.distanceBetween(
          prevPoint.latitude,
          prevPoint.longitude,
          point.latitude,
          point.longitude,
        );
        _currentMovingSegmentDistance += distance;
      }
    }
  }

  /// Update flight segments based on significant changes in direction or altitude
  void _updateFlightSegments(FlightPoint point) {
    if (_lastSegmentPoint == null) {
      // First point, initialize segment
      _lastSegmentPoint = point;
      return;
    }

    final distance = Geolocator.distanceBetween(
      _lastSegmentPoint!.latitude,
      _lastSegmentPoint!.longitude,
      point.latitude,
      point.longitude,
    );

    // Check if distance is sufficient to consider a new segment
    if (distance < _minSegmentDistance) {
      return; // Not enough distance for a new segment
    }

    // Check for significant changes
    final headingChange = (_lastSegmentPoint!.heading - point.heading).abs();
    final altitudeChange = (_lastSegmentPoint!.altitude - point.altitude).abs();

    if (headingChange > _significantHeadingChange || altitudeChange > _significantAltitudeChange) {
      // Significant change detected, create a new segment
      // Create a list of points for this segment (from last segment point to current point)
      final segmentPoints = <FlightPoint>[];

      // Find all points between the last segment point and current point
      bool foundStart = false;
      for (final flightPoint in _flightPath) {
        if (flightPoint == _lastSegmentPoint) {
          foundStart = true;
        }
        if (foundStart) {
          segmentPoints.add(flightPoint);
          if (flightPoint == point) {
            break;
          }
        }
      }

      // Only create segment if we have enough points
      if (segmentPoints.length >= 2) {
        final segment = FlightSegment.fromPoints(segmentPoints);
        _flightSegments.add(segment);
      }

      _lastSegmentPoint = point; // Update last segment point
    }
  }

  // Stop tracking flight
  Future<void> stopTracking() async {
    if (!_isTracking) return;
    _isTracking = false;

    // Set recording stopped time
    _recordingStoppedZulu = DateTime.now().toUtc();

    // Finalize any ongoing moving segment
    if (_isCurrentlyMoving && _currentMovingSegmentStart != null && _currentMovingSegmentStartPoint != null) {
      // Calculate averages for final segment
      final avgSpeed = _currentMovingSegmentSpeeds.isNotEmpty
          ? _currentMovingSegmentSpeeds.reduce((a, b) => a + b) / _currentMovingSegmentSpeeds.length
          : 0.0;
      final avgHeading = _currentMovingSegmentHeadings.isNotEmpty
          ? _currentMovingSegmentHeadings.reduce((a, b) => a + b) / _currentMovingSegmentHeadings.length
          : 0.0;
      final avgAltitude = _currentMovingSegmentAltitudes.isNotEmpty
          ? _currentMovingSegmentAltitudes.reduce((a, b) => a + b) / _currentMovingSegmentAltitudes.length
          : _currentMovingSegmentStartPoint!.altitude;

      // Calculate min/max altitudes
      final maxAlt = _currentMovingSegmentAltitudes.isNotEmpty
          ? _currentMovingSegmentAltitudes.reduce((a, b) => a > b ? a : b)
          : _currentMovingSegmentStartPoint!.altitude;
      final minAlt = _currentMovingSegmentAltitudes.isNotEmpty
          ? _currentMovingSegmentAltitudes.reduce((a, b) => a < b ? a : b)
          : _currentMovingSegmentStartPoint!.altitude;

      final segment = MovingSegment(
        start: _currentMovingSegmentStart!,
        end: _recordingStoppedZulu!,
        duration: _recordingStoppedZulu!.difference(_currentMovingSegmentStart!),
        distance: _currentMovingSegmentDistance,
        averageSpeed: avgSpeed,
        averageHeading: avgHeading,
        startAltitude: _currentMovingSegmentStartPoint!.altitude,
        endAltitude: _flightPath.isNotEmpty ? _flightPath.last.altitude : _currentMovingSegmentStartPoint!.altitude,
        averageAltitude: avgAltitude,
        maxAltitude: maxAlt,
        minAltitude: minAlt,
      );
      _movingSegments.add(segment);
    }

    _positionSubscription?.cancel();
    _barometerSubscription?.cancel();
    _barometerService?.stopListening();
    _altitudeService.stopTracking();
    
    // Create a flight from the current path
    if (_flightPath.isNotEmpty) {
      Flight flight = _createFlight();
      await addFlight(flight);
    }
    
    // Reset tracking state
    _resetTrackingState();

    notifyListeners();
  }

  // Reset all tracking state
  void _resetTrackingState() {
    _flightPath.clear();
    _totalDistance = 0.0;
    _averageSpeed = 0.0;
    _recordingStartedZulu = null;
    _recordingStoppedZulu = null;
    _movingStartedZulu = null;
    _movingStoppedZulu = null;
    _movingSegments.clear();
    _flightSegments.clear();
    _isCurrentlyMoving = false;
    _currentMovingSegmentStart = null;
    _currentMovingSegmentDistance = 0.0;
    _currentMovingSegmentSpeeds.clear();
    _currentMovingSegmentHeadings.clear();
    _currentMovingSegmentAltitudes.clear();
    _currentMovingSegmentStartPoint = null;
    _pausePoints.clear();
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
      recordingStartedZulu: _recordingStartedZulu!,
      recordingStoppedZulu: _recordingStoppedZulu,
      movingStartedZulu: _movingStartedZulu,
      movingStoppedZulu: _movingStoppedZulu,
      movingSegments: List.from(_movingSegments),
      flightSegments: List.from(_flightSegments),
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
