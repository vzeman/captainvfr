import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:logger/logger.dart';

/// Service for measuring vibrations during flight using accelerometer
class VibrationMeasurementService {
  static final _logger = Logger(
    level: Level.warning, // Only log warnings and errors in production
  );
  static final VibrationMeasurementService _instance =
      VibrationMeasurementService._internal();

  factory VibrationMeasurementService() => _instance;
  VibrationMeasurementService._internal();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final _vibrationController = StreamController<VibrationData>.broadcast();

  // Calibration values
  double _baselineX = 0.0;
  double _baselineY = 0.0;
  double _baselineZ = 9.81; // Gravity
  bool _isCalibrated = false;

  // Vibration detection parameters
  static const int _sampleWindowMs = 100;
  static const int _maxSamples = 10;

  final List<AccelerometerEvent> _recentSamples = [];

  Stream<VibrationData> get vibrationStream => _vibrationController.stream;

  /// Initialize the vibration measurement service
  Future<void> initialize() async {
    try {
      _logger.d('Initializing VibrationMeasurementService');

      // Skip accelerometer on web platform
      if (kIsWeb) {
        _logger.i('Accelerometer not supported on web platform');
        return;
      }

      // Check if accelerometer is available
      final isAvailable = await _checkAccelerometerAvailable();
      if (!isAvailable) {
        _logger.i('Accelerometer not available on this device');
        return;
      }

      // Start listening to accelerometer events
      _startAccelerometerListening();

      _logger.d('VibrationMeasurementService initialized');
    } catch (e) {
      _logger.d('Failed to initialize VibrationMeasurementService', error: e);
    }
  }

  /// Check if accelerometer is available
  Future<bool> _checkAccelerometerAvailable() async {
    try {
      // Try to get a single reading
      final events = accelerometerEventStream();
      await events.first.timeout(const Duration(seconds: 2));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Start listening to accelerometer events
  void _startAccelerometerListening() {
    _accelerometerSubscription?.cancel();

    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 20), // 50Hz sampling
        ).listen(
          _processAccelerometerEvent,
          onError: (error) {
            _logger.d('Accelerometer error', error: error);
          },
        );
  }

  /// Process accelerometer events to detect vibrations
  void _processAccelerometerEvent(AccelerometerEvent event) {
    final now = DateTime.now();

    // Add to recent samples
    _recentSamples.add(event);

    // Remove old samples
    final cutoffTime = now.subtract(Duration(milliseconds: _sampleWindowMs));
    _recentSamples.removeWhere((sample) {
      // Approximate timestamp based on position in list
      final sampleIndex = _recentSamples.indexOf(sample);
      final sampleTime = now.subtract(Duration(milliseconds: sampleIndex * 20));
      return sampleTime.isBefore(cutoffTime);
    });

    // Limit sample count
    while (_recentSamples.length > _maxSamples) {
      _recentSamples.removeAt(0);
    }

    // Calculate vibration metrics
    if (_recentSamples.length >= 3) {
      final vibrationData = _calculateVibration(_recentSamples);
      _vibrationController.add(vibrationData);
    }
  }

