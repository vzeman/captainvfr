import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import '../models/frequency.dart';
import 'cache_service.dart';

/// Service to provide frequency data from bundled assets
class BundledFrequencyService {
  List<Frequency> _frequencies = [];
  final Map<String, List<Frequency>> _frequenciesByAirport = {};
  final bool _isLoading = false;
  bool _bundledDataLoaded = false;
  late final CacheService _cacheService;

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
    
    // Try to load bundled data first
    await _loadBundledFrequencies();
    
    // If no bundled data, try cache
    if (!_bundledDataLoaded) {
      await _loadCachedFrequencies();
    }
    
    developer.log(
      '🔧 BundledFrequencyService: Initialization complete, frequencies: ${_frequencies.length}',
    );
  }

  /// Load frequencies from bundled assets
  Future<void> _loadBundledFrequencies() async {
    if (_bundledDataLoaded) return;
    
    try {
      developer.log('📦 Loading bundled frequency data...');
      
      // Try to load compressed data first
      try {
        final byteData = await rootBundle.load('assets/data/frequencies_min.json.gz');
        final compressed = byteData.buffer.asUint8List();
        
        List<int> decompressed;
        if (kIsWeb) {
          // Use archive package for web
          decompressed = GZipDecoder().decodeBytes(compressed);
        } else {
          // Use dart:io gzip for native platforms
          decompressed = gzip.decode(compressed);
        }
        
        final jsonString = utf8.decode(decompressed);
        final data = json.decode(jsonString) as Map<String, dynamic>;
        
        if (data['frequencies'] != null) {
          final items = data['frequencies'] as List;
          final frequencies = items.map((item) => _parseMinifiedFrequency(item)).toList();
          
          if (frequencies.isNotEmpty) {
            _frequencies = frequencies;
            
            // Build by-airport map
            _frequenciesByAirport.clear();
            if (data['by_airport'] != null) {
              final byAirport = data['by_airport'] as Map<String, dynamic>;
              for (final entry in byAirport.entries) {
                final airportIdent = entry.key;
                final freqList = (entry.value as List).map((f) => _parseMinifiedFrequency(f)).toList();
                _frequenciesByAirport[airportIdent] = freqList;
              }
            } else {
              // Build map from frequency list
              for (final freq in _frequencies) {
                _frequenciesByAirport.putIfAbsent(freq.airportIdent, () => []).add(freq);
              }
            }
            
            // Also cache them for offline use
            await _cacheService.cacheFrequencies(_frequencies);
            
            developer.log('✅ Loaded ${_frequencies.length} frequencies from bundled data');
            developer.log('✅ Frequencies available for ${_frequenciesByAirport.length} airports');
            _bundledDataLoaded = true;
          }
        }
      } catch (e) {
        developer.log('⚠️ Could not load compressed frequencies: $e');
      }
    } catch (e) {
      developer.log('❌ Error loading bundled frequencies: $e');
    }
  }

  /// Parse minified frequency data
  Frequency _parseMinifiedFrequency(Map<String, dynamic> data) {
    return Frequency(
      id: data['id'] ?? 0,
      airportIdent: data['airport_ident'] ?? '',
      type: data['type'] ?? '',
      description: data['description'],
      frequencyMhz: (data['frequency_mhz'] ?? 0.0).toDouble(),
    );
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

  /// Clear all cached frequency data
  Future<void> clearCache() async {
    await _cacheService.clearFrequenciesCache();
    _frequencies.clear();
    _frequenciesByAirport.clear();
    developer.log('🗑️ Frequency cache cleared');
  }

  /// Compatibility method for old API
  Future<void> fetchFrequencies({bool forceRefresh = false}) async {
    if (forceRefresh || _frequencies.isEmpty) {
      await refreshData();
    }
  }
}