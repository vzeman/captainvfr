import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';
import '../models/navaid.dart';
import '../models/runway.dart';
import '../models/frequency.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';

/// Cache service for storing airports, navaids, runways, frequencies, airspaces, and reporting points locally
class CacheService extends ChangeNotifier {
  static const String _airportsBoxName = 'airports_cache';
  static const String _navaidsBoxName = 'navaids_cache';
  static const String _runwaysBoxName = 'runways_cache';
  static const String _frequenciesBoxName = 'frequencies_cache';
  static const String _airspacesBoxName = 'airspaces_cache';
  static const String _reportingPointsBoxName = 'reporting_points_cache';
  static const String _metadataBoxName = 'cache_metadata';
  static const String _weatherBoxName = 'weather_cache';

  static const String _airportsLastFetchKey = 'airports_last_fetch';
  static const String _navaidsLastFetchKey = 'navaids_last_fetch';
  static const String _runwaysLastFetchKey = 'runways_last_fetch';
  static const String _frequenciesLastFetchKey = 'frequencies_last_fetch';
  static const String _airspacesLastFetchKey = 'airspaces_last_fetch';
  static const String _reportingPointsLastFetchKey = 'reporting_points_last_fetch';
  static const String _weatherLastFetchKey = 'weather_last_fetch';

  late Box<Map> _airportsBox;
  late Box<Map> _navaidsBox;
  late Box<Map> _runwaysBox;
  late Box<Map> _frequenciesBox;
  late Box<Map> _airspacesBox;
  late Box<Map> _reportingPointsBox;
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
      _frequenciesBox = await Hive.openBox<Map>(_frequenciesBoxName);
      _airspacesBox = await Hive.openBox<Map>(_airspacesBoxName);
      _reportingPointsBox = await Hive.openBox<Map>(_reportingPointsBoxName);
      _metadataBox = await Hive.openBox(_metadataBoxName);
      _weatherBox = await Hive.openBox<String>(_weatherBoxName);

