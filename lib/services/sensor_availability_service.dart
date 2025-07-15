import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import '../widgets/sensor_notification_widget.dart';

/// Service to check sensor availability and manage notifications
class SensorAvailabilityService extends ChangeNotifier {
  static final SensorAvailabilityService _instance = SensorAvailabilityService._internal();
  factory SensorAvailabilityService() => _instance;
  SensorAvailabilityService._internal();

  final List<SensorNotificationData> _notifications = [];
  bool _hasCheckedSensors = false;
  
  List<SensorNotificationData> get notifications => List.unmodifiable(_notifications);
  bool get hasNotifications => _notifications.isNotEmpty;

  /// Check all sensors and generate notifications for unavailable ones
  Future<void> checkSensorAvailability() async {
    if (_hasCheckedSensors) return;
    _hasCheckedSensors = true;
    
    _notifications.clear();

    // Check platform
    if (kIsWeb) {
      _addWebPlatformNotifications();
    } else {
      await _checkMobileSensors();
    }

    if (_notifications.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Add notifications for web platform limitations
  void _addWebPlatformNotifications() {
    _notifications.addAll([
      SensorNotificationData(
        id: 'web_accelerometer',
        sensorName: 'Accelerometer Not Available',
        message: 'Vibration measurement is not supported in web browsers',
        icon: Icons.vibration,
      ),
      SensorNotificationData(
        id: 'web_barometer',
        sensorName: 'Barometer Not Available', 
        message: 'Altitude and pressure sensors are not available in web browsers',
        icon: Icons.speed,
      ),
      const SensorNotificationData(
        id: 'web_offline_maps',
        sensorName: 'Offline Maps Not Available',
        message: 'Offline map storage is not supported in web browsers',
        icon: Icons.map,
      ),
    ]);
  }

  /// Check mobile platform sensors
  Future<void> _checkMobileSensors() async {
    // Check GPS/Location
    await _checkLocationSensor();
    
    // Check accelerometer
    await _checkAccelerometer();
    
    // Check barometer (platform specific)
    if (Platform.isIOS || Platform.isAndroid) {
      await _checkBarometer();
    }
  }

  /// Check if location services are available
  Future<void> _checkLocationSensor() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _notifications.add(
          const SensorNotificationData(
            id: 'location_disabled',
            sensorName: 'Location Services Disabled',
            message: 'Enable location services for navigation and flight tracking',
            icon: Icons.location_off,
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        _notifications.add(
          SensorNotificationData(
            id: 'location_permission',
            sensorName: 'Location Permission Required',
            message: permission == LocationPermission.deniedForever
                ? 'Location permission denied. Enable in device settings.'
                : 'Location permission needed for navigation features',
            icon: Icons.location_disabled,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      // Location service check failed
      _notifications.add(
        const SensorNotificationData(
          id: 'location_error',
          sensorName: 'Location Service Error',
          message: 'Unable to access location services',
          icon: Icons.error_outline,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Check if accelerometer is available
  Future<void> _checkAccelerometer() async {
    try {
      // Try to get a single accelerometer reading
      final stream = accelerometerEventStream();
      await stream.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Accelerometer not responding'),
      );
    } catch (e) {
      _notifications.add(
        const SensorNotificationData(
          id: 'accelerometer_unavailable',
          sensorName: 'Accelerometer Not Available',
          message: 'Vibration measurement features will be disabled',
          icon: Icons.vibration,
        ),
      );
    }
  }

  /// Check if barometer is available
  Future<void> _checkBarometer() async {
    try {
      // Check if we have pressure sensor permission on Android
      if (Platform.isAndroid) {
        final status = await perm.Permission.sensors.status;
        if (!status.isGranted) {
          _notifications.add(
            const SensorNotificationData(
              id: 'barometer_permission',
              sensorName: 'Barometer Permission Required',
              message: 'Sensor permission needed for altitude measurements',
              icon: Icons.speed,
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }
      }

      // Try to get a barometer reading
      final stream = barometerEventStream();
      await stream.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException('Barometer not responding'),
      );
    } catch (e) {
      _notifications.add(
        const SensorNotificationData(
          id: 'barometer_unavailable',
          sensorName: 'Barometer Not Available',
          message: 'Pressure altitude features will be limited',
          icon: Icons.speed,
        ),
      );
    }
  }

  /// Dismiss a notification
  void dismissNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Clear all notifications
  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  /// Reset to allow re-checking sensors
  void reset() {
    _hasCheckedSensors = false;
    _notifications.clear();
    notifyListeners();
  }
}