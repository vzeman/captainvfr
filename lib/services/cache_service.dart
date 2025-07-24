import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/airport.dart';
import '../models/navaid.dart';
import '../models/runway.dart';
import '../models/frequency.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import 'cache_service_refactored.dart';

/// Cache service for storing airports, navaids, runways, frequencies, airspaces, and reporting points locally
/// This is a wrapper around CacheServiceRefactored to maintain backward compatibility
class CacheService extends ChangeNotifier {
  // Singleton pattern
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  
  // Delegate to refactored service
  final CacheServiceRefactored _refactoredService = CacheServiceRefactored();

  // Forward ChangeNotifier events
  CacheService._internal() {
    _refactoredService.addListener(_notifyListeners);
  }

  void _notifyListeners() {
    notifyListeners();
  }

  /// Initialize Hive boxes
  Future<void> initialize() async {
    await _refactoredService.initialize();
  }

  /// Cache airports data
  Future<void> cacheAirports(List<Airport> airports) async {
    await _refactoredService.cacheAirports(airports);
  }

  /// Cache runways data
  Future<void> cacheRunways(List<Runway> runways) async {
    await _refactoredService.cacheRunways(runways);
  }

  /// Cache navaids data
  Future<void> cacheNavaids(List<Navaid> navaids) async {
    await _refactoredService.cacheNavaids(navaids);
  }

  /// Cache frequencies data
  Future<void> cacheFrequencies(List<Frequency> frequencies) async {
    await _refactoredService.cacheFrequencies(frequencies);
  }

  /// Cache airspaces data (replaces all existing data)
  Future<void> cacheAirspaces(List<Airspace> airspaces) async {
    await _refactoredService.cacheAirspaces(airspaces);
  }

  /// Append airspaces data (adds to existing data without clearing)
  Future<void> appendAirspaces(List<Airspace> airspaces) async {
    await _refactoredService.appendAirspaces(airspaces);
  }

  /// Cache weather data for a specific ICAO code
  Future<void> cacheWeather(String icao, String weatherData) async {
    await _refactoredService.cacheWeather(icao, weatherData);
  }

  /// Cache weather data in bulk
  Future<void> cacheWeatherBulk(Map<String, dynamic> weatherData) async {
    await _refactoredService.cacheWeatherBulk(weatherData);
  }

  /// Get cached METAR for a specific ICAO code
  Future<String?> getCachedMetar(String icao) async {
    return await _refactoredService.getCachedMetar(icao);
  }

  /// Get cached TAF for a specific ICAO code
  Future<String?> getCachedTaf(String icao) async {
    return await _refactoredService.getCachedTaf(icao);
  }

  /// Get all cached METARs
  Future<Map<String, String>> getCachedMetars() async {
    return await _refactoredService.getCachedMetars();
  }

  /// Get all cached TAFs
  Future<Map<String, String>> getCachedTafs() async {
    return await _refactoredService.getCachedTafs();
  }

  /// Get cached airports
  Future<List<Airport>> getCachedAirports() async {
    return await _refactoredService.getCachedAirports();
  }

  /// Get cached runways
  Future<List<Runway>> getCachedRunways() async {
    return await _refactoredService.getCachedRunways();
  }

  /// Get cached navaids
  Future<List<Navaid>> getCachedNavaids() async {
    return await _refactoredService.getCachedNavaids();
  }

  /// Get cached frequencies
  Future<List<Frequency>> getCachedFrequencies() async {
    return await _refactoredService.getCachedFrequencies();
  }

  /// Get cached airspaces
  Future<List<Airspace>> getCachedAirspaces() async {
    return await _refactoredService.getCachedAirspaces();
  }

  /// Cache reporting points data (replaces all existing data)
  Future<void> cacheReportingPoints(List<ReportingPoint> points) async {
    await _refactoredService.cacheReportingPoints(points);
  }

  /// Append reporting points data (adds to existing data without clearing)
  Future<void> appendReportingPoints(List<ReportingPoint> points) async {
    await _refactoredService.appendReportingPoints(points);
  }

  /// Get cached reporting points
  Future<List<ReportingPoint>> getCachedReportingPoints() async {
    return await _refactoredService.getCachedReportingPoints();
  }

