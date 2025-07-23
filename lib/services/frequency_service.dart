import 'dart:async';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/frequency.dart';
import 'cache_service.dart';
import 'tiled_data_loader.dart';
import 'bundled_frequency_service.dart';

class FrequencyService {
  static const String _baseUrl =
      'https://davidmegginson.github.io/ourairports-data';
  static const String _frequenciesUrl = '$_baseUrl/airport-frequencies.csv';

  List<Frequency> _frequencies = [];
  bool _isLoading = false;
  late final CacheService _cacheService;
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  final BundledFrequencyService _bundledService = BundledFrequencyService();
  bool _useTiledData = true;
  bool _useBundledData = false;
  
  // Cache for tiled data
  final Map<String, List<Frequency>> _frequenciesByAirport = {};
  final Set<String> _loadedAreas = {};

  // Singleton pattern
  static final FrequencyService _instance = FrequencyService._internal();
  factory FrequencyService() => _instance;
  FrequencyService._internal() {
    // Use the singleton CacheService instance
    _cacheService = CacheService();
  }

  bool get isLoading => _isLoading || _bundledService.isLoading;
  List<Frequency> get frequencies {
    if (_useTiledData) {
      // Return all frequencies from tiled data cache
      return _frequenciesByAirport.values.expand((frequencies) => frequencies).toList();
    }
    return _useBundledData ? _bundledService.frequencies : List.unmodifiable(_frequencies);
  }

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    developer.log('🔧 FrequencyService: Starting initialization...');
    await _cacheService.initialize();
    developer.log('🔧 FrequencyService: Cache service initialized');
    
    // Check if tiled data is available
    try {
      // Try to load a test tile to see if tiled data exists
      final testFrequencies = await _tiledDataLoader.loadFrequenciesForArea(
        minLat: 40.0,
        maxLat: 50.0,
        minLon: -80.0,
        maxLon: -70.0,
      );
      
      if (testFrequencies.isNotEmpty) {
        developer.log('✅ Using tiled frequency data');
        _useTiledData = true;
        _useBundledData = false;
        return;
      }
    } catch (e) {
      developer.log('ℹ️ Tiled frequency data not available: $e');
    }
    
    // Fall back to bundled data
    _useTiledData = false;
    await _bundledService.initialize();
    
