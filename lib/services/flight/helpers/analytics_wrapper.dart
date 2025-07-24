import '../../analytics_service.dart';

/// Static wrapper for analytics tracking
class AnalyticsWrapper {
  static final AnalyticsService _analytics = AnalyticsService();
  
  /// Track an event with optional properties
  static Future<void> track(String eventName, {Map<String, dynamic>? properties}) async {
    await _analytics.logEvent(name: eventName, parameters: properties);
  }
}