import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/airspace.dart';
import 'openaip_service.dart';
import 'tiled_data_loader.dart';

/// Enhanced airspace service with spatial indexing for high-performance queries
class SpatialAirspaceService extends ChangeNotifier {
  final OpenAIPService _openAIPService;
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  
  List<Airspace> _allAirspaces = [];
  bool _isIndexBuilt = false;
  Timer? _rebuildTimer;
  

  SpatialAirspaceService(this._openAIPService) {
    // Initialize service
    _initializeIndex();
    
    // Set up a periodic check to ensure index is up to date
    _rebuildTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      // Skip if not initialized yet
      if (!_isIndexBuilt) return;
      
      final currentCount = await _openAIPService.getCachedAirspaces().then((a) => a.length);
      if (currentCount != _allAirspaces.length) {
        developer.log('📊 Airspace count changed: ${_allAirspaces.length} -> $currentCount');
        await rebuildIndex();
      }
    });
  }
  
  Future<void> _initializeIndex() async {
    // Skip if already initialized
    if (_isIndexBuilt) {
      return;
    }
    
    final airspaces = await _openAIPService.getCachedAirspaces();
    if (airspaces.isNotEmpty) {
      _allAirspaces = airspaces;
      developer.log('🚀 Spatial index will be built dynamically as tiles are loaded');
      developer.log('📊 Managing ${airspaces.length} airspaces');
      _isIndexBuilt = true;
      notifyListeners();
    } else {
      developer.log('⚠️ No cached airspaces available, initializing with empty index');
      developer.log('📡 Airspaces will be loaded on-demand from tiled data');
      _allAirspaces = [];
      _isIndexBuilt = true; // Allow queries even with empty initial data
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _rebuildTimer?.cancel();
    super.dispose();
  }

  /// Get airspaces within the given bounds using spatial index
  Future<List<Airspace>> getAirspacesInBounds(LatLngBounds bounds, {
    double? currentAltitude,
    Set<int>? typeFilter,
    Set<int>? icaoClassFilter,
  }) async {
    await _ensureIndexBuilt();
    
    if (!_isIndexBuilt) {
      developer.log('⚠️ Spatial index not ready, skipping query');
      return [];
    }

    final startTime = DateTime.now();
    
    // First, ensure the tiles for this area are loaded
    await _tiledDataLoader.loadAirspacesForArea(
      minLat: bounds.southWest.latitude,
      maxLat: bounds.northEast.latitude,
      minLon: bounds.southWest.longitude,
      maxLon: bounds.northEast.longitude,
    );
    
    // Use the spatial index from TiledDataLoader
    final spatialIndex = _tiledDataLoader.getSpatialIndex('airspaces');
    if (spatialIndex == null) {
      developer.log('⚠️ No spatial index available for airspaces');
      return [];
    }
    
    // Query the spatial index
    var candidates = spatialIndex.search(bounds).whereType<Airspace>().toList();
    developer.log('🔨 Using dynamic spatial index: found ${candidates.length} airspaces');
    
    // Apply additional filters
    if (currentAltitude != null || typeFilter != null || icaoClassFilter != null) {
      candidates = candidates.where((airspace) {
        // Altitude filter
        if (currentAltitude != null && !airspace.isAtAltitude(currentAltitude)) {
          return false;
        }
        
        // Type filter
        if (typeFilter != null && !typeFilter.contains(int.tryParse(airspace.type ?? '') ?? 0)) {
          return false;
        }
        
        // ICAO class filter
        if (icaoClassFilter != null && !icaoClassFilter.contains(int.tryParse(airspace.icaoClass ?? '') ?? 0)) {
          return false;
        }
        
        return true;
      }).toList();
    }

    final queryTime = DateTime.now().difference(startTime).inMicroseconds;
    developer.log('🚀 Spatial query completed in $queryTimeμs, found ${candidates.length} airspaces');
    
    return candidates;
  }

  /// Get airspaces at a specific point using fast grid index
  Future<List<Airspace>> getAirspacesAtPoint(LatLng point, {
    double? currentAltitude,
    Set<int>? typeFilter,
    Set<int>? icaoClassFilter,
  }) async {
    await _ensureIndexBuilt();
    
    if (!_isIndexBuilt) {
      developer.log('⚠️ Spatial index not ready, skipping query');
      return [];
    }

    final startTime = DateTime.now();
    
    // First, ensure the tiles for this area are loaded (small area around the point)
    const buffer = 0.1; // degrees
    await _tiledDataLoader.loadAirspacesForArea(
      minLat: point.latitude - buffer,
      maxLat: point.latitude + buffer,
      minLon: point.longitude - buffer,
      maxLon: point.longitude + buffer,
    );
    
    // Use the spatial index from TiledDataLoader
    final spatialIndex = _tiledDataLoader.getSpatialIndex('airspaces');
    if (spatialIndex == null) {
      developer.log('⚠️ No spatial index available for airspaces');
      return [];
    }
    
    // Query the spatial index
    var candidates = spatialIndex.searchPoint(point).whereType<Airspace>().toList();
    developer.log('🔨 Using dynamic spatial index for point: found ${candidates.length} airspaces');
    
    // Apply additional filters
    if (currentAltitude != null || typeFilter != null || icaoClassFilter != null) {
      candidates = candidates.where((airspace) {
        // Altitude filter
        if (currentAltitude != null && !airspace.isAtAltitude(currentAltitude)) {
          return false;
        }
        
        // Type filter
        if (typeFilter != null && !typeFilter.contains(int.tryParse(airspace.type ?? '') ?? 0)) {
          return false;
        }
        
        // ICAO class filter
        if (icaoClassFilter != null && !icaoClassFilter.contains(int.tryParse(airspace.icaoClass ?? '') ?? 0)) {
          return false;
        }
        
        return true;
      }).toList();
    }

    final queryTime = DateTime.now().difference(startTime).inMicroseconds;
    developer.log('⚡ Point query completed in $queryTimeμs, found ${candidates.length} airspaces');
    
    return candidates;
  }

  /// Get nearest airspaces to a point within a radius
  Future<List<Airspace>> getNearestAirspaces(LatLng center, double radiusKm, {
    int maxResults = 10,
    double? currentAltitude,
    Set<int>? typeFilter,
    Set<int>? icaoClassFilter,
  }) async {
    // Convert radius to approximate degrees
    final radiusDegrees = radiusKm / 111.0; // Rough conversion: 1 degree ≈ 111 km
    
    final bounds = LatLngBounds(
      LatLng(center.latitude - radiusDegrees, center.longitude - radiusDegrees),
      LatLng(center.latitude + radiusDegrees, center.longitude + radiusDegrees),
    );

    final candidates = await getAirspacesInBounds(bounds,
        currentAltitude: currentAltitude,
        typeFilter: typeFilter,
        icaoClassFilter: icaoClassFilter);

    // Calculate distances and sort
    final candidatesWithDistance = candidates.map((airspace) {
      final distance = _calculateDistance(center, airspace);
      return _AirspaceWithDistance(airspace, distance);
    }).where((item) => item.distance <= radiusKm).toList();

    candidatesWithDistance.sort((a, b) => a.distance.compareTo(b.distance));

    return candidatesWithDistance
        .take(maxResults)
        .map((item) => item.airspace)
        .toList();
  }

  /// Force rebuild of spatial index
  Future<void> rebuildIndex() async {
    // Update the airspace list
    await _updateAirspaceList();
    
    developer.log('🔨 Clearing spatial index cache for airspaces...');
    
    // Clear the spatial index for airspaces in TiledDataLoader
    _tiledDataLoader.clearCacheForType('airspaces');
    
    _allAirspaces = await _openAIPService.getCachedAirspaces();
    
    if (_allAirspaces.isNotEmpty) {
      _isIndexBuilt = true;
      developer.log('✅ Spatial index cache cleared. Index will be rebuilt dynamically as tiles are loaded.');
      developer.log('📊 Managing ${_allAirspaces.length} airspaces');
      notifyListeners();
    } else {
      developer.log('⚠️ No airspaces available');
      _isIndexBuilt = false;
    }
  }

  /// Get index statistics
  Map<String, dynamic> getIndexStats() {
    final spatialIndex = _tiledDataLoader.getSpatialIndex('airspaces');
    return {
      'isBuilt': _isIndexBuilt,
      'airspaceCount': _allAirspaces.length,
      'indexSize': spatialIndex?.size ?? 0,
      'dynamicIndexing': true,
    };
  }

  /// Preload airspaces for a specific area
  Future<void> preloadArea(LatLngBounds bounds) async {
    // Preload airspaces for bounds
    await _openAIPService.loadAirspacesForBounds(
      minLat: bounds.southWest.latitude,
      minLon: bounds.southWest.longitude,
      maxLat: bounds.northEast.latitude,
      maxLon: bounds.northEast.longitude,
    );
    // Don't rebuild on preload - the index already contains all airspaces
  }



  Future<void> _ensureIndexBuilt() async {
    // Don't rebuild if already built or if no airspaces loaded
    if (!_isIndexBuilt && _allAirspaces.isEmpty) {
      // Try to initialize if not done yet
      await _initializeIndex();
    }
  }


  /// Clear the spatial index and free memory
  void clearIndex() {
    _tiledDataLoader.clearCacheForType('airspaces');
    _isIndexBuilt = false;
    notifyListeners();
  }

  double _calculateDistance(LatLng center, Airspace airspace) {
    // Find the closest point on the airspace boundary to the center
    double minDistance = double.infinity;
    
    for (final point in airspace.geometry) {
      final distance = _distanceInKm(center, point);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    // If center is inside airspace, distance is 0
    if (airspace.containsPoint(center)) {
      return 0.0;
    }
    
    return minDistance;
  }

  double _distanceInKm(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
  
  
  /// Update airspace list without rebuilding spatial index
  Future<void> _updateAirspaceList() async {
    final startTime = DateTime.now();
    developer.log('📋 Updating airspace list (keeping pre-built index)...');
    
    _allAirspaces = await _openAIPService.getCachedAirspaces();
    
    if (_allAirspaces.isNotEmpty) {
      _isIndexBuilt = true;
      final updateTime = DateTime.now().difference(startTime).inMilliseconds;
      developer.log('✅ Airspace list updated in ${updateTime}ms for ${_allAirspaces.length} airspaces');
      notifyListeners();
    } else {
      developer.log('⚠️ No airspaces available');
      _isIndexBuilt = false;
    }
  }
}


/// Helper class for distance calculations
class _AirspaceWithDistance {
  final Airspace airspace;
  final double distance;

  _AirspaceWithDistance(this.airspace, this.distance);
}