  /// Get cached weather data (legacy format)
  Future<String?> getCachedWeather(String icao) async {
    return await _refactoredService.getCachedWeather(icao);
  }

  /// Get airports last fetch timestamp
  Future<DateTime?> getAirportsLastFetch() async {
    return await _refactoredService.getAirportsLastFetch();
  }

  /// Get runways last fetch timestamp
  Future<DateTime?> getRunwaysLastFetch() async {
    return await _refactoredService.getRunwaysLastFetch();
  }

  /// Get navaids last fetch timestamp
  Future<DateTime?> getNavaidsLastFetch() async {
    return await _refactoredService.getNavaidsLastFetch();
  }

  /// Get frequencies last fetch timestamp
  Future<DateTime?> getFrequenciesLastFetch() async {
    return await _refactoredService.getFrequenciesLastFetch();
  }

  /// Get airspaces last fetch timestamp
  Future<DateTime?> getAirspacesLastFetch() async {
    return await _refactoredService.getAirspacesLastFetch();
  }

  /// Get reporting points last fetch timestamp
  Future<DateTime?> getReportingPointsLastFetch() async {
    return await _refactoredService.getReportingPointsLastFetch();
  }

  /// Get weather last fetch timestamp
  Future<DateTime?> getWeatherLastFetch() async {
    return await _refactoredService.getWeatherLastFetch();
  }

  /// Set runways last fetch timestamp
  Future<void> setRunwaysLastFetch(DateTime timestamp) async {
    await _refactoredService.setRunwaysLastFetch(timestamp);
  }

  /// Set navaids last fetch timestamp
  Future<void> setNavaidsLastFetch(DateTime timestamp) async {
    await _refactoredService.setNavaidsLastFetch(timestamp);
  }

  /// Set frequencies last fetch timestamp
  Future<void> setFrequenciesLastFetch(DateTime timestamp) async {
    await _refactoredService.setFrequenciesLastFetch(timestamp);
  }

  /// Set airspaces last fetch timestamp
  Future<void> setAirspacesLastFetch(DateTime timestamp) async {
    await _refactoredService.setAirspacesLastFetch(timestamp);
  }

  /// Set weather last fetch timestamp
  Future<void> setWeatherLastFetch(DateTime timestamp) async {
    await _refactoredService.setWeatherLastFetch(timestamp);
  }

  /// Clear airports cache
  Future<void> clearAirportsCache() async {
    await _refactoredService.clearAirportsCache();
  }

  /// Clear runways cache
  Future<void> clearRunwaysCache() async {
    await _refactoredService.clearRunwaysCache();
  }

  /// Clear navaids cache
  Future<void> clearNavaidsCache() async {
    await _refactoredService.clearNavaidsCache();
  }

  /// Clear frequencies cache
  Future<void> clearFrequenciesCache() async {
    await _refactoredService.clearFrequenciesCache();
  }

  /// Clear airspaces cache
  Future<void> clearAirspacesCache() async {
    await _refactoredService.clearAirspacesCache();
  }

  /// Clear reporting points cache
  Future<void> clearReportingPointsCache() async {
    await _refactoredService.clearReportingPointsCache();
  }

  /// Clear weather cache
  Future<void> clearWeatherCache() async {
    await _refactoredService.clearWeatherCache();
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await _refactoredService.clearAllCaches();
  }

  /// Clear frequencies cache (legacy)
  Future<void> clearFrequencies() async {
    await _refactoredService.clearFrequencies();
  }

  /// Generic cache operations for custom data
  Future<void> cacheData(String key, String data) async {
    await _refactoredService.cacheData(key, data);
  }

  /// Get cached custom data
  Future<String?> getCachedData(String key) async {
    return await _refactoredService.getCachedData(key);
  }

  /// Get cached data timestamp
  Future<DateTime?> getCachedDataTimestamp(String key) async {
    return await _refactoredService.getCachedDataTimestamp(key);
  }

  /// Clear cached custom data
  Future<void> clearCachedData(String key) async {
    await _refactoredService.clearCachedData(key);
  }

  /// Close all Hive boxes
  @override
  void dispose() {
    _refactoredService.removeListener(_notifyListeners);
    _refactoredService.dispose();
    super.dispose();
  }
}