import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/airport.dart';
import '../models/navaid.dart';
import '../models/runway.dart';
import '../models/frequency.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import 'cache/utils/cache_manager.dart';
import 'cache/repositories/airport_cache_repository.dart';
import 'cache/repositories/navaid_cache_repository.dart';
import 'cache/repositories/runway_cache_repository.dart';
import 'cache/repositories/frequency_cache_repository.dart';
import 'cache/repositories/airspace_cache_repository.dart';
import 'cache/repositories/reporting_point_cache_repository.dart';
import 'cache/repositories/weather_cache_repository.dart';

/// Refactored cache service using repository pattern
class CacheServiceRefactored extends ChangeNotifier {
  // Singleton pattern
  static final CacheServiceRefactored _instance = CacheServiceRefactored._internal();
  factory CacheServiceRefactored() => _instance;
  CacheServiceRefactored._internal();

  final CacheManager _cacheManager = CacheManager();
  
  // Repositories
  final AirportCacheRepository _airportRepository = AirportCacheRepository();
  final NavaidCacheRepository _navaidRepository = NavaidCacheRepository();
  final RunwayCacheRepository _runwayRepository = RunwayCacheRepository();
  final FrequencyCacheRepository _frequencyRepository = FrequencyCacheRepository();
  final AirspaceCacheRepository _airspaceRepository = AirspaceCacheRepository();
  final ReportingPointCacheRepository _reportingPointRepository = ReportingPointCacheRepository();
  final WeatherCacheRepository _weatherRepository = WeatherCacheRepository();

