import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/flight_plan.dart';
import 'offline_map_service.dart';
import '../screens/offline_data/controllers/offline_data_state_controller.dart';

/// Service for downloading map tiles along flight plan routes
class FlightPlanTileDownloadService {
  final OfflineMapService _offlineMapService;
  final OfflineDataStateController _offlineDataController;
  
  FlightPlanTileDownloadService({
    required OfflineMapService offlineMapService,
    required OfflineDataStateController offlineDataController,
  })  : _offlineMapService = offlineMapService,
        _offlineDataController = offlineDataController;

  /// Download tiles for a flight plan route with a buffer
  Future<void> downloadTilesForFlightPlan({
    required FlightPlan flightPlan,
    required BuildContext context,
    double bufferKm = 10.0, // 10km buffer around route
  }) async {
    // Check if the feature is enabled
    if (!_offlineDataController.downloadMapTilesForFlightPlan) {
      return;
    }

    // Check if we have waypoints
    if (flightPlan.waypoints.isEmpty) {
      return;
    }

    // Calculate bounds for the entire route with buffer
    final bounds = _calculateRouteBufferBounds(flightPlan.waypoints, bufferKm);
    
    // Show notification that download is starting
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text('Downloading map tiles for flight plan...'),
              ),
            ],
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.blue,
        ),
      );
    }

    // Start background download
    _downloadInBackground(
      bounds: bounds,
      minZoom: _offlineDataController.minZoom,
      maxZoom: _offlineDataController.maxZoom,
    );
  }

  /// Calculate bounds that include all waypoints with a buffer
  LatLngBounds _calculateRouteBufferBounds(List<Waypoint> waypoints, double bufferKm) {
    if (waypoints.isEmpty) {
      throw ArgumentError('Waypoints list cannot be empty');
    }

    // Find initial bounds
    double minLat = waypoints.first.latitude;
    double maxLat = waypoints.first.latitude;
    double minLng = waypoints.first.longitude;
    double maxLng = waypoints.first.longitude;

    for (final waypoint in waypoints) {
      minLat = min(minLat, waypoint.latitude);
      maxLat = max(maxLat, waypoint.latitude);
      minLng = min(minLng, waypoint.longitude);
      maxLng = max(maxLng, waypoint.longitude);
    }

    // Add buffer in kilometers
    // Approximate conversion: 1 degree latitude = 111 km
    // 1 degree longitude varies by latitude
    final latBuffer = bufferKm / 111.0;
    
    // Calculate longitude buffer based on average latitude
    final avgLat = (minLat + maxLat) / 2;
    final lngBuffer = bufferKm / (111.0 * cos(avgLat * pi / 180));

    // Apply buffer
    minLat -= latBuffer;
    maxLat += latBuffer;
    minLng -= lngBuffer;
    maxLng += lngBuffer;

    // Ensure bounds are within valid ranges
    minLat = max(minLat, -90.0);
    maxLat = min(maxLat, 90.0);
    minLng = max(minLng, -180.0);
    maxLng = min(maxLng, 180.0);

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  /// Download tiles in background without blocking UI
  Future<void> _downloadInBackground({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) async {
    try {
      // Initialize offline map service if needed
      await _offlineMapService.initialize();

      // Start download without progress callback to avoid UI updates
      await _offlineMapService.downloadAreaTiles(
        bounds: bounds,
        minZoom: minZoom,
        maxZoom: maxZoom,
      );
    } catch (e) {
      // Silently handle errors in background download
      debugPrint('Error downloading flight plan tiles: $e');
    }
  }

  /// Calculate estimated number of tiles for a flight plan
  int estimateTilesForFlightPlan(FlightPlan flightPlan, double bufferKm) {
    if (flightPlan.waypoints.isEmpty) {
      return 0;
    }

    final bounds = _calculateRouteBufferBounds(flightPlan.waypoints, bufferKm);
    int totalTiles = 0;

    for (int z = _offlineDataController.minZoom; z <= _offlineDataController.maxZoom; z++) {
      final tileBounds = _getTileBounds(bounds, z);
      final tilesX = tileBounds.maxX - tileBounds.minX + 1;
      final tilesY = tileBounds.maxY - tileBounds.minY + 1;
      totalTiles += tilesX * tilesY;
    }

    return totalTiles;
  }

  /// Get tile bounds for a geographic area at a specific zoom level
  _TileBounds _getTileBounds(LatLngBounds bounds, int zoom) {
    final minTile = _latLngToTile(bounds.southWest, zoom);
    final maxTile = _latLngToTile(bounds.northEast, zoom);
    
    return _TileBounds(
      minX: minTile.x.floor(),
      minY: maxTile.y.floor(),
      maxX: maxTile.x.floor(),
      maxY: minTile.y.floor(),
    );
  }

  /// Convert lat/lng to tile coordinates
  Point<double> _latLngToTile(LatLng latLng, int zoom) {
    final n = pow(2, zoom);
    final x = ((latLng.longitude + 180) / 360) * n;
    final latRad = latLng.latitude * pi / 180;
    final y = (1 - (log(tan(latRad) + (1 / cos(latRad))) / pi)) / 2 * n;
    return Point(x, y);
  }
}

/// Helper class for tile bounds
class _TileBounds {
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  _TileBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
}