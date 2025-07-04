import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Platform-specific services for Android 12+ compatibility
class PlatformServices {
  static const _networkChannel = MethodChannel('captainvfr/network');
  static const _vibrationChannel = MethodChannel('captainvfr/vibration');
  static final _logger = Logger();

  /// Check network status and get diagnostics
  static Future<Map<String, dynamic>> checkNetworkStatus() async {
    try {
      final result = await _networkChannel.invokeMethod('checkNetworkStatus');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      _logger.e('Error checking network status', error: e);
      return {
        'isConnected': false,
        'hasInternet': false,
        'connectionType': 'Unknown',
        'error': e.toString(),
      };
    }
  }

  /// Get detailed network diagnostics for debugging
  static Future<Map<String, dynamic>> getNetworkDiagnostics() async {
    try {
      final result = await _networkChannel.invokeMethod('getNetworkDiagnostics');
      _logger.d('Network diagnostics: $result');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      _logger.e('Error getting network diagnostics', error: e);
      return {'error': e.toString()};
    }
  }

  /// Check if device has vibrator
  static Future<bool> hasVibrator() async {
    try {
      final result = await _vibrationChannel.invokeMethod('hasVibrator');
      return result as bool;
    } catch (e) {
      _logger.e('Error checking vibrator', error: e);
      return false;
    }
  }

  /// Vibrate for specified duration in milliseconds
  static Future<void> vibrate({int duration = 100}) async {
    try {
      await _vibrationChannel.invokeMethod('vibrate', {'duration': duration});
    } catch (e) {
      _logger.e('Error vibrating', error: e);
    }
  }

  /// Vibrate with pattern
  static Future<void> vibratePattern({
    required List<int> pattern,
    int repeat = -1,
  }) async {
    try {
      await _vibrationChannel.invokeMethod('vibratePattern', {
        'pattern': pattern,
        'repeat': repeat,
      });
    } catch (e) {
      _logger.e('Error vibrating with pattern', error: e);
    }
  }

  /// Cancel vibration
  static Future<void> cancelVibration() async {
    try {
      await _vibrationChannel.invokeMethod('cancel');
    } catch (e) {
      _logger.e('Error cancelling vibration', error: e);
    }
  }

  /// Log network state on app startup for debugging
  static Future<void> logNetworkState() async {
    _logger.i('=== CaptainVFR Network State Check ===');
    
    final status = await checkNetworkStatus();
    _logger.i('Network Status: $status');
    
    final diagnostics = await getNetworkDiagnostics();
    _logger.i('Network Diagnostics: $diagnostics');
    
    if (!status['isConnected'] || !status['hasInternet']) {
      _logger.w('Network connectivity issues detected!');
      _logger.w('Please check your internet connection and app permissions');
    }
    
    _logger.i('=====================================');
  }

  /// Test vibration functionality
  static Future<void> testVibration() async {
    final hasVib = await hasVibrator();
    if (hasVib) {
      _logger.d('Testing vibration...');
      await vibrate(duration: 200);
    } else {
      _logger.w('Device does not have vibrator');
    }
  }
}