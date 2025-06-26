import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

// Platform channel for native sensor access
const MethodChannel _channel = MethodChannel('altitude_service');

class AltitudeService {
  static final AltitudeService _instance = AltitudeService._internal();
  factory AltitudeService() => _instance;
  AltitudeService._internal() {
    _logger = Logger(printer: PrettyPrinter());
  }

  // Logger
  late final Logger _logger;

  // Stream controllers
  final StreamController<double> _altitudeController = StreamController<double>.broadcast();
  final StreamController<List<double>> _altitudeHistoryController = 
      StreamController<List<double>>.broadcast();

  // Streams
  Stream<double> get altitudeStream => _altitudeController.stream;
  Stream<List<double>> get altitudeHistoryStream => _altitudeHistoryController.stream;

  // State
  List<double> _altitudeHistory = [];
  static const int _maxHistoryLength = 1000; // Store up to 1000 altitude points
  bool _isTracking = false;
  StreamSubscription<dynamic>? _sensorSubscription;
  
  // Constants for altitude calculation
  static double _pressureSeaLevel = 1013.25; // hPa - standard pressure at sea level
  static const double _temperatureLapseRate = 0.0065; // K/m
  static const double _temperatureSeaLevel = 288.15; // K (15°C)
  static const double _gasConstant = 8.3144598; // J/(mol·K)
  static const double _molarMass = 0.0289644; // kg/mol
  static const double _gravity = 9.80665; // m/s²
  
  // Platform-specific sensor availability
  bool _isBarometerAvailable = false;
  bool _isInitialized = false;
  
  // Current pressure in hPa
  double? _currentPressure;
  
  // Altitude smoothing
  final List<double> _altitudeWindow = [];
  static const int _smoothingWindow = 5; // Number of samples for moving average

