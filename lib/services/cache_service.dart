import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';
import '../models/navaid.dart';
import '../models/runway.dart';

/// Cache service for storing airports, navaids, and runways locally
class CacheService {
  static const String _airportsBoxName = 'airports_cache';
  static const String _navaidsBoxName = 'navaids_cache';
  static const String _runwaysBoxName = 'runways_cache';
  static const String _metadataBoxName = 'cache_metadata';
  static const String _weatherBoxName = 'weather_cache';

  static const String _airportsLastFetchKey = 'airports_last_fetch';
  static const String _navaidsLastFetchKey = 'navaids_last_fetch';
  static const String _runwaysLastFetchKey = 'runways_last_fetch';
  static const String _weatherLastFetchKey = 'weather_last_fetch';

  late Box<Map> _airportsBox;
  late Box<Map> _navaidsBox;
  late Box<Map> _runwaysBox;
  late Box<dynamic> _metadataBox;
  late Box<String> _weatherBox;

  bool _isInitialized = false;

  // Singleton pattern
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  /// Initialize Hive boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive with Flutter support
      await Hive.initFlutter();

      _airportsBox = await Hive.openBox<Map>(_airportsBoxName);
      _navaidsBox = await Hive.openBox<Map>(_navaidsBoxName);
      _runwaysBox = await Hive.openBox<Map>(_runwaysBoxName);
      _metadataBox = await Hive.openBox(_metadataBoxName);
      _weatherBox = await Hive.openBox<String>(_weatherBoxName);

