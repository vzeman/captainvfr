import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/flight_constants.dart';

/// Manages all sensor subscriptions for flight tracking
class SensorManager {
  // Sensor data streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  
  // Current sensor values
  double _currentXAccel = 0.0;
  double _currentYAccel = 0.0;
  double _currentZAccel = 0.0;
  double _currentXGyro = 0.0;
  double _currentYGyro = 0.0;
  double _currentZGyro = 0.0;
  double? _currentHeading;
  
  // Callbacks
  final Function(double? heading) onHeadingChanged;
  final Function() onSensorDataUpdated;
  
  // Throttling
  DateTime? _lastCompassUpdate;
  
  SensorManager({
    required this.onHeadingChanged,
    required this.onSensorDataUpdated,
  });
  
  // Getters
  double get currentXAccel => _currentXAccel;
  double get currentYAccel => _currentYAccel;
  double get currentZAccel => _currentZAccel;
  double get currentXGyro => _currentXGyro;
  double get currentYGyro => _currentYGyro;
  double get currentZGyro => _currentZGyro;
  double? get currentHeading => _currentHeading;
  
  /// Get current G-force
  double get currentGForce {
    // Calculate total acceleration magnitude
    final totalAccel = (_currentXAccel * _currentXAccel +
        _currentYAccel * _currentYAccel +
        _currentZAccel * _currentZAccel);
    // Already in G's since we divided by gravity in accelerometer listener
    return totalAccel;
  }
  
  /// Start all sensor subscriptions
  void startSensors() {
    // Check if platform supports sensors
    final bool supportsSensors = !kIsWeb && 
        (Platform.isIOS || Platform.isAndroid);
    
    // Accelerometer with reduced sampling rate
    if (supportsSensors) {
      try {
        _accelerometerSubscription = accelerometerEventStream(
          samplingPeriod: FlightConstants.sensorSamplingPeriod,
        ).listen(
          (AccelerometerEvent event) {
            // Convert from m/s² to g's
            _currentXAccel = event.x / FlightConstants.gravity;
            _currentYAccel = event.y / FlightConstants.gravity;
            _currentZAccel = event.z / FlightConstants.gravity;
            // Don't call callback here - too frequent
          },
          onError: (error) {
            debugPrint('Accelerometer error: $error');
          },
        );
      } catch (e) {
        debugPrint('Failed to initialize accelerometer: $e');
      }
    } else {
      debugPrint('Accelerometer not supported on this platform');
    }
    
    // Gyroscope with reduced sampling rate
    if (supportsSensors) {
      try {
        _gyroscopeSubscription = gyroscopeEventStream(
          samplingPeriod: FlightConstants.sensorSamplingPeriod,
        ).listen(
          (GyroscopeEvent event) {
            _currentXGyro = event.x;
            _currentYGyro = event.y;
            _currentZGyro = event.z;
            // Don't call callback here - too frequent
          },
          onError: (error) {
            debugPrint('Gyroscope error: $error');
          },
        );
      } catch (e) {
        debugPrint('Failed to initialize gyroscope: $e');
      }
    } else {
      debugPrint('Gyroscope not supported on this platform');
    }
    
    // Compass - throttle updates
    // Note: Compass may not be available on all platforms (e.g., macOS)
    try {
      _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
        if (event.heading != null) {
          _currentHeading = event.heading;
          // Throttle compass updates to max 2 per second
          final now = DateTime.now();
          if (_lastCompassUpdate == null ||
              now.difference(_lastCompassUpdate!).inMilliseconds > 
              FlightConstants.compassThrottleInterval.inMilliseconds) {
            _lastCompassUpdate = now;
            onHeadingChanged(_currentHeading);
            onSensorDataUpdated();
          }
        }
      }, onError: (error) {
        debugPrint('Compass error: $error');
      });
    } catch (e) {
      debugPrint('Failed to initialize compass: $e');
    }
  }
  
  /// Stop all sensor subscriptions
  void stopSensors() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
  }
  
  /// Dispose of resources
  void dispose() {
    stopSensors();
  }
}