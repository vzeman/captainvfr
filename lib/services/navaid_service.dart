import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/navaid.dart';
import 'cache_service.dart';
import 'bundled_navaid_service.dart';
import 'tiled_data_loader.dart';

class NavaidService {
  static const String _baseUrl =
      'https://davidmegginson.github.io/ourairports-data';
  static const String _navaidsUrl = '$_baseUrl/navaids.csv';

  List<Navaid> _navaids = [];
  bool _isLoading = false;
  final CacheService _cacheService = CacheService();
  final BundledNavaidService _bundledService = BundledNavaidService();
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  bool _useBundledData = true;
  bool _useTiledData = true;
  
  // Cache for tiled data
  final Map<String, List<Navaid>> _navaidsByArea = {};
  final Set<String> _loadedAreas = {};

  // Singleton pattern
  static final NavaidService _instance = NavaidService._internal();
  factory NavaidService() => _instance;
  NavaidService._internal();

  bool get isLoading => _isLoading || _bundledService.isLoading;
  List<Navaid> get navaids {
    if (_useTiledData) {
      // Return all navaids from tiled data cache
      return _navaidsByArea.values.expand((navaids) => navaids).toList();
    }
    return _useBundledData ? _bundledService.navaids : List.unmodifiable(_navaids);
  }

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    await _cacheService.initialize();
    
    // Check if tiled data is available
    try {
      // Try to load a test tile to see if tiled data exists
      final testNavaids = await _tiledDataLoader.loadNavaidsForArea(
        minLat: 40.0,
        maxLat: 50.0,
        minLon: -80.0,
        maxLon: -70.0,
      );
      
      if (testNavaids.isNotEmpty) {
        developer.log('✅ Using tiled navaid data');
        _useTiledData = true;
        _useBundledData = false;
        return;
      }
    } catch (e) {
      developer.log('❌ Tiled navaid data not available: $e');
    }
    
    // Fall back to bundled data
    _useTiledData = false;
    await _bundledService.initialize();
    
