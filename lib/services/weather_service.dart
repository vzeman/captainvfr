import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:io';
import 'package:archive/archive.dart';
import 'cache_service.dart';

/// Service for fetching and managing weather data for airports

class WeatherService {
  static const String _baseUrl = 'https://aviationweather.gov/cgi-bin/data';
  static const String _metarUrl = 'https://aviationweather.gov/data/cache/metars.cache.csv.gz';
  static const String _tafUrl = 'https://aviationweather.gov/data/cache/tafs.cache.csv.gz';
  static const Duration cacheDuration = Duration(minutes: 5); // Keep for backwards compatibility

  final _logger = Logger();
  final _client = http.Client();
  final _cacheService = CacheService();

  Map<String, String> _metarCache = {};
  Map<String, String> _tafCache = {};
  DateTime? _lastFetch;
  Future<void>? _ongoingFetch;

  WeatherService();

  /// Initialize the weather service and load cached data
  Future<void> initialize() async {
    await _cacheService.initialize();
    await _loadCachedData();
  }

  /// Load cached weather data from persistent storage
  Future<void> _loadCachedData() async {
    try {
      final cachedMetars = await _cacheService.getCachedMetars();
      final cachedTafs = await _cacheService.getCachedTafs();
      final lastFetch = await _cacheService.getWeatherLastFetch();

      if (cachedMetars.isNotEmpty || cachedTafs.isNotEmpty) {
        _metarCache = cachedMetars;
        _tafCache = cachedTafs;
        _lastFetch = lastFetch;
        _logger.d('📦 Loaded ${cachedMetars.length} METARs and ${cachedTafs.length} TAFs from cache');

        if (lastFetch != null) {
          final age = DateTime.now().difference(lastFetch);
          _logger.d('📅 Cached weather data is ${age.inMinutes} minutes old');
        }
      }
    } catch (e) {
      _logger.w('⚠️ Failed to load cached weather data: $e');
    }
  }

  /// Fetch all METARs and TAFs if cache is expired (15 minute cache)
  Future<void> _fetchAllWeatherIfNeeded() async {
    // If there's already an ongoing fetch, wait for it and return
    if (_ongoingFetch != null) {
      await _ongoingFetch;
      return;
    }

    // Load from persistent cache if in-memory cache is empty
    if (_metarCache.isEmpty && _tafCache.isEmpty) {
      await _loadCachedData();
    }

    // Check if we have data and it's less than 15 minutes old
    if (_metarCache.isNotEmpty && _tafCache.isNotEmpty && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < const Duration(minutes: 15)) {
        _logger.d('🕒 Using cached weather data (${timeSinceLastFetch.inMinutes} minutes old)');
        return;
      }
    }

