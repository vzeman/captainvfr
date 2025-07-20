import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WatchConnectivityService {
  static const _channel = MethodChannel('com.captainvfr.watch_connectivity');
  static final WatchConnectivityService _instance = WatchConnectivityService._internal();
  
  factory WatchConnectivityService() => _instance;
  
  WatchConnectivityService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }
  
  // Stream controllers for watch events
  final _trackingStateController = StreamController<bool>.broadcast();
  final _flightDataController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<bool> get trackingStateStream => _trackingStateController.stream;
  Stream<Map<String, dynamic>> get flightDataStream => _flightDataController.stream;
  
  // Send tracking state to watch
  Future<void> sendTrackingState(bool isTracking) async {
    try {
      await _channel.invokeMethod('sendTrackingState', {'isTracking': isTracking});
    } catch (e) {
      debugPrint('Error sending tracking state to watch: $e');
    }
  }
  
  // Send flight data to watch
  Future<void> sendFlightData({
    required double altitude,
    required double groundSpeed,
    required double heading,
    required double track,
    required double verticalSpeed,
    required double pressure,
  }) async {
    try {
      await _channel.invokeMethod('sendFlightData', {
        'altitude': altitude,
        'groundSpeed': groundSpeed,
        'heading': heading,
        'track': track,
        'verticalSpeed': verticalSpeed,
        'pressure': pressure,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error sending flight data to watch: $e');
    }
  }
  
  // Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'startTracking':
        _trackingStateController.add(true);
        break;
      case 'stopTracking':
        _trackingStateController.add(false);
        break;
      case 'flightDataUpdate':
        if (call.arguments is Map) {
          _flightDataController.add(Map<String, dynamic>.from(call.arguments));
        }
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }
  
  void dispose() {
    _trackingStateController.close();
    _flightDataController.close();
  }
}