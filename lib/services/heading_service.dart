import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'flight/models/flight_constants.dart';
import 'flight/helpers/analytics_wrapper.dart';

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
  
  // Retry mechanism
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  
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
      
      // If not running yet, schedule retries with exponential backoff
      if (!_isRunning) {
        _scheduleRetryWithBackoff();
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      notifyListeners();
      // Schedule retry with exponential backoff on error
      _scheduleRetryWithBackoff();
    }
  }
  
  /// Schedule retry with exponential backoff
  void _scheduleRetryWithBackoff() {
    if (_retryCount >= _maxRetries) {
      // Max retries reached, stop trying
      return;
    }
    
    // Cancel any existing retry timer
    _retryTimer?.cancel();
    
    // Calculate delay with exponential backoff: 2s, 4s, 8s, 16s, 32s
    final delay = _baseRetryDelay * (1 << _retryCount);
    _retryCount++;
    
    _retryTimer = Timer(delay, () async {
      if (!_isRunning && !_hasError) {
        try {
          await startHeadingUpdates();
          if (_isRunning) {
            // Success! Reset retry count
            _retryCount = 0;
          } else {
            // Still not running, schedule another retry
            _scheduleRetryWithBackoff();
          }
        } catch (e) {
          // Error occurred, schedule another retry
          _scheduleRetryWithBackoff();
        }
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
      // Check permissions but on iOS, try anyway even if denied
      final hasPermission = await _checkCompassPermissions();
      
      // On iOS, always try to start compass even if permission check fails
      // This works around permission_handler caching issues
      if (!hasPermission && !Platform.isIOS) {
        // Only block on Android if permission is denied
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
              
              // Log significant changes
              if (oldHeading == null || (oldHeading - _currentHeading!).abs() > 5) {
                // Heading changed significantly
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
  /// 
  /// Note: On iOS, the permission_handler package has a known issue where it caches
  /// permission status and may incorrectly report permissions as denied even after
  /// the user grants them in Settings. This is a documented issue:
  /// https://github.com/Baseflow/flutter-permission-handler/issues/844
  /// 
  /// As a workaround, on iOS we attempt to use the compass regardless of the reported
  /// permission status. The compass will fail gracefully if permissions are truly denied.
  /// 
  /// On Android, we respect the permission status as reported since the caching issue
  /// doesn't affect Android in the same way.
  Future<bool> _checkCompassPermissions() async {
    try {
      // On iOS and Android, location permission is required for compass
      if (Platform.isIOS || Platform.isAndroid) {
        var whenInUseStatus = await Permission.locationWhenInUse.status;
        
        // On iOS, if permission is reported as denied but the user says it's allowed,
        // try to use the compass anyway - it might work
        if (Platform.isIOS && (whenInUseStatus.isDenied || whenInUseStatus.isPermanentlyDenied)) {
          // Track this issue for monitoring
          AnalyticsWrapper.track('compass_permission_denied_ios', {
            'status': whenInUseStatus.toString(),
            'workaround_applied': true,
          });
          // Don't set error, just try to use compass
          return true; // Try anyway on iOS
        }
        
        // For Android or if permission is granted, proceed normally
        if (whenInUseStatus.isGranted || whenInUseStatus.isLimited) {
          _hasError = false;
          _errorMessage = null;
          return true;
        }
        
        // Only request permission on Android
        if (Platform.isAndroid && whenInUseStatus.isDenied) {
          whenInUseStatus = await Permission.locationWhenInUse.request();
          if (whenInUseStatus.isPermanentlyDenied) {
            // Track when Android users permanently deny permission
            AnalyticsWrapper.track('compass_permission_permanently_denied_android');
          }
          return whenInUseStatus.isGranted || whenInUseStatus.isLimited;
        }
        
        // Track if we're falling through without permission
        if (Platform.isAndroid) {
          AnalyticsWrapper.track('compass_permission_denied_android', {
            'status': whenInUseStatus.toString(),
          });
        }
        
        return false;
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
    _retryTimer?.cancel();
    stopHeadingUpdates();
    super.dispose();
  }
}