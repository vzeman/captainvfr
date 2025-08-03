import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'flight/models/flight_constants.dart';

/// Service that provides always-on heading data independent from flight tracking
/// Uses the compass sensor to continuously monitor heading when the app is running
class HeadingService extends ChangeNotifier {
  // Compass subscription
  StreamSubscription<CompassEvent>? _compassSubscription;
  
  // Current heading value
  double? _currentHeading;
  
  // Throttling
  DateTime? _lastCompassUpdate;
  
  // Service state
  bool _isInitialized = false;
  bool _isRunning = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // Getters
  double? get currentHeading => _currentHeading;
  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
  bool get hasCompass => _compassSubscription != null;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  
  /// Initialize the heading service
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      // Mark as initialized early to prevent multiple initialization attempts
      _isInitialized = true;
      
      // Try to start compass updates regardless of permissions
      // The service will work when permissions are granted later
      await startHeadingUpdates();
      
      // If not running yet, schedule periodic retries
      if (!_isRunning) {
        _schedulePeriodicRetry();
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
  
  /// Schedule periodic retry attempts to start compass
  void _schedulePeriodicRetry() {
    int retryCount = 0;
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isRunning) {
        timer.cancel();
      } else if (_hasError) {
        // Stop retrying if there's a permanent error
        timer.cancel();
      } else if (retryCount >= 6) {
        // Stop retrying after 1 minute (6 attempts * 10 seconds)
        timer.cancel();
      } else {
        retryCount++;
        startHeadingUpdates();
      }
    });
  }
  
  /// Retry starting heading updates (called when permissions are granted)
  Future<void> retryStart() async {
    if (_isRunning) {
      return;
    }
    
    // Reset error state to allow fresh permission check
    _hasError = false;
    _errorMessage = null;
    
    await startHeadingUpdates();
  }
  
  /// Start compass updates
  Future<void> startHeadingUpdates() async {
    if (_isRunning) {
      return;
    }
    
    try {
      // Check permissions first but don't fail if denied
      final hasPermission = await _checkCompassPermissions();
      
      // Check current permission status
      final status = await Permission.locationWhenInUse.status;
      
      if (!hasPermission) {
        // Check if permission is permanently denied
        if (status.isPermanentlyDenied) {
          _hasError = true;
          _errorMessage = 'Location permission permanently denied. Please enable in Settings.';
          notifyListeners(); // Notify listeners about the error state
          return; // STOP RETRYING - permission is permanently denied
        }
        
        // Don't schedule another retry if there's already an error
        if (!_hasError) {
          // Schedule a retry in 5 seconds (less aggressive)
          Future.delayed(const Duration(seconds: 5), () {
            if (!_isRunning && !_hasError) {
              startHeadingUpdates();
            }
          });
        }
        return;
      }
      
      // Check if compass is available (may not be on some platforms like macOS)
      final compassEvents = FlutterCompass.events;
      if (compassEvents == null) {
        _hasError = true;
        _errorMessage = 'Compass not available on this device';
        notifyListeners();
        return;
      }
      
      _compassSubscription = compassEvents.listen(
        (CompassEvent event) {
          if (event.heading != null) {
            final oldHeading = _currentHeading;
            _currentHeading = event.heading;
            
            // Mark as running on first successful heading
            if (!_isRunning) {
              _isRunning = true;
              _hasError = false;
              _errorMessage = null;
            }
            
            // Throttle compass updates to max 2 per second to avoid excessive UI updates
            final now = DateTime.now();
            if (_lastCompassUpdate == null ||
                now.difference(_lastCompassUpdate!).inMilliseconds > 
                FlightConstants.compassThrottleInterval.inMilliseconds) {
              _lastCompassUpdate = now;
              
              // Only log significant changes to reduce log spam
              if (oldHeading == null || (oldHeading - _currentHeading!).abs() > 5) {
              }
              
              notifyListeners();
            }
          } else {
          }
        },
        onError: (error) {
          _hasError = true;
          _errorMessage = error.toString();
        },
      );
      
      if (_compassSubscription != null) {
        // Don't mark as running yet - wait for first heading
        // Set a timeout to check if we receive any data
        Future.delayed(const Duration(seconds: 3), () {
          if (!_isRunning && _compassSubscription != null) {
            // Don't treat this as an error - compass might still initialize
            // This often happens on iOS Simulator where compass doesn't work
            _hasError = false;
            _errorMessage = null;
            notifyListeners();
          }
        });
      } else {
        // Don't treat this as a hard error
        _hasError = false;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      // Don't treat exceptions as hard errors
      _hasError = false;
      _errorMessage = null;
    }
  }
  
  /// Stop compass updates
  void stopHeadingUpdates() {
    if (!_isRunning) return;
    
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _isRunning = false;
  }
  
  /// Check if compass/heading is available
  bool get isCompassAvailable {
    // Check if platform supports compass
    final bool supportsCompass = !kIsWeb && 
        (Platform.isIOS || Platform.isAndroid);
    
    return supportsCompass && _compassSubscription != null;
  }
  
  /// Get formatted heading string
  String getFormattedHeading() {
    if (_currentHeading == null) return '---°';
    return '${_currentHeading!.round()}°';
  }
  
  /// Get cardinal direction from heading
  String getCardinalDirection() {
    if (_currentHeading == null) return '---';
    
    final heading = _currentHeading!;
    
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    if (heading >= 292.5 && heading < 337.5) return 'NW';
    
    return '---';
  }
  
  /// Request compass calibration (iOS will show calibration UI if needed)
  Future<void> requestCalibration() async {
    
    // On iOS, we can trigger calibration by restarting the compass
    if (Platform.isIOS) {
      stopHeadingUpdates();
      await Future.delayed(const Duration(milliseconds: 500));
      await startHeadingUpdates();
    } else {
      // On Android, calibration is automatic with figure-8 motion
    }
  }

  /// Check if compass permissions are available
  Future<bool> _checkCompassPermissions() async {
    try {
      // On iOS and Android, location permission is required for compass
      if (Platform.isIOS || Platform.isAndroid) {
        // Check both whenInUse and always permissions
        var whenInUseStatus = await Permission.locationWhenInUse.status;
        var alwaysStatus = await Permission.locationAlways.status;
        
        
        // If we have either permission, we're good
        if (whenInUseStatus.isGranted || whenInUseStatus.isLimited || 
            alwaysStatus.isGranted || alwaysStatus.isLimited) {
          _hasError = false;
          _errorMessage = null;
          return true;
        }
        
        // If both are denied, try requesting whenInUse
        if (whenInUseStatus.isDenied) {
          whenInUseStatus = await Permission.locationWhenInUse.request();
          
          if (whenInUseStatus.isPermanentlyDenied) {
            _hasError = true;
            _errorMessage = 'Location permission permanently denied. Please enable in Settings.';
            return false;
          }
        } else if (whenInUseStatus.isPermanentlyDenied) {
          _hasError = true;
          _errorMessage = 'Location permission permanently denied. Please enable in Settings.';
          return false;
        }
        
        // Check again after request
        return whenInUseStatus.isGranted || whenInUseStatus.isLimited ||
               alwaysStatus.isGranted || alwaysStatus.isLimited;
      }
      // For other platforms (macOS, Windows, etc.), assume available
      return true;
    } catch (e) {
      // Try to continue anyway - the compass might work
      return true;
    }
  }
  
  @override
  void dispose() {
    stopHeadingUpdates();
    super.dispose();
  }
}