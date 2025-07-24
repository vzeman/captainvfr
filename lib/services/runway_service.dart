import 'dart:async';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/runway.dart';
import '../models/unified_runway.dart';
import '../models/openaip_runway.dart';
import 'cache_service.dart';
import 'bundled_runway_service.dart';
import 'tiled_data_loader.dart';
// import 'openaip_service.dart'; // Reserved for future use

class RunwayService {
  static const String _baseUrl =
      'https://davidmegginson.github.io/ourairports-data';
  static const String _runwaysUrl = '$_baseUrl/runways.csv';

  List<Runway> _runways = [];
  bool _isLoading = false;
  final CacheService _cacheService = CacheService();
  final BundledRunwayService _bundledService = BundledRunwayService();
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  bool _useBundledData = true;
  bool _useTiledData = true;
  
  // Cache for tiled data
  final Map<String, List<Runway>> _runwaysByAirport = {};
  final Map<String, List<UnifiedRunway>> _unifiedRunwaysByAirport = {};
  final Set<String> _loadedAreas = {};
  // OpenAIPService? _openAIPService; // Reserved for future use

  // Singleton pattern
  static final RunwayService _instance = RunwayService._internal();
  factory RunwayService() => _instance;
  RunwayService._internal();

  bool get isLoading => _isLoading || _bundledService.isLoading;
  List<Runway> get runways {
    if (_useTiledData) {
      // Return all runways from tiled data cache
      return _runwaysByAirport.values.expand((runways) => runways).toList();
    }
    return _useBundledData ? _bundledService.runways : List.unmodifiable(_runways);
  }

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    await _cacheService.initialize();
    
    // Reserved for future OpenAIP service integration
    // try {
    //   _openAIPService = OpenAIPService();
    // } catch (e) {
    //   developer.log('OpenAIP service not available: $e');
    // }
    
    // Check if tiled data is available
    try {
      // Try to load a test tile to see if tiled data exists
      final testRunways = await _tiledDataLoader.loadRunwaysForArea(
        minLat: 40.0,
        maxLat: 50.0,
        minLon: -80.0,
        maxLon: -70.0,
      );
      
      if (testRunways.isNotEmpty) {
        developer.log('✅ Using tiled runway data');
        _useTiledData = true;
        _useBundledData = false;
        return;
      }
    } catch (e) {
      developer.log('ℹ️ Tiled runway data not available: $e');
    }
    
    // Fall back to bundled data
    _useTiledData = false;
    await _bundledService.initialize();
    
