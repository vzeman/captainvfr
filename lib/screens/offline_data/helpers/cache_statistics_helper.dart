import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../services/weather_service.dart';
import '../../../services/tiled_data_loader.dart';

/// Helper class for loading cache statistics
class CacheStatisticsHelper {
  static Future<Map<String, dynamic>> getCacheStatistics(WeatherService weatherService) async {
    final tiledDataLoader = TiledDataLoader();
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

      // Get obstacles and hotspots counts from index files
      try {
        final obstaclesIndexData = await rootBundle.loadString('assets/data/tiles/obstacles/index.json');
        final obstaclesIndex = json.decode(obstaclesIndexData);
        final obstacleCount = obstaclesIndex['totalItems'] ?? 0;
        developer.log('Obstacles total items from index: $obstacleCount');
        stats['obstacles'] = {
          'count': obstacleCount,
          'lastFetch': null, // Tiled data doesn't have fetch timestamps
        };
      } catch (e) {
        developer.log('Failed to load obstacles index: $e');
        // Fallback to spatial index if index file not found
        final obstaclesIndex = tiledDataLoader.getSpatialIndex('obstacles');
        final spatialCount = obstaclesIndex?.size ?? 0;
        developer.log('Obstacles from spatial index: $spatialCount');
        stats['obstacles'] = {
          'count': spatialCount,
          'lastFetch': null,
        };
      }

      try {
        final hotspotsIndexData = await rootBundle.loadString('assets/data/tiles/hotspots/index.json');
        final hotspotsIndex = json.decode(hotspotsIndexData);
        final hotspotCount = hotspotsIndex['totalItems'] ?? 0;
        developer.log('Hotspots total items from index: $hotspotCount');
        stats['hotspots'] = {
          'count': hotspotCount,
          'lastFetch': null, // Tiled data doesn't have fetch timestamps
        };
      } catch (e) {
        developer.log('Failed to load hotspots index: $e');
        // Fallback to spatial index if index file not found
        final hotspotsIndex = tiledDataLoader.getSpatialIndex('hotspots');
        final spatialCount = hotspotsIndex?.size ?? 0;
        developer.log('Hotspots from spatial index: $spatialCount');
        stats['hotspots'] = {
          'count': spatialCount,
          'lastFetch': null,
        };
      }
    } catch (e) {
      // Handle error silently
    }

    return stats;
  }
}