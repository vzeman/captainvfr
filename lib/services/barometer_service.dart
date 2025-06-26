import 'dart:async';
import 'dart:developer';
import 'package:sensors_plus/sensors_plus.dart';

class BarometerService {
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  double? _pressureHPa;
  double? _altitudeMeters;
  
  // Standard pressure at sea level in hPa
  static const double seaLevelPressure = 1013.25;
  
  // Stream controller for barometer updates
  final StreamController<void> _updateController = StreamController<void>.broadcast();
  
  // Stream that emits whenever there's a barometer update
  Stream<void> get onBarometerUpdate => _updateController.stream;
  
  BarometerService();
  
  // Get current pressure in hPa
  double? get pressureHPa => _pressureHPa;
  
  // Get current altitude in meters (calculated from pressure)
  double? get altitudeMeters => _altitudeMeters;
  
  // Start listening to sensor updates
  // Note: This is a placeholder implementation since not all devices have a barometer
  // On devices without a barometer, we'll simulate pressure changes based on device movement
  Future<void> startListening() async {
    try {
      _sensorSubscription = userAccelerometerEventStream().listen((event) {
        // Simulate pressure changes based on device movement
        // In a real app, we would use the barometer sensor if available
        final simulatedAltitude = (event.x.abs() + event.y.abs() + event.z.abs()) * 10;
        _altitudeMeters = simulatedAltitude;
        _pressureHPa = _calculatePressure(simulatedAltitude);
        _updateController.add(null);
      }, onError: (error) {
        // Handle any errors that occur during the stream
        log('Error in accelerometer stream: $error');
      });
    } catch (e) {
      // Handle any errors that occur when setting up the stream
      log('Failed to start accelerometer: $e');
      rethrow;
    }
  }
  
  // Calculate pressure from altitude using the barometric formula
  // This is the inverse of the altitude calculation
  double _calculatePressure(double altitudeMeters) {
    // Using the barometric formula for the troposphere (valid up to 11 km)
    const double temperatureLapseRate = 0.0065; // K/m
    const double temperatureAtSeaLevel = 288.15; // K (15°C)
    const double molarMass = 0.0289644; // kg/mol (molar mass of Earth's air)
    const double gravity = 9.80665; // m/s²
    const double gasConstant = 8.31447; // J/(mol·K)
    
    final double exponent = (gravity * molarMass) / (gasConstant * temperatureLapseRate);
    final double pressure = seaLevelPressure * 
        (1 - (temperatureLapseRate * altitudeMeters) / temperatureAtSeaLevel).pow(exponent);
    
    return pressure;
  }
  
  // Stop listening to sensor updates
  void stopListening() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
  }
  
  // Clean up resources
  void dispose() {
    stopListening();
  }
}

extension on num {
  num pow(num exponent) {
    return _pow(this, exponent);
  }
  
  num _pow(num base, num exponent) {
    if (exponent == 0) return 1;
    if (exponent < 0) return 1 / _pow(base, -exponent);
    if (exponent % 1 == 0) {
      num result = 1;
      for (var i = 0; i < exponent; i++) {
        result *= base;
      }
      return result;
    }
    return _pow(base, exponent.toInt()) * _pow(base, exponent - exponent.toInt());
  }
}