    // If bundled data is available, use it
    if (_bundledService.runways.isNotEmpty) {
      developer.log('✅ Using bundled runway data (${_bundledService.runways.length} runways)');
      _useBundledData = true;
    } else {
      // Fall back to old method
      _useBundledData = false;
      await _loadCachedRunways();
    }
  }

  /// Load runways from cache
  Future<void> _loadCachedRunways() async {
    try {
      final cachedRunways = await _cacheService.getCachedRunways();
      if (cachedRunways.isNotEmpty) {
        _runways = cachedRunways;
        developer.log('✅ Loaded ${_runways.length} runways from cache');
      }
    } catch (e) {
      developer.log('❌ Error loading cached runways: $e');
    }
  }
  
  /// Load runways for a given map area (for tiled data)
  Future<void> loadRunwaysForArea({
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
      developer.log('📍 Loading runways for area: ($minLat, $minLon) to ($maxLat, $maxLon)');
      
      // Load runways from tiles
      final runways = await _tiledDataLoader.loadRunwaysForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      // Group by airport and prevent duplicates
      for (final runway in runways) {
        final airportRunways = _runwaysByAirport.putIfAbsent(runway.airportIdent, () => []);
        
        // Check if this runway already exists (by ID to avoid duplicates)
        final alreadyExists = airportRunways.any((r) => r.id == runway.id);
        
        // Only add if it's not already in the list
        if (!alreadyExists) {
          airportRunways.add(runway);
        }
      }
      
      _loadedAreas.add(areaKey);
      
      // Log unique airports with runway counts
      final uniqueAirports = <String>{};
      for (final entry in _runwaysByAirport.entries) {
        if (runways.any((r) => r.airportIdent == entry.key)) {
          uniqueAirports.add(entry.key);
        }
      }
      developer.log('✅ Loaded ${runways.length} runways for area, ${uniqueAirports.length} airports updated');
    } catch (e) {
      developer.log('❌ Error loading runways for area: $e');
    }
  }

  /// Fetch runways from remote source
  Future<void> fetchRunways({bool forceRefresh = false}) async {
    if (_useBundledData) {
      await _bundledService.fetchRunways(forceRefresh: forceRefresh);
      return;
    }
    
    if (_isLoading) return;

    // Check if we need to refresh
    if (!forceRefresh && _runways.isNotEmpty) {
      final lastFetch = await _cacheService.getRunwaysLastFetch();
      if (lastFetch != null) {
        final hoursSinceLastFetch = DateTime.now()
            .difference(lastFetch)
            .inHours;
        if (hoursSinceLastFetch < 24) {
          developer.log('🔄 Runways data is recent, skipping fetch');
          return;
        }
      }
    }

    _isLoading = true;

    try {
      developer.log('🌐 Fetching runways data from remote source...');

      final response = await http
          .get(Uri.parse(_runwaysUrl), headers: {'Accept': 'text/csv'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final csvData = response.body;
        final runways = await _parseRunwaysCsv(csvData);

        _runways = runways;

        // Cache the data
        await _cacheService.cacheRunways(runways);
        await _cacheService.setRunwaysLastFetch(DateTime.now());

        developer.log(
          '✅ Successfully fetched and cached ${runways.length} runways',
        );
      } else {
        throw Exception('Failed to fetch runways: HTTP ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Error fetching runways: $e');
      // If we have cached data, continue using it
      if (_runways.isEmpty) {
        rethrow;
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Parse CSV data into runway objects
  Future<List<Runway>> _parseRunwaysCsv(String csvData) async {
    final runways = <Runway>[];

    try {
      final lines = csvData.split('\n');

      // Skip header row
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          final row = _parseCsvRow(line);
          if (row.length >= 20) {
            // Ensure we have all required columns
            final runway = Runway.fromCsvRow(row);
            runways.add(runway);
          }
        } catch (e) {
          // Skip malformed rows
          developer.log('⚠️ Skipping malformed runway row: $e');
          continue;
        }
      }

      developer.log('📊 Parsed ${runways.length} runways from CSV');
      return runways;
    } catch (e) {
      developer.log('❌ Error parsing runways CSV: $e');
      rethrow;
    }
  }

  /// Parse a single CSV row, handling quoted fields
  List<String> _parseCsvRow(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // Add the last field
    fields.add(buffer.toString());

    return fields;
  }

  /// Get runways for a specific airport
  List<Runway> getRunwaysForAirport(String airportIdent, {List<OpenAIPRunway>? openAIPRunways, double? airportLat, double? airportLon}) {
    // Try unified data first
    final unified = getUnifiedRunwaysForAirport(airportIdent, openAIPRunways: openAIPRunways, airportLat: airportLat, airportLon: airportLon);
    if (unified.isNotEmpty) {
      return unified.map((r) => r.toRunway()).toList();
    }
    
    if (_useTiledData) {
      // Return from tiled data cache
      return _runwaysByAirport[airportIdent.toUpperCase()] ?? 
             _runwaysByAirport[airportIdent] ?? 
             [];
    }
    
    if (_useBundledData) {
      return _bundledService.getRunwaysForAirport(airportIdent);
    }
    
    return _runways
        .where(
          (runway) =>
              runway.airportIdent.toUpperCase() == airportIdent.toUpperCase(),
        )
        .toList();
  }
  
  /// Get unified runways combining multiple sources
  List<UnifiedRunway> getUnifiedRunwaysForAirport(String airportIdent, {List<OpenAIPRunway>? openAIPRunways, double? airportLat, double? airportLon}) {
    final upperIdent = airportIdent.toUpperCase();
    
    // Check cache first (only if no OpenAIP data provided)
    if (openAIPRunways == null && _unifiedRunwaysByAirport.containsKey(upperIdent)) {
      return _unifiedRunwaysByAirport[upperIdent]!;
    }
    
    final unifiedRunways = <UnifiedRunway>[];
    final processedDesignations = <String>{};
    
    // 1. Get OurAirports runways
    final ourAirportsRunways = <Runway>[];
    if (_useTiledData) {
      ourAirportsRunways.addAll(
        _runwaysByAirport[upperIdent] ?? _runwaysByAirport[airportIdent] ?? []
      );
    } else if (_useBundledData) {
      ourAirportsRunways.addAll(_bundledService.getRunwaysForAirport(airportIdent));
    }
    
    // Convert to unified format
    for (final runway in ourAirportsRunways) {
      if (!runway.closed) {
        final unified = UnifiedRunway.fromOurAirports(runway);
        unifiedRunways.add(unified);
        processedDesignations.add(unified.designation);
      }
    }
    
    // 2. Add OpenAIP runways if provided
    if (openAIPRunways != null && openAIPRunways.isNotEmpty) {
      for (final openAIPRunway in openAIPRunways) {
        final unified = UnifiedRunway.fromOpenAIPRunway(
          openAIPRunway,
          airportIdent,
          airportLat: airportLat,
          airportLon: airportLon,
        );
        
        // Check if we already have this runway from OurAirports
        final existingIndex = unifiedRunways.indexWhere(
          (r) => r.matches(unified)
        );
        
        if (existingIndex >= 0) {
          // Merge data, preferring OurAirports data with OpenAIP filling gaps
          unifiedRunways[existingIndex] = UnifiedRunway.merge(
            unifiedRunways[existingIndex],
            unified,
          );
        } else if (!processedDesignations.contains(unified.designation)) {
          // Add new runway from OpenAIP
          unifiedRunways.add(unified);
          processedDesignations.add(unified.designation);
        }
      }
    }
    
    // Cache the results
    _unifiedRunwaysByAirport[upperIdent] = unifiedRunways;
    
    return unifiedRunways;
  }

  /// Get runways for multiple airports
  Map<String, List<Runway>> getRunwaysForAirports(List<String> airportIdents) {
    if (_useBundledData) {
      return _bundledService.getRunwaysForAirports(airportIdents);
    }
    
    final result = <String, List<Runway>>{};

    for (final ident in airportIdents) {
      result[ident] = getRunwaysForAirport(ident);
    }

    return result;
  }

  /// Search runways by various criteria
  List<Runway> searchRunways({
    String? airportIdent,
    int? minLengthFt,
    int? maxLengthFt,
    String? surface,
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

      if (minLengthFt != null && runway.lengthFt < minLengthFt) {
        return false;
      }

      if (maxLengthFt != null && runway.lengthFt > maxLengthFt) {
        return false;
      }

      if (surface != null &&
          !runway.surface.toLowerCase().contains(surface.toLowerCase())) {
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

  /// Get runway statistics for an airport
  RunwayStats getAirportRunwayStats(String airportIdent) {
    final airportRunways = getRunwaysForAirport(airportIdent);

    if (airportRunways.isEmpty) {
      return RunwayStats.empty();
    }

    final lengths = airportRunways.map((r) => r.lengthFt).toList();
    final surfaces = airportRunways
        .map((r) => r.surfaceFormatted)
        .toSet()
        .toList();

    return RunwayStats(
      count: airportRunways.length,
      longestFt: lengths.reduce((a, b) => a > b ? a : b),
      shortestFt: lengths.reduce((a, b) => a < b ? a : b),
      surfaces: surfaces,
      hasLightedRunways: airportRunways.any((r) => r.lighted),
      hasHardSurface: airportRunways.any(
        (r) =>
            r.surface.toLowerCase().contains('asp') ||
            r.surface.toLowerCase().contains('con'),
      ),
    );
  }

  /// Clear all cached runway data
  Future<void> clearCache() async {
    await _cacheService.clearRunwaysCache();
    _runways.clear();
    _runwaysByAirport.clear();
    _unifiedRunwaysByAirport.clear();
    _loadedAreas.clear();
    _tiledDataLoader.clearCacheForType('runways');
    developer.log('🗑️ Runway cache cleared');
  }
}

/// Statistics about runways at an airport
class RunwayStats {
  final int count;
  final int longestFt;
  final int shortestFt;
  final List<String> surfaces;
  final bool hasLightedRunways;
  final bool hasHardSurface;

  RunwayStats({
    required this.count,
    required this.longestFt,
    required this.shortestFt,
    required this.surfaces,
    required this.hasLightedRunways,
    required this.hasHardSurface,
  });

  factory RunwayStats.empty() {
    return RunwayStats(
      count: 0,
      longestFt: 0,
      shortestFt: 0,
      surfaces: [],
      hasLightedRunways: false,
      hasHardSurface: false,
    );
  }

  String get longestFormatted {
    if (longestFt >= 1000) {
      return '${(longestFt / 1000).toStringAsFixed(1)}k ft';
    }
    return '$longestFt ft';
  }

  String get shortestFormatted {
    if (shortestFt >= 1000) {
      return '${(shortestFt / 1000).toStringAsFixed(1)}k ft';
    }
    return '$shortestFt ft';
  }

  String get surfacesFormatted => surfaces.join(', ');
}
