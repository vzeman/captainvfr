import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/reporting_point.dart';
import '../services/openaip_service.dart';
import '../utils/spatial_index.dart';
import 'dart:developer' as developer;

/// High-performance reporting point service using spatial indexing
class SpatialReportingPointService extends ChangeNotifier {
  final OpenAIPService _openAIPService;
  final HybridSpatialIndex _spatialIndex = HybridSpatialIndex();
  final Map<String, ReportingPoint> _reportingPointCache = {};
  
  List<ReportingPoint> _allReportingPoints = [];
  bool _isIndexBuilt = false;
  Timer? _rebuildTimer;
  
  SpatialReportingPointService(this._openAIPService) {
    // Initialize the spatial index
    _initializeIndex();
  }

  @override
  void dispose() {
    _rebuildTimer?.cancel();
    super.dispose();
  }



  Future<void> _initializeIndex() async {
    // Get cached reporting points first
    final reportingPoints = await _openAIPService.getCachedReportingPoints();
    if (reportingPoints.isNotEmpty) {
      _buildIndexFromReportingPoints(reportingPoints);
    }
  }

  void _buildIndexFromReportingPoints(List<ReportingPoint> reportingPoints) {
    final startTime = DateTime.now();
    
    _allReportingPoints = reportingPoints;
    _reportingPointCache.clear();
    
    // Build spatial index and cache
    _spatialIndex.clear();
    for (final point in reportingPoints) {
      _spatialIndex.insert(ReportingPointAdapter(point));
      _reportingPointCache[point.id] = point;
    }
    
    _isIndexBuilt = true;
    
    final duration = DateTime.now().difference(startTime);
    developer.log('✅ Reporting point spatial index built in ${duration.inMilliseconds}ms for ${reportingPoints.length} points');
    
    notifyListeners();
  }

  /// Rebuild the spatial index
  Future<void> rebuildIndex() async {
    if (_allReportingPoints.isEmpty) {
      // Try to get reporting points from service
      final reportingPoints = await _openAIPService.getCachedReportingPoints();
      if (reportingPoints.isNotEmpty) {
        _buildIndexFromReportingPoints(reportingPoints);
      }
    } else {
      _buildIndexFromReportingPoints(_allReportingPoints);
    }
  }

  /// Get reporting points within the specified bounds with ultra-fast spatial queries
  Future<List<ReportingPoint>> getReportingPointsInBounds(
    LatLngBounds bounds, {
    double? zoom,
    bool? compulsoryOnly,
    String? airportIcao,
  }) async {
    if (!_isIndexBuilt) {
      await rebuildIndex();
      if (!_isIndexBuilt) {
        // Fallback to getting all points if index not available
        return _allReportingPoints.where((point) {
          return bounds.contains(point.position);
        }).toList();
      }
    }

    final startTime = DateTime.now();
    
    // Use spatial index for ultra-fast queries
    final adapters = _spatialIndex.search(bounds);
    
    // Extract reporting points and apply filters
    final reportingPoints = adapters
        .whereType<ReportingPointAdapter>()
        .map((adapter) => adapter.reportingPoint)
        .where((point) {
          // Apply compulsory filter if provided
          if (compulsoryOnly == true && 
              point.type?.toUpperCase() != 'COMPULSORY' && 
              point.type?.toUpperCase() != 'MANDATORY') {
            return false;
          }
          
          // Apply airport filter if provided
          if (airportIcao != null && point.airportId != airportIcao) {
            return false;
          }
          
          // Apply zoom-based filtering
          if (zoom != null) {
            return _shouldShowReportingPointAtZoom(point, zoom);
          }
          
          return true;
        })
        .toList();
    
    final queryTime = DateTime.now().difference(startTime);
    developer.log('🚀 Reporting point spatial query completed in ${queryTime.inMicroseconds}μs, found ${reportingPoints.length} points');
    
    return reportingPoints;
  }

  /// Get nearest reporting points to a position
  Future<List<ReportingPoint>> getNearestReportingPoints(
    LatLng point, {
    int limit = 10,
    double maxDistanceKm = 50,
    bool? compulsoryOnly,
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
    final pointsWithDistance = adapters
        .whereType<ReportingPointAdapter>()
        .map((adapter) {
          final reportingPoint = adapter.reportingPoint;
          final distance = _calculateDistance(point, reportingPoint.position);
          return MapEntry(reportingPoint, distance);
        })
        .where((entry) {
          // Apply distance filter
          if (entry.value > maxDistanceKm) return false;
          
          // Apply compulsory filter
          if (compulsoryOnly == true && 
              entry.key.type?.toUpperCase() != 'COMPULSORY' && 
              entry.key.type?.toUpperCase() != 'MANDATORY') {
            return false;
          }
          
          return true;
        })
        .toList();
    
    // Sort by distance
    pointsWithDistance.sort((a, b) => a.value.compareTo(b.value));
    
    // Take requested limit
    final reportingPoints = pointsWithDistance
        .take(limit)
        .map((entry) => entry.key)
        .toList();
    
    final queryTime = DateTime.now().difference(startTime);
    developer.log('🚀 Nearest reporting points query completed in ${queryTime.inMicroseconds}μs, found ${reportingPoints.length} points');
    
    return reportingPoints;
  }

  /// Get reporting points for a specific airport
  List<ReportingPoint> getReportingPointsForAirport(String airportIcao) {
    return _allReportingPoints.where((point) => point.airportId == airportIcao).toList();
  }

  /// Get reporting point by ID (O(1) lookup)
  ReportingPoint? getReportingPointById(String id) {
    return _reportingPointCache[id];
  }

  /// Clear the spatial index
  void clearIndex() {
    _spatialIndex.clear();
    _reportingPointCache.clear();
    _isIndexBuilt = false;
    notifyListeners();
  }

  bool _shouldShowReportingPointAtZoom(ReportingPoint point, double zoom) {
    // Compulsory reporting points show at lower zoom
    if (point.type?.toUpperCase() == 'COMPULSORY' || 
        point.type?.toUpperCase() == 'MANDATORY') {
      return zoom >= 10;
    }
    
    // Non-compulsory points show at higher zoom
    return zoom >= 12;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  int get indexedReportingPointCount => _allReportingPoints.length;
  bool get isIndexBuilt => _isIndexBuilt;
}

/// Adapter to make ReportingPoint work with spatial index
class ReportingPointAdapter implements SpatialIndexable {
  final ReportingPoint reportingPoint;

  ReportingPointAdapter(this.reportingPoint);

  @override
  LatLngBounds? get boundingBox {
    // Reporting points are points, so create a small bounding box
    const delta = 0.001; // ~111m
    return LatLngBounds(
      LatLng(reportingPoint.position.latitude - delta, reportingPoint.position.longitude - delta),
      LatLng(reportingPoint.position.latitude + delta, reportingPoint.position.longitude + delta),
    );
  }

  @override
  bool containsPoint(LatLng point) {
    // For reporting points, check if point is very close (within ~100m)
    const threshold = 0.001;
    return (reportingPoint.position.latitude - point.latitude).abs() < threshold &&
           (reportingPoint.position.longitude - point.longitude).abs() < threshold;
  }
}