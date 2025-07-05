import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Platform-specific services for Android 12+ compatibility
class PlatformServices {
  static const _networkChannel = MethodChannel('captainvfr/network');
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
}