  /// Initialize the altitude service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check if barometer is available on the device
      if (Platform.isIOS || Platform.isAndroid) {
        _isBarometerAvailable = await _checkBarometerAvailability();
        _logger.i('Barometer available: $_isBarometerAvailable');
      }
      _isInitialized = true;
    } catch (e) {
      _logger.e('Failed to initialize AltitudeService: $e');
      rethrow;
    }
  }
  
  /// Check if barometer is available on the device
  Future<bool> _checkBarometerAvailability() async {
    try {
      if (Platform.isIOS) {
        // On iOS, we can use the altimeter API
        return await _channel.invokeMethod('isAltimeterAvailable');
      } else if (Platform.isAndroid) {
        // On Android, we'll use the barometer sensor
        return await _channel.invokeMethod('isBarometerAvailable');
      }
      return false;
    } on PlatformException catch (e) {
      _logger.e('Error checking barometer availability: $e');
      return false;
    }
  }

  /// Start tracking altitude using barometric pressure
  Future<void> startTracking() async {
    if (_isTracking) return;
    
    if (!_isInitialized) {
      await initialize();
    }
    
    _isTracking = true;
    _logger.i('Starting altitude tracking');
    
    try {
      if (_isBarometerAvailable) {
        if (Platform.isIOS) {
          // Use iOS altimeter API
          final stream = await _channel.invokeMethod<Stream>('startAltitudeUpdates');
          if (stream != null) {
            _sensorSubscription = stream.listen(
              _handleAltitudeUpdate,
              onError: _handleSensorError,
            );
          }
        } else if (Platform.isAndroid) {
          // Use Android barometer sensor
          final stream = await _channel.invokeMethod<Stream>('startPressureUpdates');
          if (stream != null) {
            _sensorSubscription = stream.listen(
              _handlePressureUpdate,
              onError: _handleSensorError,
            );
          }
        }
      } else {
        // Fallback to GPS altitude or other methods
        _logger.w('Barometer not available, falling back to simulated data');
        _startSimulatedAltitudeUpdates();
      }
    } catch (e) {
      _logger.e('Error starting altitude tracking: $e');
      _isTracking = false;
      rethrow;
    }
  }
  
  /// Handle altitude updates from the platform
  void _handleAltitudeUpdate(dynamic data) {
    try {
      final altitude = (data as num).toDouble();
      _updateAltitude(altitude);
    } catch (e) {
      _logger.e('Error processing altitude update: $e');
    }
  }
  
  /// Handle pressure updates from the platform
  void _handlePressureUpdate(dynamic data) {
    try {
      final pressure = (data as num).toDouble(); // Pressure in hPa
      _currentPressure = pressure;
      final altitude = _calculateAltitude(pressure);
      _updateAltitude(altitude);
    } catch (e) {
      _logger.e('Error processing pressure update: $e');
    }
  }
  
  /// Update altitude with smoothing
  void _updateAltitude(double altitude) {
    // Apply moving average for smoothing
    _altitudeWindow.add(altitude);
    if (_altitudeWindow.length > _smoothingWindow) {
      _altitudeWindow.removeAt(0);
    }
    
    final smoothedAltitude = _altitudeWindow.reduce((a, b) => a + b) / _altitudeWindow.length;
    
    _altitudeController.add(smoothedAltitude);
    
    // Update history
    _altitudeHistory.add(smoothedAltitude);
    if (_altitudeHistory.length > _maxHistoryLength) {
      _altitudeHistory.removeAt(0);
    }
    _altitudeHistoryController.add(List.from(_altitudeHistory));
  }
  
  /// Handle sensor errors
  void _handleSensorError(dynamic error) {
    _logger.e('Sensor error: $error');
    _altitudeController.addError(error);
    // Consider implementing a retry mechanism or fallback
  }
  
  /// Start simulated altitude updates (for testing/fallback)
  void _startSimulatedAltitudeUpdates() {
    double simulatedAltitude = 0.0;
    bool ascending = true;
    
    _sensorSubscription = Stream.periodic(const Duration(milliseconds: 1000), (count) {
      // Simulate altitude changes
      if (ascending) {
        simulatedAltitude += 0.5;
        if (simulatedAltitude >= 100.0) ascending = false;
      } else {
        simulatedAltitude -= 0.5;
        if (simulatedAltitude <= 0.0) ascending = true;
      }
      return simulatedAltitude;
    }).listen((altitude) {
      _updateAltitude(altitude);
    });
  }

  /// Stop tracking altitude
  Future<void> stopTracking() async {
    if (!_isTracking) return;
    
    _logger.i('Stopping altitude tracking');
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _isTracking = false;
    
    try {
      if (Platform.isIOS || Platform.isAndroid) {
        await _channel.invokeMethod('stopAltitudeUpdates');
      }
    } catch (e) {
      _logger.e('Error stopping altitude updates: $e');
    }
  }

  /// Calculate altitude from pressure using the barometric formula
  double _calculateAltitude(double pressure) {
    if (pressure <= 0) return 0.0;
    
    // Barometric formula: h = (T0 / L) * (1 - (P / P0)^(R * L / (g * M)))
    // Where:
    // h = height above sea level (m)
    // T0 = standard temperature at sea level (K)
    // L = temperature lapse rate (K/m)
    // P = measured pressure (hPa)
    // P0 = standard pressure at sea level (hPa)
    // R = universal gas constant (J/(mol·K))
    // g = gravitational acceleration (m/s²)
    // M = molar mass of Earth's air (kg/mol)
    
    final exponent = (_gasConstant * _temperatureLapseRate) / (_gravity * _molarMass);
    final altitude = (_temperatureSeaLevel / _temperatureLapseRate) * 
                    (1.0 - (pressure / _pressureSeaLevel).pow(exponent));
    
    return altitude.isFinite ? altitude : 0.0;
  }

  /// Get the current altitude history
  List<double> getAltitudeHistory() => List.from(_altitudeHistory);
  
  /// Get the current pressure in hPa (if available)
  double? get currentPressure => _currentPressure;
  
  /// Check if barometer is available
  bool get isBarometerAvailable => _isBarometerAvailable;
  
  /// Check if the service is currently tracking
  bool get isTracking => _isTracking;

  /// Clear the altitude history
  void clearHistory() {
    _altitudeHistory.clear();
    _altitudeWindow.clear();
    _altitudeHistoryController.add([]);
  }
  
  /// Set the sea level pressure for more accurate altitude calculation
  void setSeaLevelPressure(double pressureHpa) {
    if (pressureHpa > 0) {
      _pressureSeaLevel = pressureHpa;
      // Recalculate current altitude with new sea level pressure
      if (_currentPressure != null) {
        final newAltitude = _calculateAltitude(_currentPressure!);
        _updateAltitude(newAltitude);
      }
    }
  }
  
  /// Dispose of resources
  void dispose() {
    stopTracking();
    _altitudeController.close();
    _altitudeHistoryController.close();
  }
}

extension on double {
  double pow(double exponent) => 
      (this * 1e6).round() / 1e6 * (exponent * 1e6).round() / 1e6;
}