  /// Calculate vibration metrics from accelerometer samples
  VibrationData _calculateVibration(List<AccelerometerEvent> samples) {
    if (!_isCalibrated) {
      _baselineX =
          samples.map((s) => s.x).reduce((a, b) => a + b) / samples.length;
      _baselineY =
          samples.map((s) => s.y).reduce((a, b) => a + b) / samples.length;
      _baselineZ =
          samples.map((s) => s.z).reduce((a, b) => a + b) / samples.length;
    }

    // Calculate RMS (Root Mean Square) of acceleration changes
    double sumSquaredX = 0;
    double sumSquaredY = 0;
    double sumSquaredZ = 0;
    double maxMagnitude = 0;

    for (final sample in samples) {
      final dx = sample.x - _baselineX;
      final dy = sample.y - _baselineY;
      final dz = sample.z - _baselineZ;

      sumSquaredX += dx * dx;
      sumSquaredY += dy * dy;
      sumSquaredZ += dz * dz;

      final magnitude = sqrt(dx * dx + dy * dy + dz * dz);
      if (magnitude > maxMagnitude) {
        maxMagnitude = magnitude;
      }
    }

    final rmsX = sqrt(sumSquaredX / samples.length);
    final rmsY = sqrt(sumSquaredY / samples.length);
    final rmsZ = sqrt(sumSquaredZ / samples.length);
    final totalRms = sqrt(rmsX * rmsX + rmsY * rmsY + rmsZ * rmsZ);

    // Calculate frequency estimate (simplified)
    int zeroCrossings = 0;
    for (int i = 1; i < samples.length; i++) {
      final prev = samples[i - 1].z - _baselineZ;
      final curr = samples[i].z - _baselineZ;
      if (prev * curr < 0) {
        zeroCrossings++;
      }
    }

    final frequency = (zeroCrossings / 2.0) / (_sampleWindowMs / 1000.0);

    // Determine vibration level
    final level = _getVibrationLevel(totalRms);

    return VibrationData(
      timestamp: DateTime.now(),
      rmsAcceleration: totalRms,
      peakAcceleration: maxMagnitude,
      frequency: frequency,
      level: level,
      axisData: AxisData(x: rmsX, y: rmsY, z: rmsZ),
    );
  }

  /// Determine vibration level from RMS acceleration
  VibrationLevel _getVibrationLevel(double rms) {
    if (rms < 0.1) return VibrationLevel.none;
    if (rms < 0.3) return VibrationLevel.light;
    if (rms < 0.6) return VibrationLevel.moderate;
    if (rms < 1.0) return VibrationLevel.strong;
    return VibrationLevel.severe;
  }

  /// Calibrate the baseline (should be called when aircraft is stationary)
  void calibrate() {
    if (_recentSamples.length >= _maxSamples) {
      _baselineX =
          _recentSamples.map((s) => s.x).reduce((a, b) => a + b) /
          _recentSamples.length;
      _baselineY =
          _recentSamples.map((s) => s.y).reduce((a, b) => a + b) /
          _recentSamples.length;
      _baselineZ =
          _recentSamples.map((s) => s.z).reduce((a, b) => a + b) /
          _recentSamples.length;
      _isCalibrated = true;
      _logger.d(
        'Vibration measurement calibrated: X=$_baselineX, Y=$_baselineY, Z=$_baselineZ',
      );
    }
  }

  /// Stop vibration measurement
  void stop() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  /// Dispose of resources
  void dispose() {
    stop();
    _vibrationController.close();
  }
}

/// Data class for vibration measurements
class VibrationData {
  final DateTime timestamp;
  final double rmsAcceleration; // Root Mean Square acceleration (m/s²)
  final double peakAcceleration; // Peak acceleration (m/s²)
  final double frequency; // Estimated frequency (Hz)
  final VibrationLevel level;
  final AxisData axisData;

  VibrationData({
    required this.timestamp,
    required this.rmsAcceleration,
    required this.peakAcceleration,
    required this.frequency,
    required this.level,
    required this.axisData,
  });

  bool get isSignificant =>
      level != VibrationLevel.none && level != VibrationLevel.light;
}

/// Axis-specific vibration data
class AxisData {
  final double x; // Lateral vibration
  final double y; // Longitudinal vibration
  final double z; // Vertical vibration

  AxisData({required this.x, required this.y, required this.z});
}

/// Vibration severity levels
enum VibrationLevel { none, light, moderate, strong, severe }

extension VibrationLevelExtension on VibrationLevel {
  String get displayName {
    switch (this) {
      case VibrationLevel.none:
        return 'None';
      case VibrationLevel.light:
        return 'Light';
      case VibrationLevel.moderate:
        return 'Moderate';
      case VibrationLevel.strong:
        return 'Strong';
      case VibrationLevel.severe:
        return 'Severe';
    }
  }

  double get maxRms {
    switch (this) {
      case VibrationLevel.none:
        return 0.1;
      case VibrationLevel.light:
        return 0.3;
      case VibrationLevel.moderate:
        return 0.6;
      case VibrationLevel.strong:
        return 1.0;
      case VibrationLevel.severe:
        return double.infinity;
    }
  }
}
