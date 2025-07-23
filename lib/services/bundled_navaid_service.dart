import 'dart:async';
import 'dart:developer' as developer;
import 'package:latlong2/latlong.dart';
import 'dart:math' show sin, cos, sqrt, atan2;
import '../models/navaid.dart';
import 'cache_service.dart';

/// Service to provide navaid data from bundled assets
class BundledNavaidService {
  List<Navaid> _navaids = [];
  final bool _isLoading = false;
  bool _bundledDataLoaded = false;
  late final CacheService _cacheService;

  // Singleton pattern
  static final BundledNavaidService _instance = BundledNavaidService._internal();
  factory BundledNavaidService() => _instance;
  BundledNavaidService._internal() {
    _cacheService = CacheService();
  }

  bool get isLoading => _isLoading;
  List<Navaid> get navaids => List.unmodifiable(_navaids);

  /// Initialize the service and load bundled data
  Future<void> initialize() async {
    developer.log('🔧 BundledNavaidService: Starting initialization...');
    await _cacheService.initialize();
    developer.log('🔧 BundledNavaidService: Cache service initialized');
    
    // Try to load bundled data first
    await _loadBundledNavaids();
    
    // If no bundled data, try cache
    if (!_bundledDataLoaded) {
      await _loadCachedNavaids();
    }
    
    developer.log(
      '🔧 BundledNavaidService: Initialization complete, navaids: ${_navaids.length}',
    );
  }

  /// Load navaids from bundled assets
  Future<void> _loadBundledNavaids() async {
    if (_bundledDataLoaded) return;
    
    try {
      // TODO load bundled navaids from assets
    } catch (e) {
      developer.log('❌ Error loading bundled navaids: $e');
    }
  }

  /// Load navaids from cache
  Future<void> _loadCachedNavaids() async {
    try {
      final cachedNavaids = await _cacheService.getCachedNavaids();
      developer.log(
        '🔧 BundledNavaidService: Retrieved ${cachedNavaids.length} navaids from cache',
      );
      if (cachedNavaids.isNotEmpty) {
        _navaids = cachedNavaids;
      }
    } catch (e) {
      developer.log('❌ Error loading cached navaids: $e');
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

  /// Force refresh from bundled data
  Future<void> refreshData() async {
    _bundledDataLoaded = false;
    await _loadBundledNavaids();
  }

  /// Clear all cached navaid data
  Future<void> clearCache() async {
    await _cacheService.clearNavaidsCache();
    _navaids.clear();
    developer.log('🗑️ Navaid cache cleared');
  }

  /// Clean up resources
  void dispose() {
    _navaids.clear();
  }

  /// Compatibility method for old API
  Future<void> fetchNavaids({bool forceRefresh = false}) async {
    if (forceRefresh || _navaids.isEmpty) {
      await refreshData();
    }
  }

  /// Force reload navaids data
  Future<void> forceReload() async {
    _navaids.clear();
    await refreshData();
  }
}