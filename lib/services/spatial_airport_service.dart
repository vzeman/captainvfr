import 'dart:async';
import 'dart:math' show cos;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';
import '../services/airport_service.dart';
import '../services/cache_service.dart';
import '../utils/spatial_index.dart';
import 'dart:developer' as developer;

/// High-performance airport service using spatial indexing
class SpatialAirportService extends ChangeNotifier {
  final AirportService _airportService;
  final CacheService _cacheService = CacheService();
  final HybridSpatialIndex _spatialIndex = HybridSpatialIndex();
  final Map<String, Airport> _airportCache = {};
  
  List<Airport> _allAirports = [];
  bool _isIndexBuilt = false;
  Timer? _rebuildTimer;
  
  SpatialAirportService(this._airportService) {
    _initializeIndex();
  }

  @override
  void dispose() {
    _rebuildTimer?.cancel();
    super.dispose();
  }


  Future<void> _initializeIndex() async {
    // Get cached airports first
    final airports = await _cacheService.getCachedAirports();
    if (airports.isNotEmpty) {
      _buildIndexFromAirports(airports);
    }
  }

  void _buildIndexFromAirports(List<Airport> airports) {
    final startTime = DateTime.now();
    
    _allAirports = airports;
    _airportCache.clear();
    
    // Build spatial index and cache
    _spatialIndex.clear();
    for (final airport in airports) {
      _spatialIndex.insert(AirportAdapter(airport));
      _airportCache[airport.icao] = airport;
    }
    
    _isIndexBuilt = true;
    
    final duration = DateTime.now().difference(startTime);
    developer.log('✅ Airport spatial index built in ${duration.inMilliseconds}ms for ${airports.length} airports');
    
    notifyListeners();
  }

  /// Rebuild the spatial index
  Future<void> rebuildIndex() async {
    if (_allAirports.isEmpty) {
      // Try to get airports from cache
      final airports = await _cacheService.getCachedAirports();
      if (airports.isNotEmpty) {
        _buildIndexFromAirports(airports);
      }
    } else {
      _buildIndexFromAirports(_allAirports);
    }
  }

  /// Get airports within the specified bounds with ultra-fast spatial queries
  Future<List<Airport>> getAirportsInBounds(
    LatLngBounds bounds, {
    double? zoom,
    Set<String>? typeFilter,
  }) async {
    if (!_isIndexBuilt) {
      await rebuildIndex();
      if (!_isIndexBuilt) {
        // Fallback to regular service if index not available
        return _airportService.getAirportsInBounds(
          bounds.southWest,
          bounds.northEast,
        );
      }
    }

    final startTime = DateTime.now();
    
    // Use spatial index for ultra-fast queries
    final adapters = _spatialIndex.search(bounds);
    
    // Extract airports and apply filters
    final airports = adapters
        .whereType<AirportAdapter>()
        .map((adapter) => adapter.airport)
        .where((airport) {
          // Apply type filter if provided
          if (typeFilter != null && !typeFilter.contains(airport.type)) {
            return false;
          }
          
          // Apply zoom-based filtering
          if (zoom != null) {
            return _shouldShowAirportAtZoom(airport, zoom);
          }
          
          return true;
        })
        .toList();
    
    final queryTime = DateTime.now().difference(startTime);
    developer.log('🚀 Airport spatial query completed in ${queryTime.inMicroseconds}μs, found ${airports.length} airports');
    
    return airports;
  }

  /// Get nearest airports to a point
  Future<List<Airport>> getNearestAirports(
    LatLng point, {
    int limit = 10,
    double maxDistanceKm = 50,
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
    final airportsWithDistance = adapters
        .whereType<AirportAdapter>()
        .map((adapter) {
          final airport = adapter.airport;
          final distance = _calculateDistance(point, airport.position);
          return MapEntry(airport, distance);
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
    airportsWithDistance.sort((a, b) => a.value.compareTo(b.value));
    
    // Take requested limit
    final airports = airportsWithDistance
        .take(limit)
        .map((entry) => entry.key)
        .toList();
    
    final queryTime = DateTime.now().difference(startTime);
    developer.log('🚀 Nearest airports query completed in ${queryTime.inMicroseconds}μs, found ${airports.length} airports');
    
    return airports;
  }

  /// Get airport by ICAO code (O(1) lookup)
  Airport? getAirportByIcao(String icao) {
    return _airportCache[icao];
  }

  /// Clear the spatial index
  void clearIndex() {
    _spatialIndex.clear();
    _airportCache.clear();
    _isIndexBuilt = false;
    notifyListeners();
  }

  bool _shouldShowAirportAtZoom(Airport airport, double zoom) {
    switch (airport.type.toLowerCase()) {
      case 'large_airport':
        return true; // Always show
      case 'medium_airport':
        return zoom >= 7;
      case 'small_airport':
        return zoom >= 9;
      case 'heliport':
        return zoom >= 11;
      case 'seaplane_base':
        return zoom >= 10;
      default:
        return zoom >= 10;
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  int get indexedAirportCount => _allAirports.length;
  bool get isIndexBuilt => _isIndexBuilt;
}

/// Adapter to make Airport work with spatial index
class AirportAdapter implements SpatialIndexable {
  final Airport airport;

  AirportAdapter(this.airport);

  @override
  LatLngBounds? get boundingBox {
    // Airports are points, so create a small bounding box
    const delta = 0.001; // ~111m
    return LatLngBounds(
      LatLng(airport.position.latitude - delta, airport.position.longitude - delta),
      LatLng(airport.position.latitude + delta, airport.position.longitude + delta),
    );
  }

  @override
  bool containsPoint(LatLng point) {
    // For airports, check if point is very close (within ~100m)
    const threshold = 0.001;
    return (airport.position.latitude - point.latitude).abs() < threshold &&
           (airport.position.longitude - point.longitude).abs() < threshold;
  }
}