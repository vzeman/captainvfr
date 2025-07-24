import 'package:hive_flutter/hive_flutter.dart';
import '../../../services/weather_service.dart';

/// Helper class for loading cache statistics
class CacheStatisticsHelper {
  static Future<Map<String, dynamic>> getCacheStatistics(WeatherService weatherService) async {
    final Map<String, dynamic> stats = {};

    try {
      // Open boxes to get counts
      final airportsBox = await Hive.openBox<Map>('airports_cache');
      final navaidsBox = await Hive.openBox<Map>('navaids_cache');
      final runwaysBox = await Hive.openBox<Map>('runways_cache');
      final frequenciesBox = await Hive.openBox<Map>('frequencies_cache');
      final airspacesBox = await Hive.openBox<Map>('airspaces_cache');
      final reportingPointsBox = await Hive.openBox<Map>('reporting_points_cache');
      final metadataBox = await Hive.openBox('cache_metadata');

      // Get counts
      stats['airports'] = {
        'count': airportsBox.length,
        'lastFetch': metadataBox.get('airports_last_fetch'),
      };

      stats['navaids'] = {
        'count': navaidsBox.length,
        'lastFetch': metadataBox.get('navaids_last_fetch'),
      };

      stats['runways'] = {
        'count': runwaysBox.length,
        'lastFetch': metadataBox.get('runways_last_fetch'),
      };

      stats['frequencies'] = {
        'count': frequenciesBox.length,
        'lastFetch': metadataBox.get('frequencies_last_fetch'),
      };

      stats['airspaces'] = {
        'count': airspacesBox.length,
        'lastFetch': metadataBox.get('airspaces_last_fetch'),
      };

      stats['reportingPoints'] = {
        'count': reportingPointsBox.length,
        'lastFetch': metadataBox.get('reporting_points_last_fetch'),
      };

      // Get weather statistics from WeatherService
      final weatherStats = weatherService.getCacheStatistics();
      stats['weather'] = {
        'metars': weatherStats['metars'] ?? 0,
        'tafs': weatherStats['tafs'] ?? 0,
        'lastFetch': weatherStats['lastFetch']?.toIso8601String(),
      };
    } catch (e) {
      // Handle error silently
    }

    return stats;
  }
}