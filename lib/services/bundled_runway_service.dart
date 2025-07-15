import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import '../models/runway.dart';
import 'cache_service.dart';

/// Service to provide runway data from bundled assets
class BundledRunwayService {
  List<Runway> _runways = [];
  final Map<String, List<Runway>> _runwaysByAirport = {};
  final bool _isLoading = false;
  bool _bundledDataLoaded = false;
  late final CacheService _cacheService;

  // Singleton pattern
  static final BundledRunwayService _instance = BundledRunwayService._internal();
  factory BundledRunwayService() => _instance;
  BundledRunwayService._internal() {
    _cacheService = CacheService();
  }

  bool get isLoading => _isLoading;
  List<Runway> get runways => List.unmodifiable(_runways);

  /// Initialize the service and load bundled data
  Future<void> initialize() async {
    developer.log('🔧 BundledRunwayService: Starting initialization...');
    await _cacheService.initialize();
    developer.log('🔧 BundledRunwayService: Cache service initialized');
    
    // Try to load bundled data first
    await _loadBundledRunways();
    
    // If no bundled data, try cache
    if (!_bundledDataLoaded) {
      await _loadCachedRunways();
    }
    
    developer.log(
      '🔧 BundledRunwayService: Initialization complete, runways: ${_runways.length}',
    );
  }

  /// Load runways from bundled assets
  Future<void> _loadBundledRunways() async {
    if (_bundledDataLoaded) return;
    
    try {
      developer.log('📦 Loading bundled runway data...');
      
      // Try to load compressed data first
      try {
        final byteData = await rootBundle.load('assets/data/runways_min.json.gz');
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
        
        if (data['runways'] != null) {
          final items = data['runways'] as List;
          final runways = items.map((item) => Runway.fromMap(item)).toList();
          
          if (runways.isNotEmpty) {
            _runways = runways;
            
            // Build by-airport map
            _runwaysByAirport.clear();
            if (data['by_airport'] != null) {
              final byAirport = data['by_airport'] as Map<String, dynamic>;
              for (final entry in byAirport.entries) {
                final airportIdent = entry.key;
                final runwayList = (entry.value as List).map((r) => Runway.fromMap(r)).toList();
                _runwaysByAirport[airportIdent] = runwayList;
              }
            } else {
              // Build map from runway list
              for (final runway in _runways) {
                _runwaysByAirport.putIfAbsent(runway.airportIdent, () => []).add(runway);
              }
            }
            
            // Also cache them for offline use
            await _cacheService.cacheRunways(_runways);
            
            developer.log('✅ Loaded ${_runways.length} runways from bundled data');
            developer.log('✅ Runways available for ${_runwaysByAirport.length} airports');
            developer.log('📅 Data generated at: ${data['generated_at']}');
            _bundledDataLoaded = true;
          }
        }
      } catch (e) {
        developer.log('⚠️ Could not load compressed runways: $e');
        
        // Try to load uncompressed data as fallback
        try {
          final jsonString = await rootBundle.loadString('assets/data/runways.json');
          final data = json.decode(jsonString) as Map<String, dynamic>;
          
          if (data['runways'] != null) {
            final items = data['runways'] as List;
            final runways = items.map((item) => Runway.fromMap(item)).toList();
            
            if (runways.isNotEmpty) {
              _runways = runways;
              
              // Build by-airport map
              _runwaysByAirport.clear();
              if (data['by_airport'] != null) {
                final byAirport = data['by_airport'] as Map<String, dynamic>;
                for (final entry in byAirport.entries) {
                  final airportIdent = entry.key;
                  final runwayList = (entry.value as List).map((r) => Runway.fromMap(r)).toList();
                  _runwaysByAirport[airportIdent] = runwayList;
                }
              } else {
                // Build map from runway list
                for (final runway in _runways) {
                  _runwaysByAirport.putIfAbsent(runway.airportIdent, () => []).add(runway);
                }
              }
              
              await _cacheService.cacheRunways(_runways);
              developer.log('✅ Loaded ${_runways.length} runways from bundled JSON');
              developer.log('📅 Data generated at: ${data['generated_at']}');
              _bundledDataLoaded = true;
            }
          }
        } catch (e2) {
          developer.log('⚠️ Could not load uncompressed runways: $e2');
        }
      }
    } catch (e) {
      developer.log('❌ Error loading bundled runways: $e');
    }
  }

  /// Load runways from cache
  Future<void> _loadCachedRunways() async {
    try {
      final cachedRunways = await _cacheService.getCachedRunways();
      developer.log(
        '🔧 BundledRunwayService: Retrieved ${cachedRunways.length} runways from cache',
      );
      if (cachedRunways.isNotEmpty) {
        _runways = cachedRunways;
        _rebuildByAirportMap();
      }
    } catch (e) {
      developer.log('❌ Error loading cached runways: $e');
    }
  }

  /// Rebuild the by-airport map from the runway list
  void _rebuildByAirportMap() {
    _runwaysByAirport.clear();
    for (final runway in _runways) {
      _runwaysByAirport.putIfAbsent(runway.airportIdent, () => []).add(runway);
    }
  }

  /// Get runways for a specific airport
  List<Runway> getRunwaysForAirport(String airportIdent) {
    // Use the pre-built map for O(1) lookup
    return _runwaysByAirport[airportIdent.toUpperCase()] ?? 
           _runwaysByAirport[airportIdent] ?? 
           [];
  }

  /// Get runways for multiple airports
  Map<String, List<Runway>> getRunwaysForAirports(List<String> airportIdents) {
    final result = <String, List<Runway>>{};
    
    for (final ident in airportIdents) {
      final runways = getRunwaysForAirport(ident);
      if (runways.isNotEmpty) {
        result[ident] = runways;
      }
    }
    
    return result;
  }

  /// Search runways by various criteria
  List<Runway> searchRunways({
    String? airportIdent,
    String? surface,
    int? minLength,
    bool? lighted,
    bool? closed,
  }) {
    return _runways.where((runway) {
      if (airportIdent != null &&
          !runway.airportIdent.toUpperCase().contains(
            airportIdent.toUpperCase(),
          )) {
        return false;
      }

      if (surface != null &&
          !runway.surface.toLowerCase().contains(surface.toLowerCase())) {
        return false;
      }

      if (minLength != null && runway.lengthFt < minLength) {
        return false;
      }

      if (lighted != null && runway.lighted != lighted) {
        return false;
      }

      if (closed != null && runway.closed != closed) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Force refresh from bundled data
  Future<void> refreshData() async {
    _bundledDataLoaded = false;
    await _loadBundledRunways();
  }

  /// Clear all cached runway data
  Future<void> clearCache() async {
    await _cacheService.clearRunwaysCache();
    _runways.clear();
    _runwaysByAirport.clear();
    developer.log('🗑️ Runway cache cleared');
  }

  /// Clean up resources
  void dispose() {
    _runways.clear();
    _runwaysByAirport.clear();
  }

  /// Compatibility method for old API
  Future<void> fetchRunways({bool forceRefresh = false}) async {
    if (forceRefresh || _runways.isEmpty) {
      await refreshData();
    }
  }

  /// Force reload runways data
  Future<void> forceReload() async {
    _runways.clear();
    _runwaysByAirport.clear();
    await refreshData();
  }
}