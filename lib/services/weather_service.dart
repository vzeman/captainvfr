import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
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
  Map<String, DateTime> _metarTimestamps = {}; // Track when each METAR was fetched
  Map<String, DateTime> _tafTimestamps = {}; // Track when each TAF was fetched
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

  /// Fetch weather data ONLY for airports currently visible on the map
  /// This method is optimized to minimize network requests and only load weather
  /// for airports that are actually displayed to the user
  Future<Map<String, String>> getMetarsForAirports(List<String> icaoCodes) async {
    if (icaoCodes.isEmpty) {
      _logger.d('🚫 No airports provided for weather fetch - skipping');
      return {};
    }

    // Limit the number of airports to prevent excessive API calls
    const maxVisibleAirports = 50; // Reasonable limit for map display
    if (icaoCodes.length > maxVisibleAirports) {
      _logger.w('⚠️ Too many airports requested (${icaoCodes.length}), limiting to $maxVisibleAirports');
      icaoCodes = icaoCodes.take(maxVisibleAirports).toList();
    }

    final results = <String, String>{};
    final expiredCodes = <String>[];
    final now = DateTime.now();

    _logger.d('🔍 Checking weather cache for ${icaoCodes.length} visible airports');

    // Check each airport individually for expired weather data (15 minutes)
    for (final icao in icaoCodes) {
      final icaoUpper = icao.toUpperCase();
      final cachedMetar = _metarCache[icaoUpper];
      final timestamp = _metarTimestamps[icaoUpper];

      if (cachedMetar != null && timestamp != null) {
        final age = now.difference(timestamp);
        if (age < const Duration(minutes: 15)) {
          // Weather data is still fresh, use cached version
          results[icao] = cachedMetar;
          continue;
        } else {
          _logger.d('🕒 METAR for $icao is ${age.inMinutes} minutes old - needs refresh');
        }
      }

      // Weather data is missing or expired, needs to be fetched
      expiredCodes.add(icao);
    }

    // If all airports have fresh data, return immediately
    if (expiredCodes.isEmpty) {
      _logger.d('✅ All ${icaoCodes.length} visible airports have fresh weather data (< 15 min)');
      return results;
    }

    _logger.d('🌤️ Need to fetch weather for ${expiredCodes.length}/${icaoCodes.length} visible airports only');

    // Check if we should fetch all data or individual airports
    final shouldFetchAll = _shouldFetchAllWeather();

    if (shouldFetchAll) {
      _logger.d('📡 Fetching all weather data (cache is empty or very old)');
      // Fetch all weather data and update timestamps
      await _fetchAllWeatherIfNeeded();

      // Update timestamps for all fetched data
      final fetchTime = DateTime.now();
      for (final icao in _metarCache.keys) {
        _metarTimestamps[icao] = fetchTime;
      }

      // Get the requested airports from the full cache
      for (final icao in icaoCodes) {
        final metar = getCachedMetar(icao);
        if (metar != null) {
          results[icao] = metar;
        }
      }
    } else {
      _logger.d('🎯 Fetching individual METARs for ${expiredCodes.length} specific airports');
      // Fetch individual airports that are expired
      for (final icao in expiredCodes) {
        try {
          final metar = await _fetchIndividualMetar(icao);
          if (metar != null) {
            final icaoUpper = icao.toUpperCase();
            _metarCache[icaoUpper] = metar;
            _metarTimestamps[icaoUpper] = now;
            results[icao] = metar;
            _logger.d('✅ Updated METAR for visible airport: $icao');
          } else {
            _logger.w('❌ No METAR available for visible airport: $icao');
          }
        } catch (e) {
          _logger.w('⚠️ Failed to fetch individual METAR for visible airport $icao: $e');
        }
      }
    }

    _logger.d('🌤️ Returning weather data for ${results.length}/${icaoCodes.length} visible airports');
    return results;
  }

  /// Check if we should fetch all weather data
  bool _shouldFetchAllWeather() {
    if (_metarCache.isEmpty || _lastFetch == null) {
      return true;
    }

    final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
    return timeSinceLastFetch >= const Duration(minutes: 15);
  }

  /// Fetch individual METAR for a specific airport
  Future<String?> _fetchIndividualMetar(String icaoCode) async {
    try {
      final url = 'https://aviationweather.gov/cgi-bin/json/MetarJSON.php?ids=$icaoCode';
      final response = await _client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData is List && jsonData.isNotEmpty) {
          final metarData = jsonData.first;
          if (metarData['rawOb'] != null) {
            _logger.d('✅ Fetched individual METAR for $icaoCode');
            return metarData['rawOb'] as String;
          }
        }
      }

      _logger.w('⚠️ No METAR data found for $icaoCode');
      return null;
    } catch (e) {
      _logger.e('❌ Error fetching individual METAR for $icaoCode', error: e);
      return null;
    }
  }

  /// Get TAFs for specific airports with 15-minute caching per airport
  Future<Map<String, String>> getTafsForAirports(List<String> icaoCodes) async {
    if (icaoCodes.isEmpty) return {};

    final results = <String, String>{};
    final expiredCodes = <String>[];
    final now = DateTime.now();

    // Check each airport individually for expired TAF data (15 minutes)
    for (final icao in icaoCodes) {
      final icaoUpper = icao.toUpperCase();
      final cachedTaf = _tafCache[icaoUpper];
      final timestamp = _tafTimestamps[icaoUpper];

      if (cachedTaf != null && timestamp != null) {
        final age = now.difference(timestamp);
        if (age < const Duration(minutes: 15)) {
          // TAF data is still fresh, use cached version
          results[icao] = cachedTaf;
          continue;
        }
      }

      // TAF data is missing or expired, needs to be fetched
      expiredCodes.add(icao);
    }

    // If all airports have fresh data, return immediately
    if (expiredCodes.isEmpty) {
      _logger.d('🕒 All ${icaoCodes.length} airports have fresh TAF data (< 15 min)');
      return results;
    }

    _logger.d('🌤️ Need to fetch TAFs for ${expiredCodes.length}/${icaoCodes.length} airports');

    final shouldFetchAll = _shouldFetchAllWeather();

    if (shouldFetchAll) {
      // Fetch all weather data and update timestamps
      await _fetchAllWeatherIfNeeded();

      // Update timestamps for all fetched TAF data
      final fetchTime = DateTime.now();
      for (final icao in _tafCache.keys) {
        _tafTimestamps[icao] = fetchTime;
      }

      // Get the requested airports from the full cache
      for (final icao in icaoCodes) {
        final taf = getCachedTaf(icao);
        if (taf != null) {
          results[icao] = taf;
        }
      }
    } else {
      // Fetch individual TAFs that are expired
      for (final icao in expiredCodes) {
        try {
          final taf = await _fetchIndividualTaf(icao);
          if (taf != null) {
            final icaoUpper = icao.toUpperCase();
            _tafCache[icaoUpper] = taf;
            _tafTimestamps[icaoUpper] = now;
            results[icao] = taf;
          }
        } catch (e) {
          _logger.w('⚠️ Failed to fetch individual TAF for $icao: $e');
        }
      }
    }

    return results;
  }

  /// Fetch individual TAF for a specific airport
  Future<String?> _fetchIndividualTaf(String icaoCode) async {
    try {
      final url = 'https://aviationweather.gov/cgi-bin/json/TafJSON.php?ids=$icaoCode';
      final response = await _client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData is List && jsonData.isNotEmpty) {
          final tafData = jsonData.first;
          if (tafData['rawTAF'] != null) {
            _logger.d('✅ Fetched individual TAF for $icaoCode');
            return tafData['rawTAF'] as String;
          }
        }
      }

      _logger.w('⚠️ No TAF data found for $icaoCode');
      return null;
    } catch (e) {
      _logger.e('❌ Error fetching individual TAF for $icaoCode', error: e);
      return null;
    }
  }
}
