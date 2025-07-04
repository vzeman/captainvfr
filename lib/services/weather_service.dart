import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:archive/archive.dart';
import 'cache_service.dart';

/// Service for fetching and managing weather data for airports

class WeatherService {
  static const String _metarUrl = 'https://aviationweather.gov/data/cache/metars.cache.csv.gz';
  static const String _tafUrl = 'https://aviationweather.gov/data/cache/tafs.cache.csv.gz';
  static const Duration cacheDuration = Duration(minutes: 5); // Keep for backwards compatibility

  final _logger = Logger();
  final _client = http.Client();
  final _cacheService = CacheService();

  Map<String, String> _metarCache = {};
  Map<String, String> _tafCache = {};
  final Map<String, DateTime> _metarTimestamps = {}; // Track when each METAR was fetched
  final Map<String, DateTime> _tafTimestamps = {}; // Track when each TAF was fetched
  DateTime? _lastFetch;
  Future<void>? _ongoingFetch;
  bool _isReloading = false; // Prevent multiple simultaneous reloads

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

  /// Fetch all METARs and TAFs if cache is expired (30+ minute cache with graceful degradation)
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

    // Use more aggressive caching - only fetch if data is very old or missing
    if (_metarCache.isNotEmpty && _tafCache.isNotEmpty && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      // Extended cache time to 30 minutes to reduce network requests
      if (timeSinceLastFetch < const Duration(minutes: 30)) {
        _logger.d('🕒 Using cached weather data (${timeSinceLastFetch.inMinutes} minutes old)');
        return;
      }
    }

