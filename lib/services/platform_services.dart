import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
    
    // For macOS and iOS, use connectivity_plus plugin
    if (!kIsWeb && (Platform.isMacOS || Platform.isIOS)) {
      try {
        final connectivity = Connectivity();
        final connectivityResult = await connectivity.checkConnectivity();
        final isConnected = !connectivityResult.contains(ConnectivityResult.none);
        
        String connectionType = 'None';
        if (connectivityResult.contains(ConnectivityResult.wifi)) {
          connectionType = 'WiFi';
        } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
          connectionType = 'Mobile';
        } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
          connectionType = 'Ethernet';
        } else if (connectivityResult.contains(ConnectivityResult.vpn)) {
          connectionType = 'VPN';
        } else if (connectivityResult.contains(ConnectivityResult.bluetooth)) {
          connectionType = 'Bluetooth';
        } else if (connectivityResult.contains(ConnectivityResult.other)) {
          connectionType = 'Other';
        }
        
        return {
          'isConnected': isConnected,
          'hasInternet': isConnected, // Assume internet if connected
          'connectionType': connectionType,
          'platform': Platform.operatingSystem,
        };
      } catch (e) {
        _logger.e('Error checking network status with connectivity_plus', error: e);
        return {
          'isConnected': false,
          'hasInternet': false,
          'connectionType': 'Unknown',
          'error': e.toString(),
        };
      }
    }
    
    // For Android, use the custom platform channel
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
    
    // For macOS and iOS, use basic connectivity info
    if (!kIsWeb && (Platform.isMacOS || Platform.isIOS)) {
      try {
        final connectivity = Connectivity();
        final connectivityResult = await connectivity.checkConnectivity();
        
        return {
          'platform': Platform.operatingSystem,
          'available': true,
          'connectionTypes': connectivityResult.map((e) => e.name).toList(),
          'isConnected': !connectivityResult.contains(ConnectivityResult.none),
        };
      } catch (e) {
        _logger.e('Error getting network diagnostics with connectivity_plus', error: e);
        return {'error': e.toString()};
      }
    }
    
    // For Android, use the custom platform channel
    try {
      final result = await _networkChannel.invokeMethod(
        'getNetworkDiagnostics',
      );
      return Map<String, dynamic>.from(result as Map);
    } on MissingPluginException {
      // Method channel not implemented - this is expected on some platforms
      return {'available': false, 'reason': 'Method not implemented'};
    } catch (e) {
      _logger.e('Error getting network diagnostics', error: e);
      return {'error': e.toString()};
    }
  }

  /// Log network state on app startup for debugging
  static Future<void> logNetworkState() async {
  }
}
