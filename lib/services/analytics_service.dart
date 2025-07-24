import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final Logger _logger = Logger();
  FirebaseAnalytics? _analytics;
  bool _isInitialized = false;
  bool _trackingEnabled = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Skip Firebase initialization on unsupported platforms (macOS, Windows, Linux)
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        _logger.i('Analytics disabled on ${Platform.operatingSystem} - Firebase not configured');
        _isInitialized = true;
        _trackingEnabled = false;
        return;
      }

      // Initialize Firebase only if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      
      _analytics = FirebaseAnalytics.instance;
      _isInitialized = true;
      
      // Check tracking permission on iOS
      if (Platform.isIOS) {
        await _checkTrackingPermission();
      } else {
        // On Android, enable tracking by default
        _trackingEnabled = true;
        await _analytics?.setAnalyticsCollectionEnabled(true);
      }
      
      _logger.i('Analytics service initialized. Tracking enabled: $_trackingEnabled');
    } catch (e) {
      _logger.w('Failed to initialize analytics: $e');
      // Mark as initialized even if failed to prevent repeated attempts
      _isInitialized = true;
      _trackingEnabled = false;
    }
  }

  Future<void> _checkTrackingPermission() async {
    try {
      // Request App Tracking Transparency permission
      final status = await Permission.appTrackingTransparency.request();
      
      _trackingEnabled = status == PermissionStatus.granted;
      await _analytics?.setAnalyticsCollectionEnabled(_trackingEnabled);
      
      _logger.i('Tracking permission status: $status');
    } catch (e) {
      _logger.e('Error checking tracking permission: $e');
      _trackingEnabled = false;
    }
  }

  // Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isInitialized || !_trackingEnabled || _analytics == null) return;

    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      _logger.d('Screen view logged: $screenName');
    } catch (e) {
      _logger.e('Error logging screen view: $e');
    }
  }

  // Log custom event
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isInitialized || !_trackingEnabled || _analytics == null) return;

    try {
      // Convert dynamic values to Object values
      final Map<String, Object>? convertedParams = parameters?.map((key, value) {
        if (value == null) return MapEntry(key, '');
        return MapEntry(key, value as Object);
      });
      
      await _analytics!.logEvent(
        name: name,
        parameters: convertedParams,
      );
      _logger.d('Event logged: $name');
    } catch (e) {
      _logger.e('Error logging event: $e');
    }
  }

  // Specific event methods
  Future<void> logFlightPlanCreated({
    required String planId,
    required int waypointCount,
    required double totalDistance,
  }) async {
    await logEvent(
      name: 'flight_plan_created',
      parameters: {
        'plan_id': planId,
        'waypoint_count': waypointCount,
        'total_distance_nm': totalDistance,
      },
    );
  }

  Future<void> logFlightStarted({
    required String planId,
  }) async {
    await logEvent(
      name: 'flight_started',
      parameters: {
        'plan_id': planId,
      },
    );
  }

  Future<void> logFlightEnded({
    required String planId,
    required Duration flightDuration,
    required double distanceCovered,
  }) async {
    await logEvent(
      name: 'flight_ended',
      parameters: {
        'plan_id': planId,
        'duration_minutes': flightDuration.inMinutes,
        'distance_covered_nm': distanceCovered,
      },
    );
  }

  Future<void> logWeatherDataLoaded({
    required String dataType,
    required int stationCount,
  }) async {
    await logEvent(
      name: 'weather_data_loaded',
      parameters: {
        'data_type': dataType,
        'station_count': stationCount,
      },
    );
  }

  Future<void> logMapInteraction({
    required String action,
    double? zoom,
  }) async {
    await logEvent(
      name: 'map_interaction',
      parameters: {
        'action': action,
        if (zoom != null) 'zoom_level': zoom,
      },
    );
  }

  Future<void> logAircraftAdded({
    required String aircraftType,
  }) async {
    await logEvent(
      name: 'aircraft_added',
      parameters: {
        'aircraft_type': aircraftType,
      },
    );
  }

  Future<void> logFeatureUsed({
    required String featureName,
    Map<String, dynamic>? additionalParams,
  }) async {
    await logEvent(
      name: 'feature_used',
      parameters: {
        'feature_name': featureName,
        if (additionalParams != null) ...additionalParams,
      },
    );
  }

  // Set user properties
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_isInitialized || !_trackingEnabled || _analytics == null) return;

    try {
      await _analytics!.setUserProperty(name: name, value: value);
      _logger.d('User property set: $name = $value');
    } catch (e) {
      _logger.e('Error setting user property: $e');
    }
  }

  // Check if tracking is enabled
  bool get isTrackingEnabled => _trackingEnabled;

  // Enable/disable tracking (for user preference)
  Future<void> setTrackingEnabled(bool enabled) async {
    if (!_isInitialized || _analytics == null) return;

    try {
      _trackingEnabled = enabled;
      await _analytics!.setAnalyticsCollectionEnabled(enabled);
      _logger.i('Tracking ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.e('Error setting tracking enabled: $e');
    }
  }
}