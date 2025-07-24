import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class BarometerService {
  static final BarometerService _instance = BarometerService._internal();
  factory BarometerService() => _instance;
  BarometerService._internal() {
    _logger = Logger(printer: PrettyPrinter());
  }

  late final Logger _logger;

  // Platform channels for native barometer access
  static const MethodChannel _methodChannel = MethodChannel(
    'barometer_service',
  );
  static const EventChannel _eventChannel = EventChannel('pressure_stream');

  StreamSubscription<dynamic>? _sensorSubscription;
  double? _pressureHPa;
  double? _altitudeMeters;

  // Standard pressure at sea level in hPa (QNH)
  static double _seaLevelPressure = 1013.25;

  // Constants for altitude calculation
  static const double _temperatureLapseRate = 0.0065; // K/m
  static const double _temperatureSeaLevel = 288.15; // K (15°C)
  static const double _gasConstant = 8.3144598; // J/(mol·K)
  static const double _molarMass = 0.0289644; // kg/mol
  static const double _gravity = 9.80665; // m/s²

  // Stream controller for barometer updates
  final StreamController<BarometerReading> _updateController =
      StreamController<BarometerReading>.broadcast();

  // Stream that emits whenever there's a barometer update
  Stream<BarometerReading> get onBarometerUpdate => _updateController.stream;

  // Pressure smoothing
  final List<double> _pressureWindow = [];
  static const int _smoothingWindow = 3; // Number of samples for moving average

  bool _isListening = false;
  bool _isBarometerAvailable = false;

  // Get current pressure in hPa
  double? get pressureHPa => _pressureHPa;

  // Alias for pressureHPa for backward compatibility
  double? get lastPressure => _pressureHPa;

  // Get current altitude in meters (calculated from pressure)
  double? get altitudeMeters => _altitudeMeters;

  // Get sea level pressure (QNH)
  double get seaLevelPressure => _seaLevelPressure;

  // Check if barometer is available
  bool get isBarometerAvailable => _isBarometerAvailable;

  // Check if currently listening
  bool get isListening => _isListening;

  /// Initialize the barometer service
  Future<void> initialize() async {
    try {
      _isBarometerAvailable = await _checkBarometerAvailability();
      if (_isBarometerAvailable) {
        _logger.i('Barometer sensor is available');
      } else {
        _logger.d('Barometer sensor is not available on this device');
      }
    } catch (e) {
      _logger.w('Failed to initialize barometer service: $e');
      _isBarometerAvailable = false;
    }
  }

  /// Check if barometer sensor is available
  Future<bool> _checkBarometerAvailability() async {
    // Barometer is not available on web
    if (kIsWeb) {
      _logger.d('Barometer not available on web platform');
      return false;
    }
    
    try {
      return await _methodChannel.invokeMethod('isBarometerAvailable') ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'UNAVAILABLE') {
        _logger.d('Barometer sensor not available: ${e.message}');
      } else {
        _logger.w('Error checking barometer availability: ${e.code} - ${e.message}');
      }
      return false;
    } on MissingPluginException catch (e) {
      _logger.d('Barometer plugin not implemented on this platform: $e');
      return false;
    }
  }

  /// Start listening to barometer sensor updates
  Future<void> startListening() async {
    if (_isListening) return;

    if (!_isBarometerAvailable) {
      await initialize();
    }

    _isListening = true;
    _logger.i('Starting barometer listening');

    try {
      if (_isBarometerAvailable) {
        // Start native barometer sensor (not on web)
        if (!kIsWeb) {
          try {
            await _methodChannel.invokeMethod('startPressureUpdates');
          } on PlatformException catch (e) {
            if (e.code == 'UNAVAILABLE') {
              _logger.d('Barometer not available when starting updates: ${e.message}');
              _isBarometerAvailable = false;
              _startSimulatedPressureUpdates();
              return;
            }
            rethrow;
          }
        }

        // Listen for pressure updates via event channel
        try {
          _sensorSubscription = _eventChannel.receiveBroadcastStream().listen(
            _handlePressureUpdate,
            onError: _handleSensorError,
            cancelOnError: false, // Continue listening even if an error occurs
          );
        } on PlatformException catch (e) {
          if (e.code == 'UNAVAILABLE') {
            _logger.d('Barometer sensor not available on this device: ${e.message}');
            _isBarometerAvailable = false;
            _isListening = false;
            // Fallback to simulated data
            _startSimulatedPressureUpdates();
            return;
          }
          // For other platform exceptions, log and fallback
          _logger.w('Platform exception in barometer: ${e.code} - ${e.message}');
          _isBarometerAvailable = false;
          _isListening = false;
          _startSimulatedPressureUpdates();
          return;
        }
      } else {
        // Fallback to simulated pressure data for testing
        _logger.d('Barometer not available, using simulated data');
        _startSimulatedPressureUpdates();
      }
    } on MissingPluginException catch (e) {
      _logger.d('Barometer plugin not implemented: $e');
      _isBarometerAvailable = false;
      _isListening = false;
      // Fallback to simulation if native plugin is missing
      _startSimulatedPressureUpdates();
    } catch (e) {
      _logger.w('Error starting barometer: $e');
      _isListening = false;
      // Fallback to simulation if native fails
      _startSimulatedPressureUpdates();
    }
  }

  /// Handle pressure updates from native sensor
  void _handlePressureUpdate(dynamic data) {
    try {
      double pressure;

      if (data is Map) {
        // Handle structured data from native
        pressure = (data['pressure'] as num?)?.toDouble() ?? 1013.25;
      } else {
        // Handle simple numeric data
        pressure = (data as num).toDouble();
      }

      _updatePressure(pressure);
    } catch (e) {
      _logger.e('Error processing pressure update: $e');
    }
  }

  /// Update pressure with smoothing and calculate altitude
  void _updatePressure(double pressure) {
    // Apply moving average for smoothing
    _pressureWindow.add(pressure);
    if (_pressureWindow.length > _smoothingWindow) {
      _pressureWindow.removeAt(0);
    }

    // Safety check to prevent "Bad state: No element" error
    if (_pressureWindow.isEmpty) {
      _logger.w('Pressure window is empty, skipping update');
      return;
    }

    final smoothedPressure =
        _pressureWindow.reduce((a, b) => a + b) / _pressureWindow.length;

    _pressureHPa = smoothedPressure;
    _altitudeMeters = _calculateAltitudeFromPressure(smoothedPressure);

    // Emit update
    _updateController.add(
      BarometerReading(
        pressure: smoothedPressure,
        altitude: _altitudeMeters!,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Calculate altitude from pressure using the barometric formula
  double _calculateAltitudeFromPressure(double pressureHPa) {
    // Using the barometric formula for the troposphere (valid up to 11 km)
    // h = (T0/L) * ((P0/P)^(R*L/(g*M)) - 1)

    final double exponent =
        (_gasConstant * _temperatureLapseRate) / (_gravity * _molarMass);
    final double pressureRatio = _seaLevelPressure / pressureHPa;
    final double altitude =
        (_temperatureSeaLevel / _temperatureLapseRate) *
        (math.pow(pressureRatio, exponent) - 1);

    return altitude;
  }

  /// Handle sensor errors
  void _handleSensorError(dynamic error) {
    // Check if it's a PlatformException for unavailable sensor
    if (error is PlatformException && error.code == 'UNAVAILABLE') {
      _logger.d('Barometer sensor not available on this device: ${error.message}');
      _isBarometerAvailable = false;
      _isListening = false;
      // Cancel the current subscription
      _sensorSubscription?.cancel();
      // Fallback to simulated data
      _startSimulatedPressureUpdates();
      return;
    }
    
    // For other errors, log as warning instead of error if it's a known issue
    if (error is PlatformException) {
      _logger.w('Barometer platform error: ${error.code} - ${error.message}');
      _isBarometerAvailable = false;
      _isListening = false;
      // Cancel the current subscription
      _sensorSubscription?.cancel();
      // Fallback to simulated data
      _startSimulatedPressureUpdates();
      return;
    }
    
    _logger.e('Barometer sensor error: $error');
    _updateController.addError(error);
  }

  /// Start simulated pressure updates for testing/fallback
  void _startSimulatedPressureUpdates() {
    // Cancel any existing subscription to prevent duplicates
    _sensorSubscription?.cancel();
    
    _logger.d('Using simulated barometer data (device has no barometer sensor)');

    double basePressure = 1013.25;
    int counter = 0;

    _sensorSubscription =
        Stream.periodic(const Duration(milliseconds: 2000), (count) {
          // Simulate realistic pressure variations (±2 hPa over time)
          counter++;
          final variation = math.sin(counter * 0.1) * 2.0;
          final simulatedPressure = basePressure + variation;

          return simulatedPressure;
        }).listen((pressure) {
          _updatePressure(pressure);
        });
  }

  /// Set the sea level pressure (QNH) for accurate altitude calculation
  void setSeaLevelPressure(double pressureHPa) {
    if (pressureHPa > 900 && pressureHPa < 1100) {
      _seaLevelPressure = pressureHPa;
      _logger.i(
        'Sea level pressure set to: ${pressureHPa.toStringAsFixed(2)} hPa',
      );

      // Recalculate altitude with new sea level pressure
      if (_pressureHPa != null) {
        _altitudeMeters = _calculateAltitudeFromPressure(_pressureHPa!);
        _updateController.add(
          BarometerReading(
            pressure: _pressureHPa!,
            altitude: _altitudeMeters!,
            timestamp: DateTime.now(),
          ),
        );
      }
    } else {
      _logger.w(
        'Invalid sea level pressure: $pressureHPa hPa. Must be between 900-1100 hPa',
      );
    }
  }

  /// Get current barometric altitude
  double? getBarometricAltitude() => _altitudeMeters;

  /// Get current pressure
  double? getCurrentPressure() => _pressureHPa;

  /// Stop listening to sensor updates
  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    _logger.i('Stopping barometer listening');

    try {
      await _sensorSubscription?.cancel();
      _sensorSubscription = null;

      // Clear the pressure window to prevent stale data
      _pressureWindow.clear();

      if (_isBarometerAvailable && !kIsWeb) {
        await _methodChannel.invokeMethod('stopPressureUpdates');
      }
    } catch (e) {
      _logger.e('Error stopping barometer: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    stopListening();
    _updateController.close();
  }
}

/// Barometer reading data class
class BarometerReading {
  final double pressure; // hPa
  final double altitude; // meters
  final DateTime timestamp;

  const BarometerReading({
    required this.pressure,
    required this.altitude,
    required this.timestamp,
  });

  @override
  String toString() =>
      'BarometerReading(pressure: ${pressure.toStringAsFixed(2)} hPa, '
      'altitude: ${altitude.toStringAsFixed(1)} m, '
      'time: ${timestamp.toIso8601String()})';
}
