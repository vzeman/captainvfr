import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
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
  
  // Getters
  double? get currentHeading => _currentHeading;
  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
  bool get hasCompass => _compassSubscription != null;
  
  /// Initialize the heading service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Start compass immediately upon initialization
      await startHeadingUpdates();
      _isInitialized = true;
      debugPrint('✅ HeadingService initialized successfully');
    } catch (e) {
      debugPrint('❌ HeadingService initialization failed: $e');
      _isInitialized = true; // Mark as initialized even if failed to avoid retry loops
    }
  }
  
  /// Start compass updates
  Future<void> startHeadingUpdates() async {
    if (_isRunning) return;
    
    try {
      // Check if compass is available (may not be on some platforms like macOS)
      _compassSubscription = FlutterCompass.events?.listen(
        (CompassEvent event) {
          if (event.heading != null) {
            _currentHeading = event.heading;
            
            // Throttle compass updates to max 2 per second to avoid excessive UI updates
            final now = DateTime.now();
            if (_lastCompassUpdate == null ||
                now.difference(_lastCompassUpdate!).inMilliseconds > 
                FlightConstants.compassThrottleInterval.inMilliseconds) {
              _lastCompassUpdate = now;
              notifyListeners();
            }
          }
        },
        onError: (error) {
          debugPrint('Compass error in HeadingService: $error');
        },
      );
      
      if (_compassSubscription != null) {
        _isRunning = true;
        debugPrint('✅ Compass updates started in HeadingService');
      } else {
        debugPrint('⚠️ Compass not available on this platform');
      }
    } catch (e) {
      debugPrint('❌ Failed to start compass updates: $e');
    }
  }
  
  /// Stop compass updates
  void stopHeadingUpdates() {
    if (!_isRunning) return;
    
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _isRunning = false;
    debugPrint('🛑 Compass updates stopped in HeadingService');
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
  
  @override
  void dispose() {
    stopHeadingUpdates();
    super.dispose();
  }
}