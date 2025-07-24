import 'dart:developer' as developer;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/cache_constants.dart';

/// Repository for caching weather data (METAR/TAF)
class WeatherCacheRepository {
  late Box<String> _weatherBox;
  late Box<dynamic> _metadataBox;

  /// Initialize the repository with the required boxes
  void initialize(Box<String> weatherBox, Box<dynamic> metadataBox) {
    _weatherBox = weatherBox;
    _metadataBox = metadataBox;
  }

  /// Cache weather data for a specific ICAO code
  Future<void> cacheWeather(String icao, String weatherData) async {
    try {
      await _weatherBox.put(icao, weatherData);
      
      // Update last fetch timestamp
      await _metadataBox.put(
        CacheConstants.weatherLastFetchKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      developer.log('❌ Error caching weather for $icao: $e');
      rethrow;
    }
  }

  /// Cache weather data in bulk
  Future<void> cacheWeatherBulk(Map<String, dynamic> weatherData) async {
    try {
      developer.log('💾 Caching weather data for ${weatherData.length} airports...');

      // Clear existing weather data
      await _weatherBox.clear();

      // Store METAR and TAF data
      for (final entry in weatherData.entries) {
        final icao = entry.key;
        final data = entry.value as Map<String, dynamic>;

        if (data.containsKey('metar')) {
          await _weatherBox.put(
            '${CacheConstants.metarPrefix}$icao',
            data['metar'] as String,
          );
        }

        if (data.containsKey('taf')) {
          await _weatherBox.put(
            '${CacheConstants.tafPrefix}$icao',
            data['taf'] as String,
          );
        }
      }

      // Update last fetch timestamp
      await _metadataBox.put(
        CacheConstants.weatherLastFetchKey,
        DateTime.now().toIso8601String(),
      );

      developer.log('✅ Cached weather data successfully');
    } catch (e) {
      developer.log('❌ Error caching weather data: $e');
      rethrow;
    }
  }

  /// Get cached METAR for a specific ICAO code
  Future<String?> getCachedMetar(String icao) async {
    try {
      return _weatherBox.get('${CacheConstants.metarPrefix}$icao');
    } catch (e) {
      developer.log('⚠️ Error getting cached METAR for $icao: $e');
      return null;
    }
  }

  /// Get cached TAF for a specific ICAO code
  Future<String?> getCachedTaf(String icao) async {
    try {
      return _weatherBox.get('${CacheConstants.tafPrefix}$icao');
    } catch (e) {
      developer.log('⚠️ Error getting cached TAF for $icao: $e');
      return null;
    }
  }

  /// Get all cached METARs
  Future<Map<String, String>> getCachedMetars() async {
    try {
      final metars = <String, String>{};
      
      for (final key in _weatherBox.keys) {
        if (key.startsWith(CacheConstants.metarPrefix)) {
          final icao = key.substring(CacheConstants.metarPrefix.length);
          final metar = _weatherBox.get(key);
          if (metar != null) {
            metars[icao] = metar;
          }
        }
      }

      return metars;
    } catch (e) {
      developer.log('❌ Error getting cached METARs: $e');
      return {};
    }
  }

  /// Get all cached TAFs
  Future<Map<String, String>> getCachedTafs() async {
    try {
      final tafs = <String, String>{};
      
      for (final key in _weatherBox.keys) {
        if (key.startsWith(CacheConstants.tafPrefix)) {
          final icao = key.substring(CacheConstants.tafPrefix.length);
          final taf = _weatherBox.get(key);
          if (taf != null) {
            tafs[icao] = taf;
          }
        }
      }

      return tafs;
    } catch (e) {
      developer.log('❌ Error getting cached TAFs: $e');
      return {};
    }
  }

  /// Get cached weather data (legacy format)
  Future<String?> getCachedWeather(String icao) async {
    try {
      return _weatherBox.get(icao);
    } catch (e) {
      developer.log('⚠️ Error getting cached weather for $icao: $e');
      return null;
    }
  }

  /// Get last fetch timestamp for weather data
  Future<DateTime?> getWeatherLastFetch() async {
    try {
      final timestamp = _metadataBox.get(CacheConstants.weatherLastFetchKey);
      if (timestamp != null) {
        return DateTime.parse(timestamp as String);
      }
    } catch (e) {
      developer.log('⚠️ Error parsing weather last fetch timestamp: $e');
    }
    return null;
  }

  /// Set last fetch timestamp for weather data
  Future<void> setWeatherLastFetch(DateTime timestamp) async {
    await _metadataBox.put(
      CacheConstants.weatherLastFetchKey,
      timestamp.toIso8601String(),
    );
  }

  /// Clear weather cache
  Future<void> clearWeatherCache() async {
    await _weatherBox.clear();
    await _metadataBox.delete(CacheConstants.weatherLastFetchKey);
  }
}