    // If bundled data is available, use it
    if (_bundledService.frequencies.isNotEmpty) {
      developer.log('✅ Using bundled frequency data (${_bundledService.frequencies.length} frequencies)');
      _useBundledData = true;
    } else {
      // Fall back to old method
      _useBundledData = false;
      await _loadCachedFrequencies();
      developer.log(
        '🔧 FrequencyService: Cached frequencies loaded, count: ${_frequencies.length}',
      );
    }
  }

  /// Load frequencies from cache
  Future<void> _loadCachedFrequencies() async {
    try {
      final cachedFrequencies = await _cacheService.getCachedFrequencies();
      developer.log(
        '🔧 FrequencyService: Retrieved ${cachedFrequencies.length} frequencies from cache',
      );
      if (cachedFrequencies.isNotEmpty) {
        _frequencies = cachedFrequencies;
      }
    } catch (e) {
      developer.log('❌ Error loading cached frequencies: $e');
    }
  }
  
  /// Load frequencies for a given map area (for tiled data)
  Future<void> loadFrequenciesForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    if (!_useTiledData) {
      // If not using tiled data, this is a no-op
      return;
    }
    
    // Create area key for tracking
    final areaKey = '${minLat.toStringAsFixed(2)}_${maxLat.toStringAsFixed(2)}_${minLon.toStringAsFixed(2)}_${maxLon.toStringAsFixed(2)}';
    
    // Skip if already loaded
    if (_loadedAreas.contains(areaKey)) {
      return;
    }
    
    try {
      developer.log('📍 Loading frequencies for area: ($minLat, $minLon) to ($maxLat, $maxLon)');
      
      // Load frequencies from tiles
      final frequencies = await _tiledDataLoader.loadFrequenciesForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      // Group by airport
      for (final frequency in frequencies) {
        _frequenciesByAirport.putIfAbsent(frequency.airportIdent, () => []).add(frequency);
      }
      
      _loadedAreas.add(areaKey);
      
      developer.log('✅ Loaded ${frequencies.length} frequencies for area');
    } catch (e) {
      developer.log('❌ Error loading frequencies for area: $e');
    }
  }

  /// Fetch frequencies from remote source
  Future<void> fetchFrequencies({bool forceRefresh = false}) async {
    if (_useBundledData) {
      await _bundledService.fetchFrequencies(forceRefresh: forceRefresh);
      return;
    }
    
    if (_isLoading) return;

    // Check if we need to refresh
    if (!forceRefresh && _frequencies.isNotEmpty) {
      final lastFetch = await _cacheService.getFrequenciesLastFetch();
      if (lastFetch != null) {
        final hoursSinceLastFetch = DateTime.now()
            .difference(lastFetch)
            .inHours;
        if (hoursSinceLastFetch < 24) {
          developer.log('🔄 Frequencies data is recent, skipping fetch');
          return;
        }
      }
    }

    _isLoading = true;

    try {
      developer.log('🌐 Fetching frequencies data from remote source...');

      final response = await http
          .get(Uri.parse(_frequenciesUrl), headers: {'Accept': 'text/csv'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final csvData = response.body;
        final frequencies = await _parseFrequenciesCsv(csvData);

        _frequencies = frequencies;

        // Cache the data
        await _cacheService.cacheFrequencies(frequencies);
        await _cacheService.setFrequenciesLastFetch(DateTime.now());

        developer.log(
          '✅ Successfully fetched and cached ${frequencies.length} frequencies',
        );
      } else {
        throw Exception(
          'Failed to fetch frequencies: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      developer.log('❌ Error fetching frequencies: $e');
      // If we have cached data, continue using it
      if (_frequencies.isEmpty) {
        rethrow;
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Parse CSV data into frequency objects
  Future<List<Frequency>> _parseFrequenciesCsv(String csvData) async {
    final frequencies = <Frequency>[];

    try {
      final lines = csvData.split('\n');

      // Show a few sample data lines
      if (lines.length > 1) {
        final sampleCount = lines.length > 5 ? 5 : lines.length - 1;
        for (int i = 1; i <= sampleCount; i++) {
          developer.log('   Line $i: ${lines[i]}');
        }
      }

      // Skip header row
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          final frequency = Frequency.fromCsv(line);
          frequencies.add(frequency);

        } catch (e) {
          // Skip malformed rows
          developer.log('⚠️ Skipping malformed frequency row at line $i: $e');
          if (i <= 10) {
            developer.log('⚠️ Problematic line: $line');
          }
          continue;
        }
      }

      developer.log('📊 Parsed ${frequencies.length} frequencies from CSV');
      return frequencies;
    } catch (e) {
      developer.log('❌ Error parsing frequencies CSV: $e');
      rethrow;
    }
  }

  /// Get frequencies for a specific airport
  List<Frequency> getFrequenciesForAirport(String airportIdent) {
    if (_useTiledData) {
      // Return from tiled data cache
      return _frequenciesByAirport[airportIdent.toUpperCase()] ?? 
             _frequenciesByAirport[airportIdent] ?? 
             [];
    }
    
    if (_useBundledData) {
      return _bundledService.getFrequenciesForAirport(airportIdent);
    }

    if (_frequencies.isEmpty) {
      return [];
    }


    // Try exact match first
    final exactMatches = _frequencies
        .where((frequency) => frequency.airportIdent == airportIdent)
        .toList();

    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    // Try case-insensitive match
    final caseInsensitiveMatches = _frequencies
        .where(
          (frequency) =>
              frequency.airportIdent.toUpperCase() ==
              airportIdent.toUpperCase(),
        )
        .toList();

    return caseInsensitiveMatches;
  }

  /// Get frequencies for multiple airports
  Map<String, List<Frequency>> getFrequenciesForAirports(
    List<String> airportIdents,
  ) {
    final result = <String, List<Frequency>>{};

    for (final ident in airportIdents) {
      result[ident] = getFrequenciesForAirport(ident);
    }

    return result;
  }

  /// Search frequencies by various criteria
  List<Frequency> searchFrequencies({
    String? airportIdent,
    String? type,
    double? minFrequency,
    double? maxFrequency,
  }) {
    return _frequencies.where((frequency) {
      if (airportIdent != null &&
          !frequency.airportIdent.toUpperCase().contains(
            airportIdent.toUpperCase(),
          )) {
        return false;
      }

      if (type != null &&
          !frequency.type.toUpperCase().contains(type.toUpperCase())) {
        return false;
      }

      if (minFrequency != null && frequency.frequencyMhz < minFrequency) {
        return false;
      }

      if (maxFrequency != null && frequency.frequencyMhz > maxFrequency) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Get all unique frequency types
  List<String> getFrequencyTypes() {
    final types = _frequencies.map((f) => f.type).toSet().toList();
    types.sort();
    return types;
  }

  /// Clear cached frequencies and force fresh data fetch
  Future<void> clearCache() async {
    try {
      developer.log('🧹 Clearing frequency cache...');
      await _cacheService.clearFrequencies();
      _frequencies.clear();
      _frequenciesByAirport.clear();
      _loadedAreas.clear();
      _tiledDataLoader.clearCacheForType('frequencies');
      developer.log('✅ Frequency cache cleared');
    } catch (e) {
      developer.log('❌ Error clearing frequency cache: $e');
    }
  }
}
