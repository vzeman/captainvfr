import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/navaid.dart';
import 'cache_service.dart';

class NavaidService {
  static const String _baseUrl = 'https://davidmegginson.github.io/ourairports-data';
  static const String _navaidsUrl = '$_baseUrl/navaids.csv';

  List<Navaid> _navaids = [];
  bool _isLoading = false;
  final CacheService _cacheService = CacheService();

  // Singleton pattern
  static final NavaidService _instance = NavaidService._internal();
  factory NavaidService() => _instance;
  NavaidService._internal();

  bool get isLoading => _isLoading;
  List<Navaid> get navaids => List.unmodifiable(_navaids);

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    await _cacheService.initialize();
    await _loadFromCache();
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

  /// Force refresh data from network
  Future<void> refreshData() async {
    developer.log('🔄 Force refreshing navaids data...');
    await _cacheService.clearNavaidsCache();
    _navaids.clear();
    await fetchNavaids(forceRefresh: true);
  }

  /// Fetch all navaids from OurAirports
  Future<void> fetchNavaids({bool forceRefresh = false}) async {
    if (_isLoading) {
      developer.log('⏳ Already loading navaids, skipping...');
      return;
    }

    // If we already have navaids and not forcing refresh, no need to fetch again
    if (_navaids.isNotEmpty && !forceRefresh) {
      developer.log('✅ Using cached navaids (${_navaids.length} navaids)');
      return;
    }

    _isLoading = true;
    developer.log('🧭 Fetching all navaids...');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse(_navaidsUrl))
          .timeout(const Duration(seconds: 10));
      developer.log('📡 Navaid data response status: ${response.statusCode} (took ${stopwatch.elapsedMilliseconds}ms)');

      if (response.statusCode == 200) {
        developer.log('📊 Successfully fetched navaid data. Parsing...');

        // Parse CSV response
        final lines = const LineSplitter().convert(response.body);
        developer.log('📄 Parsed ${lines.length} lines from navaids CSV');

        if (lines.length > 1) { // Skip header
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

          developer.log('✅ Found ${filteredNavaids.length} valid navaid entries in CSV ($invalidCount invalid entries skipped)');

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

          developer.log('✨ Successfully created ${_navaids.length} Navaid objects');

          // Cache the navaids
          await _cacheService.cacheNavaids(_navaids);

          if (_navaids.isNotEmpty) {
            developer.log('🧭 First navaid: ${_navaids.first.ident} - ${_navaids.first.name} (${_navaids.first.position})');
            developer.log('🧭 Sample types: ${_navaids.take(5).map((n) => n.type).join(", ")}');
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
    return _navaids.where((navaid) =>
      navaid.type.toLowerCase() == type.toLowerCase()
    ).toList();
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadiusKm = 6371.0;

    double dLat = _toRadians(point2.latitude - point1.latitude);
    double dLon = _toRadians(point2.longitude - point1.longitude);

    double lat1 = _toRadians(point1.latitude);
    double lat2 = _toRadians(point2.latitude);

    double a = sin(dLat/2) * sin(dLat/2) +
              sin(dLon/2) * sin(dLon/2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Clean up resources
  void dispose() {
    _navaids.clear();
  }

  /// Force reload navaids data
  Future<void> forceReload() async {
    _navaids.clear();
    await fetchNavaids(forceRefresh: true);
  }
}
