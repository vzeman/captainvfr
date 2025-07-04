
import 'package:logger/logger.dart';
import 'platform_services.dart';

/// Service for handling vibration alerts in the app
/// Properly handles Android 12+ vibration permissions
class VibrationAlertService {
  static final _logger = Logger();
  static bool _hasVibrator = false;
  static bool _initialized = false;

  /// Initialize the vibration service
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _hasVibrator = await PlatformServices.hasVibrator();
      _initialized = true;
      _logger.d('VibrationAlertService initialized. Has vibrator: $_hasVibrator');
    } catch (e) {
      _logger.e('Failed to initialize VibrationAlertService', error: e);
      _hasVibrator = false;
      _initialized = true;
    }
  }

  /// Alert for excessive G-force
  static Future<void> alertHighGForce() async {
    if (!_hasVibrator) return;
    
    try {
      // Pattern: wait 0ms, vibrate 100ms, wait 100ms, vibrate 100ms
      await PlatformServices.vibratePattern(
        pattern: [0, 100, 100, 100],
        repeat: -1, // Don't repeat
      );
    } catch (e) {
      _logger.e('Failed to vibrate for high G-force', error: e);
    }
  }

  /// Alert for stall warning
  static Future<void> alertStallWarning() async {
    if (!_hasVibrator) return;
    
    try {
      // Longer vibration pattern for stall warning
      await PlatformServices.vibratePattern(
        pattern: [0, 200, 100, 200, 100, 200],
        repeat: -1,
      );
    } catch (e) {
      _logger.e('Failed to vibrate for stall warning', error: e);
    }
  }

  /// Alert for terrain proximity
  static Future<void> alertTerrainProximity() async {
    if (!_hasVibrator) return;
    
    try {
      // Quick pulses for terrain warning
      await PlatformServices.vibratePattern(
        pattern: [0, 50, 50, 50, 50, 50, 50, 50],
        repeat: -1,
      );
    } catch (e) {
      _logger.e('Failed to vibrate for terrain proximity', error: e);
    }
  }

  /// Alert for overspeed
  static Future<void> alertOverspeed() async {
    if (!_hasVibrator) return;
    
    try {
      // Continuous short vibration
      await PlatformServices.vibrate(duration: 500);
    } catch (e) {
      _logger.e('Failed to vibrate for overspeed', error: e);
    }
  }

  /// Generic feedback vibration
  static Future<void> feedback() async {
    if (!_hasVibrator) return;
    
    try {
      await PlatformServices.vibrate(duration: 50);
    } catch (e) {
      _logger.e('Failed to provide haptic feedback', error: e);
    }
  }

  /// Test vibration functionality
  static Future<void> test() async {
    if (!_initialized) {
      await initialize();
    }
    
    if (_hasVibrator) {
      _logger.d('Testing vibration patterns...');
      
      // Test different patterns
      await Future.delayed(const Duration(milliseconds: 500));
      _logger.d('Testing feedback vibration');
      await feedback();
      
      await Future.delayed(const Duration(seconds: 1));
      _logger.d('Testing high G-force alert');
      await alertHighGForce();
      
      await Future.delayed(const Duration(seconds: 2));
      _logger.d('Testing stall warning');
      await alertStallWarning();
      
      _logger.d('Vibration test complete');
    } else {
      _logger.w('Cannot test vibration - device does not have vibrator');
    }
  }
}