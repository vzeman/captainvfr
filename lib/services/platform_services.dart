import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// Platform-specific services for Android 12+ compatibility
class PlatformServices {
  static const _networkChannel = MethodChannel('captainvfr/network');
  static final _logger = Logger(
    level: Level.warning, // Only log warnings and errors in production
  );

  /// Check network status and get diagnostics
  static Future<Map<String, dynamic>> checkNetworkStatus() async {
    // On web, assume we're connected (browser handles connectivity)
    if (kIsWeb) {
      return {
        'isConnected': true,
        'hasInternet': true,
        'connectionType': 'Web Browser',
        'platform': 'web',
      };
    }
    
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
    // On web, return basic browser info
    if (kIsWeb) {
      return {
        'platform': 'web',
        'userAgent': 'Web Browser',
        'online': true,
      };
    }
    
    try {
      final result = await _networkChannel.invokeMethod(
        'getNetworkDiagnostics',
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      _logger.e('Error getting network diagnostics', error: e);
      return {'error': e.toString()};
    }
  }

  /// Log network state on app startup for debugging
  static Future<void> logNetworkState() async {
    _logger.i('=== CaptainVFR Network State Check ===');
    
    if (kIsWeb) {
      _logger.i('Platform: Web Browser');
      _logger.i('Network: Managed by browser');
    } else {
      final status = await checkNetworkStatus();
      _logger.i('Network Status: $status');

      final diagnostics = await getNetworkDiagnostics();
      _logger.i('Network Diagnostics: $diagnostics');

      if (!status['isConnected'] || !status['hasInternet']) {
        _logger.w('Network connectivity issues detected!');
        _logger.w('Please check your internet connection and app permissions');
      }
    }

    _logger.i('=====================================');
  }
}
