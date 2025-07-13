import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/navaid.dart';
import '../services/navaid_service.dart';
import '../utils/spatial_index.dart';
import 'dart:developer' as developer;

/// High-performance navaid service using spatial indexing
class SpatialNavaidService extends ChangeNotifier {
  final NavaidService _navaidService;
  final HybridSpatialIndex _spatialIndex = HybridSpatialIndex();
  final Map<int, Navaid> _navaidCache = {};
  
  List<Navaid> _allNavaids = [];
  bool _isIndexBuilt = false;
  Timer? _rebuildTimer;
  
  SpatialNavaidService(this._navaidService) {
    _initializeIndex();
  }

  @override
  void dispose() {
    _rebuildTimer?.cancel();
    super.dispose();
  }


  Future<void> _initializeIndex() async {
    // Get navaids from service
    await _navaidService.initialize();
    final navaids = _navaidService.navaids;
    if (navaids.isNotEmpty) {
      _buildIndexFromNavaids(navaids);
    }
  }

  void _buildIndexFromNavaids(List<Navaid> navaids) {
    final startTime = DateTime.now();
    
    _allNavaids = navaids;
    _navaidCache.clear();
    
    // Build spatial index and cache
    _spatialIndex.clear();
    for (final navaid in navaids) {
      _spatialIndex.insert(NavaidAdapter(navaid));
      _navaidCache[navaid.id] = navaid;
    }
    
    _isIndexBuilt = true;
    
    final duration = DateTime.now().difference(startTime);
    developer.log('✅ Navaid spatial index built in ${duration.inMilliseconds}ms for ${navaids.length} navaids');
    
    notifyListeners();
  }

  /// Rebuild the spatial index
  Future<void> rebuildIndex() async {
    if (_allNavaids.isEmpty) {
      // Try to get navaids from service
      final navaids = _navaidService.navaids;
      if (navaids.isNotEmpty) {
        _buildIndexFromNavaids(navaids);
      }
    } else {
      _buildIndexFromNavaids(_allNavaids);
    }
  }

  /// Get navaids within the specified bounds with ultra-fast spatial queries
  Future<List<Navaid>> getNavaidsInBounds(
    LatLngBounds bounds, {
    double? zoom,
    Set<String>? typeFilter,
    double? minPower,
  }) async {
    if (!_isIndexBuilt) {
      await rebuildIndex();
      if (!_isIndexBuilt) {
        // Fallback to regular service if index not available
        return _navaidService.getNavaidsInBounds(
          bounds.southWest,
          bounds.northEast,
        );
      }
    }

    final startTime = DateTime.now();
    
    // Use spatial index for ultra-fast queries
    final adapters = _spatialIndex.search(bounds);
    
    // Extract navaids and apply filters
    final navaids = adapters
        .whereType<NavaidAdapter>()
        .map((adapter) => adapter.navaid)
        .where((navaid) {
          // Apply type filter if provided
          if (typeFilter != null && !typeFilter.contains(navaid.type)) {
            return false;
          }
          
          // Apply power filter if provided
          if (minPower != null && navaid.power < minPower) {
            return false;
          }
          
          // Apply zoom-based filtering
          if (zoom != null) {
            return _shouldShowNavaidAtZoom(navaid, zoom);
          }
          
          return true;
        })
        .toList();
    
    final queryTime = DateTime.now().difference(startTime);
    developer.log('🚀 Navaid spatial query completed in ${queryTime.inMicroseconds}μs, found ${navaids.length} navaids');
    
    return navaids;
  }

  /// Get nearest navaids to a point
  Future<List<Navaid>> getNearestNavaids(
    LatLng point, {
    int limit = 10,
    double maxDistanceKm = 100,
    Set<String>? typeFilter,
  }) async {
    if (!_isIndexBuilt) {
      await rebuildIndex();
    }

    final startTime = DateTime.now();
    
    // Create search bounds based on max distance
    final latDelta = maxDistanceKm / 111.0; // Rough conversion
    final lngDelta = maxDistanceKm / (111.0 * cos(point.latitude * pi / 180));
    
    final bounds = LatLngBounds(
      LatLng(point.latitude - latDelta, point.longitude - lngDelta),
      LatLng(point.latitude + latDelta, point.longitude + lngDelta),
    );
    
    // Use spatial index to get candidates
    final adapters = _spatialIndex.search(bounds);
    
    // Calculate distances and sort
    final navaidsWithDistance = adapters
        .whereType<NavaidAdapter>()
        .map((adapter) {
          final navaid = adapter.navaid;
          final distance = _calculateDistance(point, navaid.position);
          return MapEntry(navaid, distance);
        })
        .where((entry) {
          // Apply distance filter
          if (entry.value > maxDistanceKm) return false;
          
          // Apply type filter
          if (typeFilter != null && !typeFilter.contains(entry.key.type)) {
            return false;
          }
          
          return true;
        })
        .toList();
    
    // Sort by distance
    navaidsWithDistance.sort((a, b) => a.value.compareTo(b.value));
    
    // Take requested limit
    final navaids = navaidsWithDistance
        .take(limit)
        .map((entry) => entry.key)
        .toList();
    
    final queryTime = DateTime.now().difference(startTime);
    developer.log('🚀 Nearest navaids query completed in ${queryTime.inMicroseconds}μs, found ${navaids.length} navaids');
    
    return navaids;
  }

  /// Get navaid by ID (O(1) lookup)
  Navaid? getNavaidById(int id) {
    return _navaidCache[id];
  }

  /// Clear the spatial index
  void clearIndex() {
    _spatialIndex.clear();
    _navaidCache.clear();
    _isIndexBuilt = false;
    notifyListeners();
  }

  bool _shouldShowNavaidAtZoom(Navaid navaid, double zoom) {
    // VOR/VORTAC and NDB are important, show at lower zoom
    if (navaid.type == 'VOR' || navaid.type == 'VORTAC' || navaid.type == 'NDB') {
      return zoom >= 8;
    }
    
    // DME and TACAN show at medium zoom
    if (navaid.type == 'DME' || navaid.type == 'TACAN') {
      return zoom >= 10;
    }
    
    // Other types show at higher zoom
    return zoom >= 11;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  int get indexedNavaidCount => _allNavaids.length;
  bool get isIndexBuilt => _isIndexBuilt;
}

/// Adapter to make Navaid work with spatial index
class NavaidAdapter implements SpatialIndexable {
  final Navaid navaid;

  NavaidAdapter(this.navaid);

  @override
  LatLngBounds? get boundingBox {
    // Navaids are points, so create a small bounding box
    const delta = 0.001; // ~111m
    return LatLngBounds(
      LatLng(navaid.position.latitude - delta, navaid.position.longitude - delta),
      LatLng(navaid.position.latitude + delta, navaid.position.longitude + delta),
    );
  }

  @override
  bool containsPoint(LatLng point) {
    // For navaids, check if point is very close (within ~100m)
    const threshold = 0.001;
    return (navaid.position.latitude - point.latitude).abs() < threshold &&
           (navaid.position.longitude - point.longitude).abs() < threshold;
  }
}