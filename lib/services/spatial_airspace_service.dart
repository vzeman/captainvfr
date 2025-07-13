import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/airspace.dart';
import '../utils/spatial_index.dart';
import 'openaip_service.dart';

/// Enhanced airspace service with spatial indexing for high-performance queries
class SpatialAirspaceService extends ChangeNotifier {
  final OpenAIPService _openAIPService;
  final HybridSpatialIndex _spatialIndex = HybridSpatialIndex();
  
  List<Airspace> _allAirspaces = [];
  bool _isIndexBuilt = false;
  Timer? _rebuildTimer;
  

  SpatialAirspaceService(this._openAIPService) {
    // Initialize service and build index once
    _initializeIndex();
  }
  
  Future<void> _initializeIndex() async {
    final airspaces = await _openAIPService.getCachedAirspaces();
    if (airspaces.isNotEmpty) {
      developer.log('🚀 Initializing spatial index with ${airspaces.length} airspaces');
      _allAirspaces = airspaces;
      _spatialIndex.clear();
      for (final airspace in airspaces) {
        _spatialIndex.insert(airspace);
      }
      _isIndexBuilt = true;
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
      developer.log('⚠️ Spatial index not ready, falling back to linear search');
      return _fallbackLinearSearch(bounds, currentAltitude, typeFilter, icaoClassFilter);
    }

    final startTime = DateTime.now();
    
    // Use spatial index for fast initial filtering
    List<Airspace> candidates = _spatialIndex.search(bounds).whereType<Airspace>().toList();
    
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
      developer.log('⚠️ Spatial index not ready, falling back to linear search');
      final bounds = LatLngBounds(point, point);
      return _fallbackLinearSearch(bounds, currentAltitude, typeFilter, icaoClassFilter);
    }

    final startTime = DateTime.now();
    
    // Use grid index for ultra-fast point queries
    List<Airspace> candidates = _spatialIndex.searchPoint(point).whereType<Airspace>().toList();
    
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
    final startTime = DateTime.now();
    developer.log('🔨 Rebuilding spatial index...');
    
    _allAirspaces = await _openAIPService.getCachedAirspaces();
    
    if (_allAirspaces.isNotEmpty) {
      _spatialIndex.clear();
      for (final airspace in _allAirspaces) {
        _spatialIndex.insert(airspace);
      }
      _isIndexBuilt = true;
      
      final buildTime = DateTime.now().difference(startTime).inMilliseconds;
      developer.log('✅ Spatial index rebuilt in ${buildTime}ms for ${_allAirspaces.length} airspaces');
      
      notifyListeners();
    } else {
      developer.log('⚠️ No airspaces available for indexing');
      _isIndexBuilt = false;
    }
  }

  /// Get index statistics
  Map<String, dynamic> getIndexStats() {
    return {
      'isBuilt': _isIndexBuilt,
      'airspaceCount': _allAirspaces.length,
      'indexSize': _spatialIndex.size,
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

  /// Fallback linear search when index is not available
  List<Airspace> _fallbackLinearSearch(LatLngBounds bounds, double? currentAltitude, 
      Set<int>? typeFilter, Set<int>? icaoClassFilter) {
    return _allAirspaces.where((airspace) {
      // Bounds check
      final airspaceBounds = airspace.boundingBox;
      if (airspaceBounds == null) return false;
      
      final intersects = !(airspaceBounds.northEast.latitude < bounds.southWest.latitude ||
                          airspaceBounds.southWest.latitude > bounds.northEast.latitude ||
                          airspaceBounds.northEast.longitude < bounds.southWest.longitude ||
                          airspaceBounds.southWest.longitude > bounds.northEast.longitude);
      
      if (!intersects) return false;
      
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

  /// Clear the spatial index and free memory
  void clearIndex() {
    _spatialIndex.clear();
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
}


/// Helper class for distance calculations
class _AirspaceWithDistance {
  final Airspace airspace;
  final double distance;

  _AirspaceWithDistance(this.airspace, this.distance);
}