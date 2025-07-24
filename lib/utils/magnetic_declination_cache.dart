import 'magnetic_declination_simple.dart';

/// Cache for magnetic declination calculations to improve performance
class MagneticDeclinationCache {
  static final Map<String, double> _cache = {};
  static const int _maxCacheSize = 1000;
  static const int _precisionDecimals = 2;
  
  /// Get cached declination value or calculate and cache it
  static double getCached(double latitude, double longitude, {DateTime? date}) {
    // Create cache key with reduced precision to increase cache hits
    final key = _createKey(latitude, longitude, date);
    
    // Check cache first
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    
    // Calculate declination
    final declination = MagneticDeclinationSimple.calculate(
      latitude,
      longitude,
      date: date,
    );
    
    // Add to cache with size limit
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entries (simple FIFO)
      final keysToRemove = _cache.keys.take(_cache.length ~/ 4).toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }
    
    _cache[key] = declination;
    return declination;
  }
  
  /// Create cache key from coordinates with reduced precision
  static String _createKey(double latitude, double longitude, DateTime? date) {
    // Round to 2 decimal places (~1km precision)
    final lat = latitude.toStringAsFixed(_precisionDecimals);
    final lon = longitude.toStringAsFixed(_precisionDecimals);
    final year = (date ?? DateTime.now()).year;
    return '${lat}_${lon}_$year';
  }
  
  /// Clear the cache
  static void clearCache() {
    _cache.clear();
  }
  
  /// Get cache size for monitoring
  static int get cacheSize => _cache.length;
}