    // If bundled data is available, use it
    if (_bundledService.navaids.isNotEmpty) {
      developer.log('✅ Using bundled navaid data (${_bundledService.navaids.length} navaids)');
      _useBundledData = true;
    } else {
      // Fall back to old method
      _useBundledData = false;
      await _loadFromCache();
    }
  }

  /// Load navaids from cache if available
  Future<void> _loadFromCache() async {
    try {
      _navaids = await _cacheService.getCachedNavaids();
    } catch (e) {
      developer.log('❌ Error loading navaids from cache: $e');
      _navaids = [];
    }
  }
  
  /// Load navaids for a given map area (for tiled data)
  Future<void> loadNavaidsForArea({
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
      developer.log('📍 Loading navaids for area: ($minLat, $minLon) to ($maxLat, $maxLon)');
      
      // Load navaids from tiles
      final navaids = await _tiledDataLoader.loadNavaidsForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      // Group by area and prevent duplicates
      for (final navaid in navaids) {
        final existingNavaids = _navaidsByArea.values.expand((list) => list);
        
        // Check if this navaid already exists (by ID to avoid duplicates)
        final alreadyExists = existingNavaids.any((n) => n.id == navaid.id);
        
        // Only add if it's not already in the list
        if (!alreadyExists) {
          _navaidsByArea.putIfAbsent(areaKey, () => []).add(navaid);
        }
      }
      
      _loadedAreas.add(areaKey);
      
      developer.log('✅ Loaded ${navaids.length} navaids for area');
    } catch (e) {
      developer.log('❌ Error loading navaids for area: $e');
    }
  }

  /// Force refresh data from network
  Future<void> refreshData() async {
    developer.log('🔄 Force refreshing navaids data...');
    
    if (_useBundledData) {
      await _bundledService.refreshData();
    } else {
      await _cacheService.clearNavaidsCache();
      _navaids.clear();
      await fetchNavaids(forceRefresh: true);
    }
  }

  /// Fetch all navaids from OurAirports
  Future<void> fetchNavaids({bool forceRefresh = false}) async {
    if (_useBundledData) {
      await _bundledService.fetchNavaids(forceRefresh: forceRefresh);
      return;
    }
    
    if (_isLoading) {
      developer.log('⏳ Already loading navaids, skipping...');
      return;
    }

    // If we already have navaids and not forcing refresh, no need to fetch again
    if (_navaids.isNotEmpty && !forceRefresh) {
      return;
    }

    _isLoading = true;

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse(_navaidsUrl))
          .timeout(const Duration(seconds: 10));
      developer.log(
        '📡 Navaid data response status: ${response.statusCode} (took ${stopwatch.elapsedMilliseconds}ms)',
      );

      if (response.statusCode == 200) {
        developer.log('📊 Successfully fetched navaid data. Parsing...');

        // Parse CSV response
        final lines = const LineSplitter().convert(response.body);
        developer.log('📄 Parsed ${lines.length} lines from navaids CSV');

        if (lines.length > 1) {
          // Skip header
          final filteredNavaids = <String>[];
          int invalidCount = 0;

          for (var i = 1; i < lines.length; i++) {
            final line = lines[i];
            if (line.trim().isEmpty) continue;

            try {
              final parts = line.split(',');
              if (parts.length >= 8) {
                final lat = double.tryParse(parts[6]) ?? 0.0;
                final lon = double.tryParse(parts[7]) ?? 0.0;

                if (lat != 0.0 || lon != 0.0) {
                  filteredNavaids.add(line);
                } else {
                  invalidCount++;
                }
              } else {
                invalidCount++;
              }
            } catch (e) {
              invalidCount++;
            }
          }

          developer.log(
            '✅ Found ${filteredNavaids.length} valid navaid entries in CSV ($invalidCount invalid entries skipped)',
          );

          developer.log('🏗  Creating Navaid objects...');
          final parsedNavaids = <Navaid>[];

          for (final line in filteredNavaids) {
            try {
              final navaid = Navaid.fromCsv(line);
              if (navaid.hasValidPosition) {
                parsedNavaids.add(navaid);
              }
            } catch (e) {
              developer.log('❌ Error parsing navaid data: $e');
              // Continue with next navaid
            }
          }

          _navaids = parsedNavaids;

          developer.log(
            '✨ Successfully created ${_navaids.length} Navaid objects',
          );

          // Cache the navaids
          await _cacheService.cacheNavaids(_navaids);

          if (_navaids.isNotEmpty) {
            developer.log(
              '🧭 First navaid: ${_navaids.first.ident} - ${_navaids.first.name} (${_navaids.first.position})',
            );
            developer.log(
              '🧭 Sample types: ${_navaids.take(5).map((n) => n.type).join(", ")}',
            );
          }
        }
      } else {
        throw Exception('Failed to load navaids: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log('Error fetching navaids: $e');
      developer.log('Stack trace: $stackTrace');
      // Fall back to cached data if network fails
      if (!forceRefresh) {
        await _loadFromCache();
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Get navaids within a bounding box
  List<Navaid> getNavaidsInBounds(LatLng southWest, LatLng northEast) {
    if (_useTiledData) {
      // Return from tiled data cache
      final allNavaids = _navaidsByArea.values.expand((list) => list);
      return allNavaids.where((navaid) {
        final lat = navaid.position.latitude;
        final lng = navaid.position.longitude;

        return lat >= southWest.latitude &&
            lat <= northEast.latitude &&
            lng >= southWest.longitude &&
            lng <= northEast.longitude;
      }).toList();
    }
    
    if (_useBundledData) {
      return _bundledService.getNavaidsInBounds(southWest, northEast);
    }
    
    return _navaids.where((navaid) {
      final lat = navaid.position.latitude;
      final lng = navaid.position.longitude;

      return lat >= southWest.latitude &&
          lat <= northEast.latitude &&
          lng >= southWest.longitude &&
          lng <= northEast.longitude;
    }).toList();
  }

  /// Find navaids near a position
  List<Navaid> findNavaidsNearby(LatLng position, {double radiusKm = 50.0}) {
    if (_useTiledData) {
      // Return from tiled data cache
      final allNavaids = _navaidsByArea.values.expand((list) => list);
      return allNavaids.where((navaid) {
        try {
          final distance = _calculateDistance(position, navaid.position);
          return distance <= radiusKm;
        } catch (e) {
          developer.log('Error calculating distance for navaid', error: e);
          return false;
        }
      }).toList();
    }
    
    if (_useBundledData) {
      return _bundledService.findNavaidsNearby(position, radiusKm: radiusKm);
    }
    
    if (_navaids.isEmpty) return [];

    return _navaids.where((navaid) {
      try {
        final distance = _calculateDistance(position, navaid.position);
        return distance <= radiusKm;
      } catch (e) {
        developer.log('Error calculating distance for navaid', error: e);
        return false;
      }
    }).toList();
  }

  /// Search navaids by identifier or name
  List<Navaid> searchNavaids(String query) {
    if (_useTiledData) {
      if (query.isEmpty) return [];

      final searchQuery = query.toLowerCase().trim();
      final allNavaids = _navaidsByArea.values.expand((list) => list);

      return allNavaids.where((navaid) {
        // Search by identifier
        if (navaid.ident.toLowerCase().contains(searchQuery)) return true;

        // Search by name
        if (navaid.name.toLowerCase().contains(searchQuery)) return true;

        // Search by type
        if (navaid.type.toLowerCase().contains(searchQuery)) return true;

        return false;
      }).toList();
    }
    
    if (_useBundledData) {
      return _bundledService.searchNavaids(query);
    }
    
    if (query.isEmpty) return [];

    final searchQuery = query.toLowerCase().trim();

    return _navaids.where((navaid) {
      // Search by identifier
      if (navaid.ident.toLowerCase().contains(searchQuery)) return true;

      // Search by name
      if (navaid.name.toLowerCase().contains(searchQuery)) return true;

      // Search by type
      if (navaid.type.toLowerCase().contains(searchQuery)) return true;

      return false;
    }).toList();
  }

  /// Find navaid by exact identifier
  Navaid? findNavaidByIdent(String ident) {
    if (_useTiledData) {
      try {
        final allNavaids = _navaidsByArea.values.expand((list) => list);
        return allNavaids.firstWhere(
          (navaid) => navaid.ident.toLowerCase() == ident.toLowerCase(),
        );
      } catch (e) {
        return null;
      }
    }
    
    if (_useBundledData) {
      return _bundledService.findNavaidByIdent(ident);
    }
    
    try {
      return _navaids.firstWhere(
        (navaid) => navaid.ident.toLowerCase() == ident.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get navaids by type
  List<Navaid> getNavaidsByType(String type) {
    if (_useTiledData) {
      final allNavaids = _navaidsByArea.values.expand((list) => list);
      return allNavaids
          .where((navaid) => navaid.type.toLowerCase() == type.toLowerCase())
          .toList();
    }
    
    if (_useBundledData) {
      return _bundledService.getNavaidsByType(type);
    }
    
    return _navaids
        .where((navaid) => navaid.type.toLowerCase() == type.toLowerCase())
        .toList();
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadiusKm = 6371.0;

    double dLat = _toRadians(point2.latitude - point1.latitude);
    double dLon = _toRadians(point2.longitude - point1.longitude);

    double lat1 = _toRadians(point1.latitude);
    double lat2 = _toRadians(point2.latitude);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * 3.141592653589793 / 180;
  }

  /// Clean up resources
  void dispose() {
    _navaids.clear();
    _navaidsByArea.clear();
    _loadedAreas.clear();
    _tiledDataLoader.clearCacheForType('navaids');
    _bundledService.dispose();
  }

  /// Force reload navaids data
  Future<void> forceReload() async {
    if (_useBundledData) {
      await _bundledService.forceReload();
    } else {
      _navaids.clear();
      await fetchNavaids(forceRefresh: true);
    }
  }
}