    // Only fetch if we have no data at all or data is very stale (30+ minutes)
    _logger.d('🌍 Starting weather fetch (cache age: ${_lastFetch != null ? DateTime.now().difference(_lastFetch!).inMinutes : "unknown"} minutes)...');
    _ongoingFetch = _fetchAllWeather();
    try {
      await _ongoingFetch;
    } catch (e) {
      _logger.e('❌ Failed to fetch weather data, using cached data: $e');
      // Continue with cached data even if fetch fails
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

  /// Get METAR for ICAO code - returns cached data immediately and triggers reload if needed
  Future<String?> getMetar(String icaoCode) async {
    final icaoUpper = icaoCode.toUpperCase();

    // First, try to get cached data
    String? cachedMetar = _metarCache[icaoUpper];

    // If no cached data, try loading from persistent storage
    if (cachedMetar == null && _metarCache.isEmpty) {
      await _loadCachedData();
      cachedMetar = _metarCache[icaoUpper];
    }

    // Check if we need to reload data in background
    final shouldReload = _shouldReloadWeatherData(icaoUpper, isMetar: true);

    if (shouldReload && !_isReloading) {
      // Trigger background reload but don't wait for it
      _triggerBackgroundReload();
    }

    // Return cached data immediately (even if invalid/expired)
    return cachedMetar;
  }

  /// Get TAF for ICAO code - returns cached data immediately and triggers reload if needed
  Future<String?> getTaf(String icaoCode) async {
    final icaoUpper = icaoCode.toUpperCase();

    // First, try to get cached data
    String? cachedTaf = _tafCache[icaoUpper];

    // If no cached data, try loading from persistent storage
    if (cachedTaf == null && _tafCache.isEmpty) {
      await _loadCachedData();
      cachedTaf = _tafCache[icaoUpper];
    }

    // Check if we need to reload data in background
    final shouldReload = _shouldReloadWeatherData(icaoUpper, isMetar: false);

    if (shouldReload && !_isReloading) {
      // Trigger background reload but don't wait for it
      _triggerBackgroundReload();
    }

    // Return cached data immediately (even if invalid/expired)
    return cachedTaf;
  }

  /// Check if weather data should be reloaded
  bool _shouldReloadWeatherData(String icaoCode, {required bool isMetar}) {
    final cache = isMetar ? _metarCache : _tafCache;
    final timestamps = isMetar ? _metarTimestamps : _tafTimestamps;

    // If no data at all, need to reload
    if (cache[icaoCode] == null) {
      return true;
    }

    // If data is invalid, need to reload
    if (_isWeatherDataInvalid(cache[icaoCode]!)) {
      _logger.d('🔄 Weather data for $icaoCode is invalid, triggering reload');
      return true;
    }

    // If data is expired (older than 15 minutes), need to reload
    final timestamp = timestamps[icaoCode];
    if (timestamp != null) {
      final age = DateTime.now().difference(timestamp);
      if (age > const Duration(minutes: 15)) {
        _logger.d('🕒 Weather data for $icaoCode is ${age.inMinutes} minutes old, triggering reload');
        return true;
      }
    } else {
      // No timestamp means data is from persistent cache, likely old
      return true;
    }

    return false;
  }

  /// Check if weather data is invalid
  bool _isWeatherDataInvalid(String weatherData) {
    if (weatherData.trim().isEmpty) return true;

    // Check for common invalid patterns
    if (weatherData.contains('ERROR') ||
        weatherData.contains('INVALID') ||
        weatherData.contains('NO DATA') ||
        weatherData.contains('TIMEOUT')) {
      return true;
    }

    // For METAR: Should start with 4-letter ICAO code followed by date/time
    if (!RegExp(r'^[A-Z]{4}\s+\d{6}Z?').hasMatch(weatherData.trim())) {
      return true;
    }

    return false;
  }

  /// Trigger background reload of weather data
  void _triggerBackgroundReload() {
    if (_isReloading) {
      _logger.d('🔄 Background reload already in progress, skipping');
      return;
    }

    _isReloading = true;
    _logger.d('🔄 Triggering background weather data reload');

    // Start background reload
    _backgroundReload().then((_) {
      _isReloading = false;
      _logger.d('✅ Background weather data reload completed');
    }).catchError((error) {
      _isReloading = false;
      _logger.e('❌ Background weather data reload failed: $error');
    });
  }

  /// Background reload of weather data
  Future<void> _backgroundReload() async {
    try {
      await _fetchAllWeather();

      // Update timestamps for all fetched data
      final fetchTime = DateTime.now();
      for (final icao in _metarCache.keys) {
        _metarTimestamps[icao] = fetchTime;
      }
      for (final icao in _tafCache.keys) {
        _tafTimestamps[icao] = fetchTime;
      }

    } catch (e, st) {
      _logger.e('❌ Error in background weather reload', error: e, stackTrace: st);
    }
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
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return {
      'metars': _metarCache.length,
      'tafs': _tafCache.length,
      'lastFetch': _lastFetch,
    };
  }

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

  /// Fetch weather data ONLY from cached/bulk data - NO individual API requests
  /// This method is optimized to minimize network requests and serve from local memory
  Future<Map<String, String>> getMetarsForAirports(List<String> icaoCodes) async {
    if (icaoCodes.isEmpty) {
      _logger.d('🚫 No airports provided for weather fetch - skipping');
      return {};
    }

    _logger.d('🔍 Getting METARs for ${icaoCodes.length} airports from cache');

    // Load from persistent cache if in-memory cache is empty
    if (_metarCache.isEmpty) {
      await _loadCachedData();
    }

    // Trigger bulk data refresh in background if needed (but don't wait for it)
    await _fetchAllWeatherIfNeeded();

    final results = <String, String>{};

    // Get data from cache for all requested airports
    for (final icao in icaoCodes) {
      final icaoUpper = icao.toUpperCase();
      final cachedMetar = _metarCache[icaoUpper];

      if (cachedMetar != null) {
        results[icao] = cachedMetar;
      }
    }

    _logger.d('🌤️ Returning ${results.length}/${icaoCodes.length} METARs from cache');
    return results;
  }

  /// Get TAFs for specific airports - ONLY from cached/bulk data
  Future<Map<String, String>> getTafsForAirports(List<String> icaoCodes) async {
    if (icaoCodes.isEmpty) return {};

    _logger.d('🔍 Getting TAFs for ${icaoCodes.length} airports from cache');

    // Load from persistent cache if in-memory cache is empty
    if (_tafCache.isEmpty) {
      await _loadCachedData();
    }

    // Trigger bulk data refresh in background if needed (but don't wait for it)
    await _fetchAllWeatherIfNeeded();

    final results = <String, String>{};

    // Get data from cache for all requested airports
    for (final icao in icaoCodes) {
      final icaoUpper = icao.toUpperCase();
      final cachedTaf = _tafCache[icaoUpper];

      if (cachedTaf != null) {
        results[icao] = cachedTaf;
      }
    }

    _logger.d('🌤️ Returning ${results.length}/${icaoCodes.length} TAFs from cache');
    return results;
  }
}
