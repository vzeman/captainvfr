import 'dart:async';
import 'dart:developer' as developer;
import '../models/frequency.dart';
import 'cache_service.dart';
import 'tiled_data_loader.dart';

/// Service to provide frequency data from bundled assets
class BundledFrequencyService {
  List<Frequency> _frequencies = [];
  final Map<String, List<Frequency>> _frequenciesByAirport = {};
  final bool _isLoading = false;
  bool _bundledDataLoaded = false;
  late final CacheService _cacheService;
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  bool _useTiledData = false;
  final Set<String> _loadedAreas = {};

  // Singleton pattern
  static final BundledFrequencyService _instance = BundledFrequencyService._internal();
  factory BundledFrequencyService() => _instance;
  BundledFrequencyService._internal() {
    _cacheService = CacheService();
  }

  bool get isLoading => _isLoading;
  List<Frequency> get frequencies => List.unmodifiable(_frequencies);

  /// Initialize the service and load bundled data
  Future<void> initialize() async {
    developer.log('🔧 BundledFrequencyService: Starting initialization...');
    await _cacheService.initialize();
    developer.log('🔧 BundledFrequencyService: Cache service initialized');
    
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
        _bundledDataLoaded = true;
        return;
      }
    } catch (e) {
      developer.log('ℹ️ Tiled frequency data not available: $e');
    }
    
    // Fall back to cached data
    _useTiledData = false;
    await _loadCachedFrequencies();
    
    developer.log(
      '🔧 BundledFrequencyService: Initialization complete, frequencies: ${_frequencies.length}',
    );
  }

  /// Load frequencies from bundled assets
  Future<void> _loadBundledFrequencies() async {
    if (_bundledDataLoaded) return;
    
    try {
      developer.log('📦 Loading bundled frequency data...');
      
      // TODO: Implement tiled frequency loading when frequencies tiles are available
      // For now, frequencies will be loaded from cache only
      developer.log('ℹ️ Frequency tiles not yet available, using cache only');
      _bundledDataLoaded = true;
      
    } catch (e) {
      developer.log('❌ Error loading bundled frequencies: $e');
    }
  }


  /// Load frequencies from cache
  Future<void> _loadCachedFrequencies() async {
    try {
      final cachedFrequencies = await _cacheService.getCachedFrequencies();
      developer.log(
        '🔧 BundledFrequencyService: Retrieved ${cachedFrequencies.length} frequencies from cache',
      );
      if (cachedFrequencies.isNotEmpty) {
        _frequencies = cachedFrequencies;
        _rebuildByAirportMap();
      }
    } catch (e) {
      developer.log('❌ Error loading cached frequencies: $e');
    }
  }

  /// Rebuild the by-airport map from the frequency list
  void _rebuildByAirportMap() {
    _frequenciesByAirport.clear();
    for (final freq in _frequencies) {
      _frequenciesByAirport.putIfAbsent(freq.airportIdent, () => []).add(freq);
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
    
    // Use the pre-built map for O(1) lookup
    return _frequenciesByAirport[airportIdent.toUpperCase()] ?? 
           _frequenciesByAirport[airportIdent] ?? 
           [];
  }

  /// Get frequencies for multiple airports
  Map<String, List<Frequency>> getFrequenciesForAirports(List<String> airportIdents) {
    final result = <String, List<Frequency>>{};
    
    for (final ident in airportIdents) {
      final freqs = getFrequenciesForAirport(ident);
      if (freqs.isNotEmpty) {
        result[ident] = freqs;
      }
    }
    
    return result;
  }

  /// Search frequencies by various criteria
  List<Frequency> searchFrequencies({
    String? airportIdent,
    String? type,
    String? description,
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
          !frequency.type.toLowerCase().contains(type.toLowerCase())) {
        return false;
      }

      if (description != null &&
          frequency.description != null &&
          !frequency.description!.toLowerCase().contains(
            description.toLowerCase(),
          )) {
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

  /// Force refresh from bundled data
  Future<void> refreshData() async {
    _bundledDataLoaded = false;
    await _loadBundledFrequencies();
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
  
  /// Clear all cached frequency data
  Future<void> clearCache() async {
    await _cacheService.clearFrequenciesCache();
    _frequencies.clear();
    _frequenciesByAirport.clear();
    _loadedAreas.clear();
    _tiledDataLoader.clearCacheForType('frequencies');
    developer.log('🗑️ Frequency cache cleared');
  }

  /// Compatibility method for old API
  Future<void> fetchFrequencies({bool forceRefresh = false}) async {
    if (forceRefresh || _frequencies.isEmpty) {
      await refreshData();
    }
  }
}