    // Start fetch and ensure only one happens at a time
    _logger.d('🌍 Starting weather fetch...');
    _ongoingFetch = _fetchAllWeather();
    try {
      await _ongoingFetch;
    } finally {
      _ongoingFetch = null;
    }
  }

  Future<void> _fetchAllWeather() async {
    try {
      _logger.d('🌍 Fetching all METARs and TAFs');
      final metarResp = await _client.get(Uri.parse(_metarUrl));
      final tafResp = await _client.get(Uri.parse(_tafUrl));

      if (metarResp.statusCode == 200) {
        _metarCache = _parseGzCsv(metarResp.bodyBytes, isMetar: true);
        _logger.d('✅ Loaded ${_metarCache.length} METARs');
      }

      if (tafResp.statusCode == 200) {
        _tafCache = _parseGzCsv(tafResp.bodyBytes, isMetar: false);
        _logger.d('✅ Loaded ${_tafCache.length} TAFs');
      }

      _lastFetch = DateTime.now();

      // Save to persistent cache
      await _saveToPersistentCache();

    } catch (e, st) {
      _logger.e('❌ Error fetching global weather', error: e, stackTrace: st);
    }
  }

  /// Save weather data to persistent cache
  Future<void> _saveToPersistentCache() async {
    try {
      await _cacheService.cacheWeatherBulk(_metarCache, _tafCache);
      _logger.d('💾 Saved weather data to persistent cache');
    } catch (e) {
      _logger.w('⚠️ Failed to save weather data to cache: $e');
    }
  }

  Map<String, String> _parseGzCsv(List<int> gzBytes, {required bool isMetar}) {
    try {
      final archive = GZipDecoder().decodeBytes(gzBytes);
      final csv = utf8.decode(archive);
      final lines = csv.split('\n');
      final map = <String, String>{};

      _logger.d('📊 Parsing ${isMetar ? 'METAR' : 'TAF'} CSV with ${lines.length} lines');

      // Skip header lines and find where actual data starts
      int dataStartIndex = 0;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Look for lines that start with 4-letter ICAO codes
        if (RegExp(r'^[A-Z]{4}[\s,]').hasMatch(line)) {
          dataStartIndex = i;
          _logger.d('📍 Found data starting at line $i: ${line.substring(0, math.min(50, line.length))}...');
          break;
        }

        // Log first few lines for debugging
        if (i < 10) {
          _logger.d('Header line $i: $line');
        }
      }

      // Parse actual weather data lines
      for (int i = dataStartIndex; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        String? icao;
        String? weatherText;

        // Try different parsing approaches
        if (line.contains(',')) {
          // CSV format parsing - based on logs, raw_text is the first column
          final parts = line.split(',');
          if (parts.isNotEmpty) {
            // The first column should be the raw_text (weather data)
            final rawText = parts[0].trim().replaceAll('"', '');

            // Extract ICAO from the raw text
            final icaoMatch = RegExp(r'^([A-Z]{4})[\s\d]').firstMatch(rawText);
            if (icaoMatch != null) {
              icao = icaoMatch.group(1);
              weatherText = rawText;
            }
          }
        } else {
          // Single line format - extract ICAO from the beginning
          final match = RegExp(r'^([A-Z]{4})\s+(.+)').firstMatch(line);
          if (match != null) {
            icao = match.group(1);
            weatherText = line; // Use the whole line as weather text
          }
        }

        if (icao != null && weatherText != null && weatherText.isNotEmpty) {
          map[icao.toUpperCase()] = weatherText;
        }
      }

      _logger.d('✅ Parsed ${map.length} ${isMetar ? 'METAR' : 'TAF'} entries');
      if (map.isNotEmpty) {
        final firstEntry = map.entries.first;
        _logger.d('Sample entry: ${firstEntry.key} -> ${firstEntry.value.substring(0, math.min(100, firstEntry.value.length))}...');
      }

      return map;
    } catch (e) {
      _logger.e('❌ Error parsing ${isMetar ? 'METAR' : 'TAF'} CSV', error: e);
      return {};
    }
  }

  /// Get METAR for ICAO code (loads all if needed)
  Future<String?> getMetar(String icaoCode) async {
    await _fetchAllWeatherIfNeeded();
    return _metarCache[icaoCode.toUpperCase()];
  }

  /// Get TAF for ICAO code (loads all if needed)
  Future<String?> getTaf(String icaoCode) async {
    await _fetchAllWeatherIfNeeded();
    return _tafCache[icaoCode.toUpperCase()];
  }

  /// Get cached METAR without fetching
  String? getCachedMetar(String icaoCode) {
    return _metarCache[icaoCode.toUpperCase()];
  }

  /// Get cached TAF without fetching
  String? getCachedTaf(String icaoCode) {
    return _tafCache[icaoCode.toUpperCase()];
  }

  /// Force reload (always reloads regardless of cache state)
  Future<void> forceReload() async {
    if (_ongoingFetch != null) {
      await _ongoingFetch;
    }
    _ongoingFetch = _fetchAllWeather();
    await _ongoingFetch;
    _ongoingFetch = null;
  }

  DateTime? get lastFetch => _lastFetch;

  /// Legacy method for backward compatibility
  Future<String?> fetchMetar(String icaoCode) async {
    return await getMetar(icaoCode);
  }

  /// Legacy method for backward compatibility
  Future<String?> fetchTaf(String icaoCode) async {
    return await getTaf(icaoCode);
  }

  /// Disposes of resources
  void dispose() {
    _client.close();
  }
}
