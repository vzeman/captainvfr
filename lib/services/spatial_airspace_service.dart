import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:archive/archive.dart';
import '../models/airspace.dart';
import '../utils/spatial_index.dart';
import '../utils/serializable_spatial_index.dart';
import 'openaip_service.dart';

/// Enhanced airspace service with spatial indexing for high-performance queries
class SpatialAirspaceService extends ChangeNotifier {
  final OpenAIPService _openAIPService;
  final HybridSpatialIndex _spatialIndex = HybridSpatialIndex();
  SerializableSpatialIndex? _prebuiltIndex;
  
  List<Airspace> _allAirspaces = [];
  bool _isIndexBuilt = false;
  Timer? _rebuildTimer;
  bool _prebuiltIndexLoaded = false;
  

  SpatialAirspaceService(this._openAIPService) {
    // Initialize service and try to load pre-built index
    _initializeIndex();
    
    // Set up a periodic check to ensure index is up to date
    _rebuildTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      // Skip if not initialized yet
      if (!_isIndexBuilt) return;
      
      final currentCount = await _openAIPService.getCachedAirspaces().then((a) => a.length);
      if (currentCount != _allAirspaces.length) {
        developer.log('📊 Airspace count changed: ${_allAirspaces.length} -> $currentCount');
        // Update airspace list without rebuilding if we have pre-built index
        if (_prebuiltIndexLoaded && _prebuiltIndex != null) {
          await _updateAirspaceList();
        } else {
          await rebuildIndex();
        }
      }
    });
  }
  
  Future<void> _initializeIndex() async {
    // Skip if already initialized
    if (_isIndexBuilt) {
      return;
    }
    
    // Try to load pre-built index first
    await _loadPrebuiltIndex();
    
    final airspaces = await _openAIPService.getCachedAirspaces();
    if (airspaces.isNotEmpty) {
      _allAirspaces = airspaces;
      
      if (_prebuiltIndexLoaded && _prebuiltIndex != null) {
        developer.log('🚀 Pre-built spatial index loaded successfully!');
        developer.log('📊 Index contains ${_prebuiltIndex!.gridIndex.length} grid cells');
        developer.log('📊 Managing ${airspaces.length} airspaces');
        _isIndexBuilt = true;
      } else {
        developer.log('🚀 Building runtime spatial index with ${airspaces.length} airspaces');
        developer.log('⚠️ Pre-built index not available, falling back to runtime indexing');
        _spatialIndex.clear();
        for (final airspace in airspaces) {
          _spatialIndex.insert(airspace);
        }
        _isIndexBuilt = true;
      }
      notifyListeners();
    } else {
      developer.log('⚠️ No airspaces available for spatial index initialization');
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
    
    List<Airspace> candidates;
    
    // Use pre-built index if available, otherwise fall back to runtime index
    if (_prebuiltIndexLoaded && _prebuiltIndex != null) {
      final airspaceIds = _prebuiltIndex!.queryBounds(bounds);
      candidates = _getAirspacesByIds(airspaceIds);
      developer.log('🗂️ Using pre-built index: found ${airspaceIds.length} IDs, matched ${candidates.length} airspaces');
    } else {
      candidates = _spatialIndex.search(bounds).whereType<Airspace>().toList();
      developer.log('🔨 Using runtime index: found ${candidates.length} airspaces');
    }
    
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
    
    List<Airspace> candidates;
    
    // Use pre-built index if available, otherwise fall back to runtime index
    if (_prebuiltIndexLoaded && _prebuiltIndex != null) {
      final airspaceIds = _prebuiltIndex!.queryPoint(point);
      candidates = _getAirspacesByIds(airspaceIds.toSet());
      developer.log('🗂️ Using pre-built index for point: found ${airspaceIds.length} IDs, matched ${candidates.length} airspaces');
    } else {
      candidates = _spatialIndex.searchPoint(point).whereType<Airspace>().toList();
      developer.log('🔨 Using runtime index for point: found ${candidates.length} airspaces');
    }
    
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
    // If we have a pre-built index, just update the airspace list
    if (_prebuiltIndexLoaded && _prebuiltIndex != null) {
      await _updateAirspaceList();
      return;
    }
    
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
      'prebuiltIndexLoaded': _prebuiltIndexLoaded,
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
  
  /// Load pre-built spatial index from assets
  Future<void> _loadPrebuiltIndex() async {
    // Skip if already loaded
    if (_prebuiltIndexLoaded || _prebuiltIndex != null) {
      return;
    }
    
    try {
      developer.log('📦 Loading pre-built airspace spatial index...');
      final byteData = await rootBundle.load('assets/data/airspaces_index.json.gz');
      final compressed = byteData.buffer.asUint8List();
      
      List<int> decompressed;
      if (kIsWeb) {
        decompressed = GZipDecoder().decodeBytes(compressed);
      } else {
        decompressed = gzip.decode(compressed);
      }
      
      final jsonData = json.decode(utf8.decode(decompressed)) as Map<String, dynamic>;
      _prebuiltIndex = SerializableSpatialIndex.fromJson(jsonData);
      _prebuiltIndexLoaded = true;
      
      developer.log('✅ Pre-built spatial index loaded successfully');
    } catch (e) {
      developer.log('⚠️ Failed to load pre-built spatial index: $e');
      _prebuiltIndexLoaded = false;
    }
  }
  
  /// Get airspaces by their IDs
  List<Airspace> _getAirspacesByIds(Set<String> ids) {
    final results = _allAirspaces.where((airspace) => ids.contains(airspace.id)).toList();
    if (results.isEmpty && ids.isNotEmpty) {
      developer.log('⚠️ No airspaces found for ${ids.length} IDs. Sample IDs: ${ids.take(3).join(", ")}');
      developer.log('⚠️ Sample airspace IDs in memory: ${_allAirspaces.take(3).map((a) => a.id).join(", ")}');
    }
    return results;
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