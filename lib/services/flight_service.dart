import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
    _initializeStorage();
  }

  Future<void> _initializeStorage() async {
    await FlightStorageService.init();
    await _loadFlights();
  }

  // Start sensor subscriptions when tracking begins
  void _startSensors() {
    // Accelerometer with reduced sampling rate
    try {
      _accelerometerSubscription =
          accelerometerEventStream(
            samplingPeriod: const Duration(
              milliseconds: 100,
            ), // 10Hz instead of max
          ).listen(
            (AccelerometerEvent event) {
              // Convert from m/s² to g's
              _currentXAccel = event.x / _gravity;
              _currentYAccel = event.y / _gravity;
              _currentZAccel = event.z / _gravity;
              // Don't call notifyListeners here - too frequent
            },
            onError: (error) {
              // debugPrint('Accelerometer error: $error');
            },
          );
    } catch (e) {
      // debugPrint('Failed to initialize accelerometer: $e');
    }

    // Gyroscope with reduced sampling rate
    _gyroscopeSubscription =
        gyroscopeEventStream(
          samplingPeriod: const Duration(
            milliseconds: 100,
          ), // 10Hz instead of max
        ).listen((GyroscopeEvent event) {
          _currentXGyro = event.x;
          _currentYGyro = event.y;
          _currentZGyro = event.z;
          // Don't call notifyListeners here - too frequent
        });

    // Compass - throttle updates
    DateTime? lastCompassUpdate;
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        _currentHeading = event.heading;
        // Throttle compass updates to max 2 per second
        final now = DateTime.now();
        if (lastCompassUpdate == null ||
            now.difference(lastCompassUpdate!).inMilliseconds > 500) {
          lastCompassUpdate = now;
          notifyListeners();
        }
      }
    });
  }

  Future<void> initialize() async {
    await _loadFlights();
  }

  // Load saved flights from storage
  Future<void> _loadFlights() async {
    try {
      _flights = await FlightStorageService.getAllFlights();
      notifyListeners();
    } catch (e) {
      // debugPrint('Error loading flights: $e');
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

    // Enable wakelock to keep screen on during tracking
    WakelockPlus.enable();

    // Start sensors only when tracking begins
    _startSensors();

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
    // Configure location settings for background tracking
    late LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // meters - increased to reduce updates
        intervalDuration: const Duration(
          seconds: 2,
        ), // faster updates but with distance filter
        // Enable background location updates
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Captain VFR is tracking your flight",
          notificationTitle: "Flight Tracking Active",
          enableWakeLock: true,
        ),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // meters - increased to reduce updates
        pauseLocationUpdatesAutomatically: false,
        // Show background location indicator
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.otherNavigation,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // meters
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPositionChanged);
  }

  void _onPositionChanged(Position position) {
    if (!_isTracking) return;

    // Defer heavy processing to next frame to keep UI responsive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPositionUpdate(position);
    });
  }

  void _processPositionUpdate(Position position) {
    if (!_isTracking) return;

    // Get the best available altitude measurement
    final bestAltitude = _getBestAltitude(position.altitude);

    // Calculate heading from GPS movement
    double heading = _currentHeading ?? 0.0;
    if (_flightPath.isNotEmpty) {
      final lastPoint = _flightPath.last;
      // Calculate distance to check if we're actually moving
      final distance = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        position.latitude,
        position.longitude,
      );

      // Only update heading if we've moved more than 5 meters
      if (distance > 5.0) {
        final computedHeading = Geolocator.bearingBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          position.latitude,
          position.longitude,
        );
        // Convert from [-180, 180] to [0, 360]
        heading = computedHeading < 0 ? computedHeading + 360 : computedHeading;

        // Always update GPS-based heading if compass is not available
        if (FlutterCompass.events == null || _currentHeading == null) {
          _currentHeading = heading;
          notifyListeners();
        }
      }
    }

    // Calculate vertical speed in m/s
    double calculatedVerticalSpeed = 0.0;
    if (_flightPath.isNotEmpty) {
      final lastPoint = _flightPath.last;
      final altitudeDiff = bestAltitude - lastPoint.altitude;
      final timeDiff =
          DateTime.now().difference(lastPoint.timestamp).inMilliseconds /
          1000.0;

      if (timeDiff > 0) {
        calculatedVerticalSpeed = altitudeDiff / timeDiff; // m/s
      }
    }

    // Get smoothed speed to avoid GPS zero jumps
    double smoothedSpeed = _getSmoothedSpeed(position.speed);

    final point = FlightPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: bestAltitude,
      speed: smoothedSpeed,
      heading: heading,
      accuracy: position.accuracy,
      verticalAccuracy:
          0.0, // position.verticalAccuracy not available in current geolocator
      speedAccuracy: position.speedAccuracy,
      headingAccuracy:
          0.0, // position.headingAccuracy not available in current geolocator
      xAcceleration: _currentXAccel,
      yAcceleration: _currentYAccel,
      zAcceleration: _currentZAccel,
      xGyro: _currentXGyro,
      yGyro: _currentYGyro,
      zGyro: _currentZGyro,
      pressure: _barometerService?.lastPressure ?? 0.0,
      verticalSpeed: calculatedVerticalSpeed,
    );

    _flightPath.add(point);

    // Handle moving segment tracking
    _updateMovingSegments(point);

    // Handle flight segment tracking
    _updateFlightSegments(point);

    _updateFlightStats();

    // Throttle notifications to avoid excessive UI updates
    _throttledNotifyListeners();
    onFlightPathUpdated?.call();
  }

  /// Get smoothed speed to avoid GPS zero jumps
  double _getSmoothedSpeed(double gpsSpeed) {
    // If we don't have enough data, return GPS speed
    if (_flightPath.length < 3) {
      return gpsSpeed;
    }

    // If GPS reports zero but we've been moving, calculate speed from position change
    if (gpsSpeed == 0.0) {
      final recentPoints = _flightPath.reversed.take(3).toList();

      if (recentPoints.length >= 2) {
        // Calculate speed from last few position changes
        double totalDistance = 0.0;
        double totalTime = 0.0;

        for (int i = 0; i < recentPoints.length - 1; i++) {
          final distance = Geolocator.distanceBetween(
            recentPoints[i].latitude,
            recentPoints[i].longitude,
            recentPoints[i + 1].latitude,
            recentPoints[i + 1].longitude,
          );
          final timeDiff = recentPoints[i].timestamp
              .difference(recentPoints[i + 1].timestamp)
              .inSeconds
              .abs();

          if (timeDiff > 0) {
            totalDistance += distance;
            totalTime += timeDiff;
          }
        }

        if (totalTime > 0) {
          final calculatedSpeed = totalDistance / totalTime;
          // Only use calculated speed if it's reasonable (less than 100 m/s for small aircraft)
          if (calculatedSpeed < 100.0) {
            return calculatedSpeed;
          }
        }
      }
    }

    // If GPS speed seems reasonable, use weighted average with recent speeds
    if (gpsSpeed > 0.0 && gpsSpeed < 100.0) {
      final recentSpeeds = _flightPath.reversed
          .take(3)
          .map((p) => p.speed)
          .where((s) => s > 0)
          .toList();
      if (recentSpeeds.isNotEmpty) {
        // Weighted average: current reading gets 50% weight, recent average gets 50%
        final avgRecentSpeed =
            recentSpeeds.reduce((a, b) => a + b) / recentSpeeds.length;
        return (gpsSpeed * 0.5) + (avgRecentSpeed * 0.5);
      }
    }

    return gpsSpeed;
  }

  /// Get the best available altitude measurement by combining GPS and barometric data
  double _getBestAltitude(double gpsAltitude) {
    final barometricAltitude = _barometerService?.altitudeMeters;
    final altitudeFromService = _altitudeService.currentAltitude;

    // Priority order:
    // 1. Barometric altitude (most accurate for aviation)
    // 2. Altitude service (if available)
    // 3. GPS altitude (fallback, with smoothing)

    // Use barometric altitude if available and reasonable
    if (barometricAltitude != null &&
        _isAltitudeReasonable(barometricAltitude)) {
      // Add altitude to history for smoothing
      _altitudeHistory.add(barometricAltitude);
      if (_altitudeHistory.length > 10) {
        _altitudeHistory.removeAt(0);
      }
      return _getSmoothedAltitude(barometricAltitude);
    }

    // Use altitude service if available
    if (altitudeFromService != null &&
        _isAltitudeReasonable(altitudeFromService)) {
      _altitudeHistory.add(altitudeFromService);
      if (_altitudeHistory.length > 10) {
        _altitudeHistory.removeAt(0);
      }
      return _getSmoothedAltitude(altitudeFromService);
    }

    // Fallback to GPS altitude with heavy smoothing to avoid jumps
    if (_isAltitudeReasonable(gpsAltitude)) {
      _altitudeHistory.add(gpsAltitude);
      if (_altitudeHistory.length > 10) {
        _altitudeHistory.removeAt(0);
      }
      return _getSmoothedAltitude(gpsAltitude);
    }

    // If GPS altitude is unreasonable, use last known good altitude
    if (_altitudeHistory.isNotEmpty) {
      return _altitudeHistory.last;
    }

    // Absolute fallback - use sea level
    return 0.0;
  }

  /// Get smoothed altitude to avoid sinusoidal patterns
  double _getSmoothedAltitude(double currentAltitude) {
    if (_altitudeHistory.length < 3) {
      return currentAltitude;
    }

    // Use median of last few values to filter out outliers
    final recentValues = _altitudeHistory.reversed.take(5).toList()..sort();
    final median = recentValues[recentValues.length ~/ 2];

    // If current value is too far from median, use weighted average
    final deviation = (currentAltitude - median).abs();
    if (deviation > 50.0) {
      // More than 50m deviation is suspicious
      // Use 30% current, 70% median
      return (currentAltitude * 0.3) + (median * 0.7);
    }

    // Otherwise use weighted average of recent values
    double sum = 0.0;
    double weight = 0.0;
    for (int i = 0; i < math.min(5, _altitudeHistory.length); i++) {
      final w = 1.0 / (i + 1); // More recent values get higher weight
      sum += _altitudeHistory[_altitudeHistory.length - 1 - i] * w;
      weight += w;
    }

    return sum / weight;
  }

  /// Check if altitude value seems reasonable (basic sanity check)
  bool _isAltitudeReasonable(double altitude) {
    // Sea level should be 0m, reject negative values and unreasonably high values
    // Most small aircraft operate below 10,000m
    return altitude >= 0.0 && altitude <= 10000.0;
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
      if (_currentMovingSegmentStart != null &&
          _currentMovingSegmentStartPoint != null) {
        // Calculate averages for the segment
        final avgSpeed = _currentMovingSegmentSpeeds.isNotEmpty
            ? _currentMovingSegmentSpeeds.reduce((a, b) => a + b) /
                  _currentMovingSegmentSpeeds.length
            : 0.0;
        final avgHeading = _currentMovingSegmentHeadings.isNotEmpty
            ? _currentMovingSegmentHeadings.reduce((a, b) => a + b) /
                  _currentMovingSegmentHeadings.length
            : 0.0;
        final avgAltitude = _currentMovingSegmentAltitudes.isNotEmpty
            ? _currentMovingSegmentAltitudes.reduce((a, b) => a + b) /
                  _currentMovingSegmentAltitudes.length
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

    if (headingChange > _significantHeadingChange ||
        altitudeChange > _significantAltitudeChange) {
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

    // Stop sensors to save battery
    _stopSensors();

    // Disable wakelock when tracking stops
    WakelockPlus.disable();

    // Set recording stopped time
    _recordingStoppedZulu = DateTime.now().toUtc();

    // Finalize any ongoing moving segment
    if (_isCurrentlyMoving &&
        _currentMovingSegmentStart != null &&
        _currentMovingSegmentStartPoint != null) {
      // Calculate averages for final segment
      final avgSpeed = _currentMovingSegmentSpeeds.isNotEmpty
          ? _currentMovingSegmentSpeeds.reduce((a, b) => a + b) /
                _currentMovingSegmentSpeeds.length
          : 0.0;
      final avgHeading = _currentMovingSegmentHeadings.isNotEmpty
          ? _currentMovingSegmentHeadings.reduce((a, b) => a + b) /
                _currentMovingSegmentHeadings.length
          : 0.0;
      final avgAltitude = _currentMovingSegmentAltitudes.isNotEmpty
          ? _currentMovingSegmentAltitudes.reduce((a, b) => a + b) /
                _currentMovingSegmentAltitudes.length
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
        duration: _recordingStoppedZulu!.difference(
          _currentMovingSegmentStart!,
        ),
        distance: _currentMovingSegmentDistance,
        averageSpeed: avgSpeed,
        averageHeading: avgHeading,
        startAltitude: _currentMovingSegmentStartPoint!.altitude,
        endAltitude: _flightPath.isNotEmpty
            ? _flightPath.last.altitude
            : _currentMovingSegmentStartPoint!.altitude,
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

  // Optimize G-force data by keeping only max values per minute
  List<FlightPoint> _optimizeGForceData(List<FlightPoint> points) {
    if (points.isEmpty) return points;

    final optimizedPoints = <FlightPoint>[];
    Map<DateTime, List<FlightPoint>> minuteGroups = {};

    // Group points by minute
    for (final point in points) {
      final minuteKey = DateTime(
        point.timestamp.year,
        point.timestamp.month,
        point.timestamp.day,
        point.timestamp.hour,
        point.timestamp.minute,
      );
      minuteGroups.putIfAbsent(minuteKey, () => []).add(point);
    }

    // For each minute, keep the point with the highest G-force
    for (final entry in minuteGroups.entries) {
      final pointsInMinute = entry.value;

      if (pointsInMinute.length == 1) {
        // Only one point in this minute, keep it as is
        optimizedPoints.add(pointsInMinute.first);
      } else {
        // Find the point with maximum total G-force
        FlightPoint? maxGPoint;
        double maxTotalG = 0.0;

        for (final point in pointsInMinute) {
          final totalG = math.sqrt(
            point.xAcceleration * point.xAcceleration +
                point.yAcceleration * point.yAcceleration +
                point.zAcceleration * point.zAcceleration,
          );

          if (totalG > maxTotalG) {
            maxTotalG = totalG;
            maxGPoint = point;
          }
        }

        // Keep the point with max G-force, but also keep first and last points of the minute
        // to maintain accurate position tracking
        optimizedPoints.add(pointsInMinute.first);
        if (maxGPoint != null &&
            maxGPoint != pointsInMinute.first &&
            maxGPoint != pointsInMinute.last) {
          optimizedPoints.add(maxGPoint);
        }
        if (pointsInMinute.last != pointsInMinute.first) {
          optimizedPoints.add(pointsInMinute.last);
        }
      }
    }

    // Sort by timestamp to maintain chronological order
    optimizedPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return optimizedPoints;
  }

  // Create a flight from the current tracking data
  Flight _createFlight() {
    if (_flightPath.isEmpty) {
      throw Exception('No flight data to save');
    }

    // Optimize G-force data before saving
    final optimizedPath = _optimizeGForceData(_flightPath);

    final startTime = optimizedPath.first.timestamp;
    final endTime = optimizedPath.last.timestamp;

    // Calculate max altitude and speed
    double maxAltitude = 0.0;
    double maxSpeed = 0.0;

    // Calculate stats from optimized path
    for (final point in optimizedPath) {
      maxAltitude = math.max(maxAltitude, point.altitude);
      maxSpeed = math.max(maxSpeed, point.speed);
    }

    // Calculate moving time (time spent moving > 1 m/s)
    final movingTime = optimizedPath.fold<Duration>(
      Duration.zero,
      (total, point) =>
          point.speed > 1.0 ? total + Duration(seconds: 1) : total,
    );

    return Flight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: endTime,
      path: optimizedPath,
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
            ? ((_averageSpeed * (_flightPath.length - 2)) + currentSpeed) /
                  (_flightPath.length - 1)
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
    if (_flightPath.isEmpty) {
      // If no flight path data, return time since start if tracking, otherwise zero
      return _isTracking
          ? DateTime.now().difference(_startTime!)
          : Duration.zero;
    }
    final endTime = _isTracking ? DateTime.now() : _flightPath.last.timestamp;
    return endTime.difference(_startTime!);
  }

  // Get the flight duration as a Duration object (alias for movingTime)
  Duration get flightDuration => movingTime;

  // Get the vertical speed in feet per minute (fpm)
  double get verticalSpeed {
    if (_flightPath.length < 2) return 0.0;

    // Use up to last 3 points for smoothing
    int pointsToUse = math.min(3, _flightPath.length);
    if (pointsToUse < 2) return 0.0;

    double totalVerticalSpeed = 0.0;
    int validMeasurements = 0;

    for (
      int i = _flightPath.length - 1;
      i > _flightPath.length - pointsToUse;
      i--
    ) {
      final currentPoint = _flightPath[i];
      final previousPoint = _flightPath[i - 1];

      final altitudeDiff = currentPoint.altitude - previousPoint.altitude;
      final timeDiff =
          currentPoint.timestamp
              .difference(previousPoint.timestamp)
              .inMilliseconds /
          1000.0; // Convert to seconds

      if (timeDiff > 0) {
        // Convert from m/s to feet/minute: 1 m/s = 196.85 ft/min
        final verticalSpeedMps = altitudeDiff / timeDiff;
        final verticalSpeedFpm = verticalSpeedMps * 196.85;
        totalVerticalSpeed += verticalSpeedFpm;
        validMeasurements++;
      }
    }

    return validMeasurements > 0 ? totalVerticalSpeed / validMeasurements : 0.0;
  }

  // Get current G-force
  double get currentGForce {
    // Calculate total acceleration magnitude
    final totalAccel = math.sqrt(
      _currentXAccel * _currentXAccel +
          _currentYAccel * _currentYAccel +
          _currentZAccel * _currentZAccel,
    );
    // Already in G's since we divided by _gravity in _initSensors
    return totalAccel;
  }

  // Get current barometric pressure in hPa
  double get currentPressure => _barometerService?.lastPressure ?? 1013.25;

  // Clean up resources
  // Throttling for notifications
  DateTime? _lastNotifyTime;
  Timer? _notifyTimer;
  static const _notifyThrottleMs = 250; // Max 4 updates per second

  void _throttledNotifyListeners() {
    final now = DateTime.now();
    if (_lastNotifyTime == null ||
        now.difference(_lastNotifyTime!).inMilliseconds > _notifyThrottleMs) {
      _lastNotifyTime = now;
      notifyListeners();
    } else {
      // Schedule a delayed notification if we're throttling
      _notifyTimer?.cancel();
      _notifyTimer = Timer(const Duration(milliseconds: _notifyThrottleMs), () {
        _lastNotifyTime = DateTime.now();
        notifyListeners();
      });
    }
  }

  // Stop sensor subscriptions
  void _stopSensors() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
  }

  @override
  void dispose() {
    _stopSensors();
    _positionSubscription?.cancel();
    _barometerSubscription?.cancel();
    _barometerService?.dispose();
    _notifyTimer?.cancel();
    _isTracking = false;
    _flightPath.clear();
    // Ensure wakelock is disabled when service is disposed
    WakelockPlus.disable();
    super.dispose();
  }
}