  /// Initialize the cache service
  Future<void> initialize() async {
    await _cacheManager.initialize();
    
    // Initialize all repositories with their boxes
    _airportRepository.initialize(_cacheManager.airportsBox, _cacheManager.metadataBox);
    _navaidRepository.initialize(_cacheManager.navaidsBox, _cacheManager.metadataBox);
    _runwayRepository.initialize(_cacheManager.runwaysBox, _cacheManager.metadataBox);
    _frequencyRepository.initialize(_cacheManager.frequenciesBox, _cacheManager.metadataBox);
    _airspaceRepository.initialize(_cacheManager.airspacesBox, _cacheManager.metadataBox);
    _reportingPointRepository.initialize(_cacheManager.reportingPointsBox, _cacheManager.metadataBox);
    _weatherRepository.initialize(_cacheManager.weatherBox, _cacheManager.metadataBox);
  }

  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    await _cacheManager.ensureInitialized();
  }

  // Airport operations
  Future<void> cacheAirports(List<Airport> airports) async {
    await _ensureInitialized();
    await _airportRepository.cacheAirports(airports);
  }

  Future<List<Airport>> getCachedAirports() async {
    await _ensureInitialized();
    return await _airportRepository.getCachedAirports();
  }

  Future<DateTime?> getAirportsLastFetch() async {
    await _ensureInitialized();
    return await _airportRepository.getLastFetch();
  }

  Future<void> clearAirportsCache() async {
    await _ensureInitialized();
    await _airportRepository.clearCache();
  }

  // Navaid operations
  Future<void> cacheNavaids(List<Navaid> navaids) async {
    await _ensureInitialized();
    await _navaidRepository.cacheNavaids(navaids);
  }

  Future<List<Navaid>> getCachedNavaids() async {
    await _ensureInitialized();
    return await _navaidRepository.getCachedNavaids();
  }

  Future<DateTime?> getNavaidsLastFetch() async {
    await _ensureInitialized();
    return await _navaidRepository.getLastFetch();
  }

  Future<void> setNavaidsLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _navaidRepository.setLastFetch(timestamp);
  }

  Future<void> clearNavaidsCache() async {
    await _ensureInitialized();
    await _navaidRepository.clearCache();
  }

  // Runway operations
  Future<void> cacheRunways(List<Runway> runways) async {
    await _ensureInitialized();
    await _runwayRepository.cacheRunways(runways);
  }

  Future<List<Runway>> getCachedRunways() async {
    await _ensureInitialized();
    return await _runwayRepository.getCachedRunways();
  }

  Future<DateTime?> getRunwaysLastFetch() async {
    await _ensureInitialized();
    return await _runwayRepository.getLastFetch();
  }

  Future<void> setRunwaysLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _runwayRepository.setLastFetch(timestamp);
  }

  Future<void> clearRunwaysCache() async {
    await _ensureInitialized();
    await _runwayRepository.clearCache();
  }

  // Frequency operations
  Future<void> cacheFrequencies(List<Frequency> frequencies) async {
    await _ensureInitialized();
    await _frequencyRepository.cacheFrequencies(frequencies);
  }

  Future<List<Frequency>> getCachedFrequencies() async {
    await _ensureInitialized();
    return await _frequencyRepository.getCachedFrequencies();
  }

  Future<DateTime?> getFrequenciesLastFetch() async {
    await _ensureInitialized();
    return await _frequencyRepository.getLastFetch();
  }

  Future<void> setFrequenciesLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _frequencyRepository.setLastFetch(timestamp);
  }

  Future<void> clearFrequenciesCache() async {
    await _ensureInitialized();
    await _frequencyRepository.clearCache();
  }

  Future<void> clearFrequencies() async {
    await clearFrequenciesCache();
  }

  // Airspace operations
  Future<void> cacheAirspaces(List<Airspace> airspaces) async {
    await _ensureInitialized();
    await _airspaceRepository.cacheAirspaces(airspaces);
    notifyListeners();
  }

  Future<void> appendAirspaces(List<Airspace> airspaces) async {
    await _ensureInitialized();
    await _airspaceRepository.appendAirspaces(airspaces);
    notifyListeners();
  }

  Future<List<Airspace>> getCachedAirspaces() async {
    await _ensureInitialized();
    return await _airspaceRepository.getCachedAirspaces();
  }

  Future<DateTime?> getAirspacesLastFetch() async {
    await _ensureInitialized();
    return await _airspaceRepository.getLastFetch();
  }

  Future<void> setAirspacesLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _airspaceRepository.setLastFetch(timestamp);
  }

  Future<void> clearAirspacesCache() async {
    await _ensureInitialized();
    await _airspaceRepository.clearCache();
    notifyListeners();
  }

  // Reporting point operations
  Future<void> cacheReportingPoints(List<ReportingPoint> points) async {
    await _ensureInitialized();
    await _reportingPointRepository.cacheReportingPoints(points);
    notifyListeners();
  }

  Future<void> appendReportingPoints(List<ReportingPoint> points) async {
    await _ensureInitialized();
    await _reportingPointRepository.appendReportingPoints(points);
    notifyListeners();
  }

  Future<List<ReportingPoint>> getCachedReportingPoints() async {
    await _ensureInitialized();
    return await _reportingPointRepository.getCachedReportingPoints();
  }

  Future<DateTime?> getReportingPointsLastFetch() async {
    await _ensureInitialized();
    return await _reportingPointRepository.getLastFetch();
  }

  Future<void> clearReportingPointsCache() async {
    await _ensureInitialized();
    await _reportingPointRepository.clearCache();
  }

  // Weather operations
  Future<void> cacheWeather(String icao, String weatherData) async {
    await _ensureInitialized();
    await _weatherRepository.cacheWeather(icao, weatherData);
  }

  Future<void> cacheWeatherBulk(Map<String, dynamic> weatherData) async {
    await _ensureInitialized();
    await _weatherRepository.cacheWeatherBulk(weatherData);
  }

  Future<String?> getCachedMetar(String icao) async {
    await _ensureInitialized();
    return await _weatherRepository.getCachedMetar(icao);
  }

  Future<String?> getCachedTaf(String icao) async {
    await _ensureInitialized();
    return await _weatherRepository.getCachedTaf(icao);
  }

  Future<Map<String, String>> getCachedMetars() async {
    await _ensureInitialized();
    return await _weatherRepository.getCachedMetars();
  }

  Future<Map<String, String>> getCachedTafs() async {
    await _ensureInitialized();
    return await _weatherRepository.getCachedTafs();
  }

  Future<String?> getCachedWeather(String icao) async {
    await _ensureInitialized();
    return await _weatherRepository.getCachedWeather(icao);
  }

  Future<DateTime?> getWeatherLastFetch() async {
    await _ensureInitialized();
    return await _weatherRepository.getWeatherLastFetch();
  }

  Future<void> setWeatherLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _weatherRepository.setWeatherLastFetch(timestamp);
  }

  Future<void> clearWeatherCache() async {
    await _ensureInitialized();
    await _weatherRepository.clearWeatherCache();
  }

  // General cache operations
  Future<void> clearAllCaches() async {
    await _ensureInitialized();
    await _cacheManager.clearAllCaches();
    notifyListeners();
  }

  // Generic cache operations for backward compatibility
  Future<void> cacheData(String key, String data) async {
    await _ensureInitialized();
    try {
      await _cacheManager.metadataBox.put(key, {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      developer.log('❌ Error caching data for key $key: $e');
      rethrow;
    }
  }

  Future<String?> getCachedData(String key) async {
    await _ensureInitialized();
    try {
      final cached = _cacheManager.metadataBox.get(key);
      if (cached != null && cached is Map) {
        return cached['data'] as String?;
      }
    } catch (e) {
      developer.log('⚠️ Error getting cached data for key $key: $e');
    }
    return null;
  }

  Future<DateTime?> getCachedDataTimestamp(String key) async {
    await _ensureInitialized();
    try {
      final cached = _cacheManager.metadataBox.get(key);
      if (cached != null && cached is Map && cached['timestamp'] != null) {
        return DateTime.parse(cached['timestamp'] as String);
      }
    } catch (e) {
      developer.log('⚠️ Error getting cached timestamp for key $key: $e');
    }
    return null;
  }

  Future<void> clearCachedData(String key) async {
    await _ensureInitialized();
    try {
      await _cacheManager.metadataBox.delete(key);
    } catch (e) {
      developer.log('⚠️ Error clearing cached data for key $key: $e');
    }
  }

  @override
  void dispose() {
    _cacheManager.dispose();
    super.dispose();
  }
}