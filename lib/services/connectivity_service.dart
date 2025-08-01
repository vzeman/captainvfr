import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _hasInternetConnection = true;
  bool _isCheckingConnection = false;
  DateTime? _lastConnectionCheck;

  bool get hasInternetConnection => _hasInternetConnection;
  bool get isCheckingConnection => _isCheckingConnection;

  // Google's DNS server - highly reliable for connectivity checks
  static const String _connectivityCheckUrl =
      'https://dns.google/resolve?name=google.com';
  static const Duration _checkTimeout = Duration(seconds: 5);
  static const Duration _checkInterval = Duration(minutes: 1);

  Future<void> initialize() async {
    // debugPrint('🌐 Initializing connectivity service...');

    // Don't block on initial connectivity check - do it in background
    checkInternetConnection(silent: true)
        .then((_) {
          // debugPrint('🌐 Initial connectivity check completed');
        })
        .catchError((e) {
          // debugPrint('⚠️ Initial connectivity check failed: $e');
        });

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      // debugPrint('📡 Connectivity changed: $results');

      // Even if we have network connectivity, we need to verify internet access
      await checkInternetConnection();
    });
  }

  /// Checks if the device has actual internet connectivity
  /// This performs an HTTP request to verify internet access, not just network connectivity
  Future<bool> checkInternetConnection({bool silent = false}) async {
    // Avoid checking too frequently
    if (_lastConnectionCheck != null) {
      final timeSinceLastCheck = DateTime.now().difference(
        _lastConnectionCheck!,
      );
      if (timeSinceLastCheck < const Duration(seconds: 180)) {
        return _hasInternetConnection;
      }
    }

    // Store previous state to detect changes
    final previousConnectionState = _hasInternetConnection;
    final previousCheckingState = _isCheckingConnection;

    if (!silent) {
      _isCheckingConnection = true;
      if (previousCheckingState != _isCheckingConnection) {
        notifyListeners();
      }
    }

    try {
      // First check basic connectivity
      final connectivityResult = await _connectivity.checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none)) {
        // debugPrint('❌ No network connectivity');
        _hasInternetConnection = false;
        _lastConnectionCheck = DateTime.now();
        // Only notify if connection state changed and no text field has focus
        if (previousConnectionState != _hasInternetConnection && !silent) {
          notifyListeners();
        }
        return false;
      }

      // Then verify actual internet access with HTTP request
      try {
        final response = await http
            .get(
              Uri.parse(_connectivityCheckUrl),
              headers: {'Accept': 'application/json'},
            )
            .timeout(_checkTimeout);

        _hasInternetConnection = response.statusCode == 200;
        // debugPrint(_hasInternetConnection
        //   ? '✅ Internet connection verified'
        //   : '❌ Internet check failed with status: ${response.statusCode}'
        // );
      } catch (e) {
        // If the HTTP request fails, we don't have internet
        _hasInternetConnection = false;
        // debugPrint('❌ Internet check failed: $e');
      }

      _lastConnectionCheck = DateTime.now();
    } catch (e) {
      // debugPrint('❌ Error checking connectivity: $e');
      _hasInternetConnection = false;
    } finally {
      if (!silent) {
        _isCheckingConnection = false;
      }
      // Only notify if state actually changed and no text field has focus
      if ((previousConnectionState != _hasInternetConnection || 
           previousCheckingState != _isCheckingConnection) && !silent) {
        notifyListeners();
      }
    }

    return _hasInternetConnection;
  }

  /// Get a user-friendly message about the current connection status
  String getConnectionStatusMessage() {
    if (_isCheckingConnection) {
      return 'Checking internet connection...';
    }

    if (!_hasInternetConnection) {
      return 'No internet connection. Some features may be limited.';
    }

    return 'Connected to internet';
  }

  /// Get features that are affected by lack of internet
  List<String> getAffectedFeatures() {
    return [
      'Live weather updates',
      'Airport information updates',
      'Map tile downloads',
      'Frequency information',
      'NAVAID updates',
    ];
  }

  /// Perform periodic connectivity checks
  void startPeriodicChecks() {
    Timer.periodic(_checkInterval, (timer) async {
      if (!_isCheckingConnection) {
        // Use silent mode for periodic checks to avoid unnecessary UI updates
        await checkInternetConnection(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