      _isInitialized = true;
      developer.log('✅ Cache service initialized');
    } catch (e) {
      developer.log('❌ Error initializing cache service: $e');
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }

    // Check if boxes are still open, and reopen them if they've been closed
    try {
      // Test if boxes are accessible by checking if they're open
      if (!_airportsBox.isOpen) {
        developer.log('🔄 Airports box was closed, reopening...');
        _airportsBox = await Hive.openBox<Map>(_airportsBoxName);
      }
      if (!_navaidsBox.isOpen) {
        developer.log('🔄 Navaids box was closed, reopening...');
        _navaidsBox = await Hive.openBox<Map>(_navaidsBoxName);
      }
      if (!_runwaysBox.isOpen) {
        developer.log('🔄 Runways box was closed, reopening...');
        _runwaysBox = await Hive.openBox<Map>(_runwaysBoxName);
      }
      if (!_frequenciesBox.isOpen) {
        developer.log('🔄 Frequencies box was closed, reopening...');
        _frequenciesBox = await Hive.openBox<Map>(_frequenciesBoxName);
      }
      if (!_airspacesBox.isOpen) {
        developer.log('🔄 Airspaces box was closed, reopening...');
        _airspacesBox = await Hive.openBox<Map>(_airspacesBoxName);
      }
      if (!_reportingPointsBox.isOpen) {
        developer.log('🔄 Reporting points box was closed, reopening...');
        _reportingPointsBox = await Hive.openBox<Map>(_reportingPointsBoxName);
      }
      if (!_metadataBox.isOpen) {
        developer.log('🔄 Metadata box was closed, reopening...');
        _metadataBox = await Hive.openBox(_metadataBoxName);
      }
      if (!_weatherBox.isOpen) {
        developer.log('🔄 Weather box was closed, reopening...');
        _weatherBox = await Hive.openBox<String>(_weatherBoxName);
      }
    } catch (e) {
      developer.log('❌ Error checking/reopening boxes: $e');
      // If there's an error, reinitialize completely
      _isInitialized = false;
      await initialize();
    }
  }

  /// Cache airports data
  Future<void> cacheAirports(List<Airport> airports) async {
    await _ensureInitialized();

    try {
      developer.log('💾 Caching ${airports.length} airports...');

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

      developer.log('✅ Cached ${airports.length} airports successfully');
    } catch (e) {
      developer.log('❌ Error caching airports: $e');
      rethrow;
    }
  }

  /// Cache runways data
  Future<void> cacheRunways(List<Runway> runways) async {
    await _ensureInitialized();

    try {
      developer.log('💾 Caching ${runways.length} runways...');

      // Clear existing data
      await _runwaysBox.clear();

      // Cache runways as maps
      for (final runway in runways) {
        await _runwaysBox.put('${runway.id}', runway.toMap());
      }

      // Update last fetch timestamp
      await _metadataBox.put(_runwaysLastFetchKey, DateTime.now().toIso8601String());

      developer.log('✅ Cached ${runways.length} runways successfully');
    } catch (e) {
      developer.log('❌ Error caching runways: $e');
      rethrow;
    }
  }

  /// Cache navaids data
  Future<void> cacheNavaids(List<Navaid> navaids) async {
    await _ensureInitialized();

    try {
      developer.log('💾 Caching ${navaids.length} navaids...');

      // Clear existing data
      await _navaidsBox.clear();

      // Cache navaids as maps
      for (final navaid in navaids) {
        await _navaidsBox.put('${navaid.id}', navaid.toMap());
      }

      // Update last fetch timestamp
      await _metadataBox.put(_navaidsLastFetchKey, DateTime.now().toIso8601String());

      developer.log('✅ Cached ${navaids.length} navaids successfully');
    } catch (e) {
      developer.log('❌ Error caching navaids: $e');
      rethrow;
    }
  }

  /// Cache frequencies data
  Future<void> cacheFrequencies(List<Frequency> frequencies) async {
    await _ensureInitialized();

    try {
      developer.log('💾 Caching ${frequencies.length} frequencies...');

      // Clear existing data
      await _frequenciesBox.clear();

      // Cache frequencies as maps
      for (final frequency in frequencies) {
        await _frequenciesBox.put(frequency.id, frequency.toMap());
      }

      // Update last fetch timestamp
      await _metadataBox.put(_frequenciesLastFetchKey, DateTime.now().toIso8601String());

      developer.log('✅ Cached ${frequencies.length} frequencies successfully');
    } catch (e) {
      developer.log('❌ Error caching frequencies: $e');
      rethrow;
    }
  }

  /// Cache airspaces data (replaces all existing data)
  Future<void> cacheAirspaces(List<Airspace> airspaces) async {
    await _ensureInitialized();

    try {
      developer.log('💾 Caching ${airspaces.length} airspaces (replacing all)...');
      developer.log('📊 Current box status: isOpen=${_airspacesBox.isOpen}, length=${_airspacesBox.length}');

      // Clear existing data
      await _airspacesBox.clear();
      developer.log('✅ Cleared existing airspaces');

      // Cache airspaces as maps
      int cached = 0;
      for (final airspace in airspaces) {
        try {
          final json = airspace.toJson();
          await _airspacesBox.put(airspace.id, json);
          cached++;
        } catch (e) {
          developer.log('⚠️ Error caching airspace ${airspace.id}: $e');
        }
      }

      // Update last fetch timestamp
      await _metadataBox.put(_airspacesLastFetchKey, DateTime.now().toIso8601String());

      developer.log('✅ Cached $cached/${airspaces.length} airspaces successfully');
      developer.log('📊 Final box status: isOpen=${_airspacesBox.isOpen}, length=${_airspacesBox.length}');
      
      // Notify listeners about data change
      notifyListeners();
    } catch (e) {
      developer.log('❌ Error caching airspaces: $e');
      developer.log('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Append airspaces data (adds to existing data without clearing)
  Future<void> appendAirspaces(List<Airspace> airspaces) async {
    await _ensureInitialized();

    try {
      developer.log('💾 Appending ${airspaces.length} airspaces to cache...');
      developer.log('📊 Current box status: isOpen=${_airspacesBox.isOpen}, length=${_airspacesBox.length}');

      // Cache airspaces as maps without clearing
      int cached = 0;
      int updated = 0;
      Set<String> uniqueIds = {};
      
      for (final airspace in airspaces) {
        try {
          final json = airspace.toJson();
          final exists = _airspacesBox.containsKey(airspace.id);
          
          // Check for duplicate IDs in this batch
          if (uniqueIds.contains(airspace.id)) {
            developer.log('⚠️ Duplicate airspace ID found in batch: ${airspace.id}');
          }
          uniqueIds.add(airspace.id);
          
          await _airspacesBox.put(airspace.id, json);
          if (exists) {
            updated++;
            developer.log('📝 Updated existing airspace: ${airspace.id}');
          } else {
            cached++;
          }
        } catch (e) {
          developer.log('⚠️ Error caching airspace ${airspace.id}: $e');
        }
      }

      // Update last fetch timestamp
      await _metadataBox.put(_airspacesLastFetchKey, DateTime.now().toIso8601String());

      developer.log('✅ Added $cached new airspaces, updated $updated existing ones');
      developer.log('📊 Final box status: isOpen=${_airspacesBox.isOpen}, length=${_airspacesBox.length}');
      
      // Notify listeners about data change
      notifyListeners();
    } catch (e) {
      developer.log('❌ Error appending airspaces: $e');
      developer.log('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Cache weather data
  Future<void> cacheWeather(String icao, String weatherData) async {
    await _ensureInitialized();

    try {
      await _weatherBox.put(icao, weatherData);
    } catch (e) {
      developer.log('❌ Error caching weather data for $icao: $e');
      rethrow;
    }
  }

  /// Cache bulk weather data (METARs and TAFs)
  Future<void> cacheWeatherBulk(Map<String, String> metars, Map<String, String> tafs) async {
    await _ensureInitialized();

    try {
      developer.log('💾 Caching ${metars.length} METARs and ${tafs.length} TAFs...');

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

      developer.log('✅ Cached ${metars.length} METARs and ${tafs.length} TAFs successfully');
    } catch (e) {
      developer.log('❌ Error caching weather data: $e');
      rethrow;
    }
  }

  /// Get cached METAR data
  Future<String?> getCachedMetar(String icao) async {
    await _ensureInitialized();

    try {
      return _weatherBox.get('METAR_${icao.toUpperCase()}');
    } catch (e) {
      developer.log('❌ Error loading cached METAR for $icao: $e');
      return null;
    }
  }

  /// Get cached TAF data
  Future<String?> getCachedTaf(String icao) async {
    await _ensureInitialized();

    try {
      return _weatherBox.get('TAF_${icao.toUpperCase()}');
    } catch (e) {
      developer.log('❌ Error loading cached TAF for $icao: $e');
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
      developer.log('❌ Error loading cached METARs: $e');
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
      developer.log('❌ Error loading cached TAFs: $e');
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
      developer.log('❌ Error loading cached airports: $e');
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
      developer.log('❌ Error loading cached runways: $e');
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
      developer.log('❌ Error loading cached navaids: $e');
      return [];
    }
  }

  /// Get cached frequencies
  Future<List<Frequency>> getCachedFrequencies() async {
    await _ensureInitialized();

    try {
      final frequencies = <Frequency>[];

      for (final key in _frequenciesBox.keys) {
        final data = _frequenciesBox.get(key);
        if (data != null) {
          final frequency = Frequency.fromMap(Map<String, dynamic>.from(data));
          frequencies.add(frequency);
        }
      }

      return frequencies;
    } catch (e) {
      developer.log('❌ Error loading cached frequencies: $e');
      return [];
    }
  }

  /// Get cached airspaces
  Future<List<Airspace>> getCachedAirspaces() async {
    await _ensureInitialized();

    try {
      developer.log('📊 Airspaces box info: isOpen=${_airspacesBox.isOpen}, length=${_airspacesBox.length}');
      
      final airspaces = <Airspace>[];

      for (final key in _airspacesBox.keys) {
        final data = _airspacesBox.get(key);
        if (data != null) {
          try {
            final airspace = Airspace.fromJson(Map<String, dynamic>.from(data));
            airspaces.add(airspace);
          } catch (e) {
            developer.log('⚠️ Error parsing airspace with key $key: $e');
          }
        }
      }

      developer.log('✅ Loaded ${airspaces.length} airspaces from cache');
      return airspaces;
    } catch (e) {
      developer.log('❌ Error loading cached airspaces: $e');
      developer.log('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Cache reporting points data (replaces all existing data)
  Future<void> cacheReportingPoints(List<ReportingPoint> reportingPoints) async {
    await _ensureInitialized();

    try {
      developer.log('💾 Caching ${reportingPoints.length} reporting points (replacing all)...');

      // Clear existing data
      await _reportingPointsBox.clear();

      // Cache reporting points as maps
      for (final point in reportingPoints) {
        await _reportingPointsBox.put(point.id, point.toJson());
      }

      // Update last fetch timestamp
      await _metadataBox.put(_reportingPointsLastFetchKey, DateTime.now().toIso8601String());
      
      // iOS-specific: Force flush to disk
      if (Platform.isIOS) {
        await _reportingPointsBox.flush();
        await _metadataBox.flush();
        developer.log('🍎 iOS: Forced flush after caching ${reportingPoints.length} reporting points');
      }

      developer.log('✅ Cached ${reportingPoints.length} reporting points');
      
      // Notify listeners about data change
      notifyListeners();
    } catch (e) {
      developer.log('❌ Error caching reporting points: $e');
      rethrow;
    }
  }

  /// Append reporting points data (adds to existing data without clearing)
  Future<void> appendReportingPoints(List<ReportingPoint> reportingPoints) async {
    await _ensureInitialized();

    try {
      developer.log('💾 Appending ${reportingPoints.length} reporting points to cache...');
      developer.log('📊 Current box status: isOpen=${_reportingPointsBox.isOpen}, length=${_reportingPointsBox.length}');

      // Cache reporting points as maps without clearing
      int cached = 0;
      int updated = 0;
      for (final point in reportingPoints) {
        try {
          final exists = _reportingPointsBox.containsKey(point.id);
          await _reportingPointsBox.put(point.id, point.toJson());
          if (exists) {
            updated++;
          } else {
            cached++;
          }
        } catch (e) {
          developer.log('⚠️ Error caching reporting point ${point.id}: $e');
        }
      }

      // Update last fetch timestamp
      await _metadataBox.put(_reportingPointsLastFetchKey, DateTime.now().toIso8601String());
      
      // iOS-specific: Force flush to disk
      if (Platform.isIOS) {
        await _reportingPointsBox.flush();
        await _metadataBox.flush();
        developer.log('🍎 iOS: Forced flush of reporting points to disk');
      }

      developer.log('✅ Added $cached new reporting points, updated $updated existing ones');
      developer.log('📊 Final box status: isOpen=${_reportingPointsBox.isOpen}, length=${_reportingPointsBox.length}');
      
      // Notify listeners about data change
      notifyListeners();
    } catch (e) {
      developer.log('❌ Error appending reporting points: $e');
      developer.log('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Get cached reporting points
  Future<List<ReportingPoint>> getCachedReportingPoints() async {
    await _ensureInitialized();

    try {
      // Add iOS-specific debugging
      if (Platform.isIOS) {
        developer.log('🍎 iOS: Getting reporting points - Box isOpen: ${_reportingPointsBox.isOpen}, isEmpty: ${_reportingPointsBox.isEmpty}, length: ${_reportingPointsBox.length}');
        if (_reportingPointsBox.path != null) {
          developer.log('🍎 iOS: Box path: ${_reportingPointsBox.path}');
        }
      }
      
      final reportingPoints = <ReportingPoint>[];

      for (final key in _reportingPointsBox.keys) {
        final data = _reportingPointsBox.get(key);
        if (data != null) {
          final point = ReportingPoint.fromJson(Map<String, dynamic>.from(data));
          reportingPoints.add(point);
        }
      }
      
      if (Platform.isIOS && reportingPoints.isEmpty && _reportingPointsBox.isNotEmpty) {
        developer.log('🍎 iOS: WARNING - Box has ${_reportingPointsBox.length} entries but parsed 0 points!');
      }

      return reportingPoints;
    } catch (e) {
      developer.log('❌ Error loading cached reporting points: $e');
      if (Platform.isIOS) {
        developer.log('🍎 iOS: Stack trace: ${StackTrace.current}');
      }
      return [];
    }
  }

  /// Get cached weather data
  Future<String?> getCachedWeather(String icao) async {
    await _ensureInitialized();

    try {
      return _weatherBox.get(icao);
    } catch (e) {
      developer.log('❌ Error loading cached weather data for $icao: $e');
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

  /// Get frequencies last fetch timestamp
  Future<DateTime?> getFrequenciesLastFetch() async {
    await _ensureInitialized();
    final timestampStr = _metadataBox.get(_frequenciesLastFetchKey);
    if (timestampStr != null) {
      return DateTime.tryParse(timestampStr);
    }
    return null;
  }

  /// Get airspaces last fetch timestamp
  Future<DateTime?> getAirspacesLastFetch() async {
    await _ensureInitialized();
    final timestampStr = _metadataBox.get(_airspacesLastFetchKey);
    if (timestampStr != null) {
      return DateTime.tryParse(timestampStr);
    }
    return null;
  }

  /// Get reporting points last fetch timestamp
  Future<DateTime?> getReportingPointsLastFetch() async {
    await _ensureInitialized();
    final timestampStr = _metadataBox.get(_reportingPointsLastFetchKey);
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

  /// Set frequencies last fetch timestamp
  Future<void> setFrequenciesLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _metadataBox.put(_frequenciesLastFetchKey, timestamp.toIso8601String());
  }

  /// Set airspaces last fetch timestamp
  Future<void> setAirspacesLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _metadataBox.put(_airspacesLastFetchKey, timestamp.toIso8601String());
  }

  /// Set weather last fetch timestamp
  Future<void> setWeatherLastFetch(DateTime timestamp) async {
    await _ensureInitialized();
    await _metadataBox.put(_weatherLastFetchKey, timestamp.toIso8601String());
  }

  /// Clear airports cache
  Future<void> clearAirportsCache() async {
    await _ensureInitialized();
    await _airportsBox.clear();
    await _metadataBox.delete(_airportsLastFetchKey);
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

  /// Clear frequencies cache
  Future<void> clearFrequenciesCache() async {
    await _ensureInitialized();
    await _frequenciesBox.clear();
    await _metadataBox.delete(_frequenciesLastFetchKey);
  }

  /// Clear airspaces cache
  Future<void> clearAirspacesCache() async {
    await _ensureInitialized();
    developer.log('🗑️ Clearing airspaces cache - current count: ${_airspacesBox.length}');
    await _airspacesBox.clear();
    await _metadataBox.delete(_airspacesLastFetchKey);
    developer.log('✅ Airspaces cache cleared - new count: ${_airspacesBox.length}');
  }

  /// Clear reporting points cache
  Future<void> clearReportingPointsCache() async {
    await _ensureInitialized();
    await _reportingPointsBox.clear();
    await _metadataBox.delete(_reportingPointsLastFetchKey);
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
    await _frequenciesBox.clear();
    await _airspacesBox.clear();
    await _reportingPointsBox.clear();
    await _metadataBox.clear();
    await _weatherBox.clear();
    developer.log('🗑️ All caches cleared');
  }

  /// Clear all cached frequencies
  Future<void> clearFrequencies() async {
    try {
      await _frequenciesBox.clear();
      await _metadataBox.delete(_frequenciesLastFetchKey);
      developer.log('✅ Cleared all cached frequencies');
    } catch (e) {
      developer.log('❌ Error clearing frequencies cache: $e');
      rethrow;
    }
  }
}