      _isInitialized = true;
      print('✅ Cache service initialized');
    } catch (e) {
      print('❌ Error initializing cache service: $e');
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Cache airports data
  Future<void> cacheAirports(List<Airport> airports) async {
    await _ensureInitialized();

    try {
      print('💾 Caching ${airports.length} airports...');

      // Clear existing data
      await _airportsBox.clear();

      // Cache airports as maps
      for (final airport in airports) {
        await _airportsBox.put(airport.icao, {
          'icao': airport.icao,
          'name': airport.name,
          'municipality': airport.municipality,
          'country': airport.country,
          'region': airport.region,
          'type': airport.type,
          'latitude': airport.position.latitude,
          'longitude': airport.position.longitude,
          'elevation': airport.elevation,
          'iata': airport.iata,
          'website': airport.website,
          'phone': airport.phone,
          'runways': airport.runways,
          'frequencies': airport.frequencies,
        });
      }

      // Update last fetch timestamp
      await _metadataBox.put(_airportsLastFetchKey, DateTime.now().toIso8601String());

      print('✅ Cached ${airports.length} airports successfully');
    } catch (e) {
      print('❌ Error caching airports: $e');
      rethrow;
    }
  }

  /// Cache runways data
  Future<void> cacheRunways(List<Runway> runways) async {
    await _ensureInitialized();

    try {
      print('💾 Caching ${runways.length} runways...');

      // Clear existing data
      await _runwaysBox.clear();

      // Cache runways as maps
      for (final runway in runways) {
        await _runwaysBox.put('${runway.id}', runway.toMap());
      }

      // Update last fetch timestamp
      await _metadataBox.put(_runwaysLastFetchKey, DateTime.now().toIso8601String());

      print('✅ Cached ${runways.length} runways successfully');
    } catch (e) {
      print('❌ Error caching runways: $e');
      rethrow;
    }
  }

  /// Cache navaids data
  Future<void> cacheNavaids(List<Navaid> navaids) async {
    await _ensureInitialized();

    try {
      print('💾 Caching ${navaids.length} navaids...');

      // Clear existing data
      await _navaidsBox.clear();

      // Cache navaids as maps
      for (final navaid in navaids) {
        await _navaidsBox.put('${navaid.id}', navaid.toMap());
      }

      // Update last fetch timestamp
      await _metadataBox.put(_navaidsLastFetchKey, DateTime.now().toIso8601String());

      print('✅ Cached ${navaids.length} navaids successfully');
    } catch (e) {
      print('❌ Error caching navaids: $e');
      rethrow;
    }
  }

  /// Cache weather data
  Future<void> cacheWeather(String icao, String weatherData) async {
    await _ensureInitialized();

    try {
      await _weatherBox.put(icao, weatherData);
    } catch (e) {
      print('❌ Error caching weather data for $icao: $e');
      rethrow;
    }
  }

  /// Cache bulk weather data (METARs and TAFs)
  Future<void> cacheWeatherBulk(Map<String, String> metars, Map<String, String> tafs) async {
    await _ensureInitialized();

    try {
      print('💾 Caching ${metars.length} METARs and ${tafs.length} TAFs...');

      // Cache METARs with prefix
      for (final entry in metars.entries) {
        await _weatherBox.put('METAR_${entry.key}', entry.value);
      }

      // Cache TAFs with prefix
      for (final entry in tafs.entries) {
        await _weatherBox.put('TAF_${entry.key}', entry.value);
      }

      // Update last fetch timestamp
      await _metadataBox.put(_weatherLastFetchKey, DateTime.now().toIso8601String());

      print('✅ Cached ${metars.length} METARs and ${tafs.length} TAFs successfully');
    } catch (e) {
      print('❌ Error caching weather data: $e');
      rethrow;
    }
  }

  /// Get cached METAR data
  Future<String?> getCachedMetar(String icao) async {
    await _ensureInitialized();

    try {
      return _weatherBox.get('METAR_${icao.toUpperCase()}');
    } catch (e) {
      print('❌ Error loading cached METAR for $icao: $e');
      return null;
    }
  }

  /// Get cached TAF data
  Future<String?> getCachedTaf(String icao) async {
    await _ensureInitialized();

    try {
      return _weatherBox.get('TAF_${icao.toUpperCase()}');
    } catch (e) {
      print('❌ Error loading cached TAF for $icao: $e');
      return null;
    }
  }

  /// Get all cached METARs
  Future<Map<String, String>> getCachedMetars() async {
    await _ensureInitialized();

    try {
      final metars = <String, String>{};
      for (final key in _weatherBox.keys) {
        if (key.startsWith('METAR_')) {
          final icao = key.substring(6); // Remove 'METAR_' prefix
          final value = _weatherBox.get(key);
          if (value != null) {
            metars[icao] = value;
          }
        }
      }
      return metars;
    } catch (e) {
      print('❌ Error loading cached METARs: $e');
      return {};
    }
  }

  /// Get all cached TAFs
  Future<Map<String, String>> getCachedTafs() async {
    await _ensureInitialized();

    try {
      final tafs = <String, String>{};
      for (final key in _weatherBox.keys) {
        if (key.startsWith('TAF_')) {
          final icao = key.substring(4); // Remove 'TAF_' prefix
          final value = _weatherBox.get(key);
          if (value != null) {
            tafs[icao] = value;
          }
        }
      }
      return tafs;
    } catch (e) {
      print('❌ Error loading cached TAFs: $e');
      return {};
    }
  }

  /// Get cached airports
  Future<List<Airport>> getCachedAirports() async {
    await _ensureInitialized();

    try {
      final airports = <Airport>[];

      for (final key in _airportsBox.keys) {
        final data = _airportsBox.get(key);
        if (data != null) {
          final airport = Airport(
            icao: data['icao'] ?? '',
            name: data['name'] ?? '',
            city: data['municipality'] ?? '',
            country: data['country'] ?? '',
            position: LatLng(
              data['latitude']?.toDouble() ?? 0.0,
              data['longitude']?.toDouble() ?? 0.0,
            ),
            elevation: data['elevation'] ?? 0,
            type: data['type'] ?? 'small_airport',
            iata: data['iata'],
            website: data['website'],
            phone: data['phone'],
            runways: data['runways'],
            frequencies: data['frequencies'],
            municipality: data['municipality'],
            region: data['region'],
          );
          airports.add(airport);
        }
      }

      return airports;
    } catch (e) {
      print('❌ Error loading cached airports: $e');
      return [];
    }
  }

  /// Get cached runways
  Future<List<Runway>> getCachedRunways() async {
    await _ensureInitialized();

    try {
      final runways = <Runway>[];

      for (final key in _runwaysBox.keys) {
        final data = _runwaysBox.get(key);
        if (data != null) {
          final runway = Runway.fromMap(Map<String, dynamic>.from(data));
          runways.add(runway);
        }
      }

      return runways;
    } catch (e) {
      print('❌ Error loading cached runways: $e');
      return [];
    }
  }

  /// Get cached navaids
  Future<List<Navaid>> getCachedNavaids() async {
    await _ensureInitialized();

    try {
      final navaids = <Navaid>[];

      for (final key in _navaidsBox.keys) {
        final data = _navaidsBox.get(key);
        if (data != null) {
          final navaid = Navaid.fromMap(Map<String, dynamic>.from(data));
          navaids.add(navaid);
        }
      }

      return navaids;
    } catch (e) {
      print('❌ Error loading cached navaids: $e');
      return [];
    }
  }

  /// Get cached weather data
  Future<String?> getCachedWeather(String icao) async {
    await _ensureInitialized();

    try {
      return _weatherBox.get(icao);
    } catch (e) {
      print('❌ Error loading cached weather data for $icao: $e');
      return null;
    }
  }

  /// Get airports last fetch timestamp
  Future<DateTime?> getAirportsLastFetch() async {
    await _ensureInitialized();
    final timestampStr = _metadataBox.get(_airportsLastFetchKey);
    if (timestampStr != null) {
      return DateTime.tryParse(timestampStr);
    }
    return null;
  }

  /// Get runways last fetch timestamp
  Future<DateTime?> getRunwaysLastFetch() async {
    await _ensureInitialized();
    final timestampStr = _metadataBox.get(_runwaysLastFetchKey);
    if (timestampStr != null) {
      return DateTime.tryParse(timestampStr);
    }
    return null;
  }

  /// Get navaids last fetch timestamp
  Future<DateTime?> getNavaidsLastFetch() async {
    await _ensureInitialized();
    final timestampStr = _metadataBox.get(_navaidsLastFetchKey);
    if (timestampStr != null) {
      return DateTime.tryParse(timestampStr);
    }
    return null;
  }

  /// Get weather last fetch timestamp
  Future<DateTime?> getWeatherLastFetch() async {
    await _ensureInitialized();
    final timestampStr = _metadataBox.get(_weatherLastFetchKey);
    if (timestampStr != null) {
      return DateTime.tryParse(timestampStr);
    }
    return null;
  }

  /// Set runways last fetch timestamp
  Future<void> setRunwaysLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _metadataBox.put(_runwaysLastFetchKey, timestamp.toIso8601String());
  }

  /// Set navaids last fetch timestamp
  Future<void> setNavaidsLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _metadataBox.put(_navaidsLastFetchKey, timestamp.toIso8601String());
  }

  /// Set weather last fetch timestamp
  Future<void> setWeatherLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _metadataBox.put(_weatherLastFetchKey, timestamp.toIso8601String());
  }

  /// Clear runways cache
  Future<void> clearRunwaysCache() async {
    await _ensureInitialized();
    await _runwaysBox.clear();
    await _metadataBox.delete(_runwaysLastFetchKey);
  }

  /// Clear navaids cache
  Future<void> clearNavaidsCache() async {
    await _ensureInitialized();
    await _navaidsBox.clear();
    await _metadataBox.delete(_navaidsLastFetchKey);
  }

  /// Clear weather cache
  Future<void> clearWeatherCache() async {
    await _ensureInitialized();
    await _weatherBox.clear();
    await _metadataBox.delete(_weatherLastFetchKey);
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await _ensureInitialized();
    await _airportsBox.clear();
    await _navaidsBox.clear();
    await _runwaysBox.clear();
    await _metadataBox.clear();
    await _weatherBox.clear();
    print('🗑️ All caches cleared');
  }
}
