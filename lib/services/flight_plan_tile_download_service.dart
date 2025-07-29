import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/flight_plan.dart';
import 'offline_map_service.dart';
import '../screens/offline_data/controllers/offline_data_state_controller.dart';

/// Service for downloading map tiles along flight plan routes
class FlightPlanTileDownloadService {
  static const int maxTilesPerDownload = 5000; // Maximum tiles to download at once
  static const double kmPerLatDegree = 111.0; // Approximate km per degree latitude
  
  final OfflineMapService _offlineMapService;
  final OfflineDataStateController _offlineDataController;
  
  // Track active downloads for cancellation
  final Map<String, CancelableOperation<dynamic>> _activeDownloads = {};
  
  // Download queue to manage multiple requests
  final List<_DownloadRequest> _downloadQueue = [];
  bool _isProcessingQueue = false;
  
  // Error log for user visibility
  final List<String> _errorLog = [];
  List<String> get errorLog => List.unmodifiable(_errorLog);
  
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
    debugPrint('FlightPlanTileDownloadService: downloadTilesForFlightPlan called for ${flightPlan.name}');
    
    // Check if the feature is enabled
    if (!_offlineDataController.downloadMapTilesForFlightPlan) {
      debugPrint('FlightPlanTileDownloadService: Feature is disabled in settings');
      return;
    }

    // Check if we have waypoints
    if (flightPlan.waypoints.isEmpty) {
      debugPrint('FlightPlanTileDownloadService: No waypoints in flight plan');
      return;
    }

    // Estimate tile count first
    final estimatedTiles = estimateTilesForFlightPlan(flightPlan, bufferKm);
    
    // Check if tile count exceeds limit
    if (estimatedTiles > maxTilesPerDownload) {
      if (context.mounted) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Large Download Warning'),
            content: Text(
              'This flight plan requires downloading approximately $estimatedTiles map tiles, '
              'which exceeds the recommended limit of $maxTilesPerDownload tiles. '
              'This may take a long time and use significant storage space.\n\n'
              'Do you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        
        if (result != true) {
          return;
        }
      }
    }

    // Calculate bounds for the entire route with buffer
    final bounds = _calculateRouteBufferBounds(flightPlan.waypoints, bufferKm);
    
    // Show notification that download is starting
    debugPrint('FlightPlanTileDownloadService: Showing download notification for $estimatedTiles tiles');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Downloading $estimatedTiles map tiles for flight plan...'),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      debugPrint('FlightPlanTileDownloadService: Context not mounted, cannot show notification');
    }

    // Add to download queue
    _addToQueue(_DownloadRequest(
      flightPlanId: flightPlan.id,
      bounds: bounds,
      minZoom: _offlineDataController.minZoom,
      maxZoom: _offlineDataController.maxZoom,
    ));
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
    final latBuffer = bufferKm / kmPerLatDegree;
    
    // Calculate longitude buffer based on average latitude
    final avgLat = (minLat + maxLat) / 2;
    final lngBuffer = bufferKm / (kmPerLatDegree * cos(avgLat * pi / 180));

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
    required String flightPlanId,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) async {
    // Cancel any existing download for this flight plan
    await cancelDownload(flightPlanId);
    
    // Create cancelable operation
    final completer = CancelableCompleter<Map<String, int>>();
    _activeDownloads[flightPlanId] = completer.operation;
    
    try {
      // Initialize offline map service if needed
      await _offlineMapService.initialize();

      // Start download without progress callback to avoid UI updates
      final downloadFuture = _offlineMapService.downloadAreaTiles(
        bounds: bounds,
        minZoom: minZoom,
        maxZoom: maxZoom,
      );
      
      // Make the download cancelable
      completer.complete(downloadFuture);
      await completer.operation.value;
      
    } catch (e) {
      final errorMessage = 'Error downloading tiles for flight plan $flightPlanId: $e';
      debugPrint(errorMessage);
      _addError(errorMessage);
      
      // Check if it was cancelled
      if (completer.isCanceled) {
        debugPrint('Download cancelled for flight plan $flightPlanId');
      }
    } finally {
      _activeDownloads.remove(flightPlanId);
    }
  }
  
  /// Cancel a download for a specific flight plan
  Future<void> cancelDownload(String flightPlanId) async {
    final operation = _activeDownloads[flightPlanId];
    if (operation != null) {
      operation.cancel();
      _activeDownloads.remove(flightPlanId);
    }
  }
  
  /// Cancel all active downloads
  Future<void> cancelAllDownloads() async {
    // Cancel active downloads
    for (final operation in _activeDownloads.values) {
      operation.cancel();
    }
    _activeDownloads.clear();
    
    // Clear the download queue
    _downloadQueue.clear();
    _isProcessingQueue = false;
  }
  
  /// Add error to log with timestamp
  void _addError(String error) {
    final timestamp = DateTime.now().toIso8601String();
    _errorLog.add('$timestamp: $error');
    
    // Keep only last 50 errors
    if (_errorLog.length > 50) {
      _errorLog.removeAt(0);
    }
  }
  
  /// Clear error log
  void clearErrorLog() {
    _errorLog.clear();
  }
  
  /// Validate that all tiles are downloaded for saved flight plans
  Future<List<FlightPlanValidationResult>> validateAllFlightPlans(List<FlightPlan> flightPlans) async {
    debugPrint('FlightPlanTileDownloadService: Validating ${flightPlans.length} flight plans');
    final results = <FlightPlanValidationResult>[];
    
    // Only validate if the feature is enabled
    if (!_offlineDataController.downloadMapTilesForFlightPlan) {
      debugPrint('FlightPlanTileDownloadService: Validation skipped - download feature is disabled');
      return results;
    }
    
    for (final flightPlan in flightPlans) {
      if (flightPlan.waypoints.isEmpty) {
        continue;
      }
      
      try {
        final bounds = _calculateRouteBufferBounds(flightPlan.waypoints, 10.0);
        final missingTiles = await _checkMissingTiles(
          bounds: bounds,
          minZoom: _offlineDataController.minZoom,
          maxZoom: _offlineDataController.maxZoom,
        );
        
        if (missingTiles > 0) {
          results.add(FlightPlanValidationResult(
            flightPlan: flightPlan,
            missingTiles: missingTiles,
            totalTiles: estimateTilesForFlightPlan(flightPlan, 10.0),
          ));
        }
      } catch (e) {
        debugPrint('Error validating flight plan ${flightPlan.name}: $e');
      }
    }
    
    return results;
  }
  
  /// Check how many tiles are missing for a given area
  Future<int> _checkMissingTiles({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) async {
    int missingCount = 0;
    
    try {
      await _offlineMapService.initialize();
      
      // Check each zoom level
      for (int z = minZoom; z <= maxZoom; z++) {
        final tileBounds = _getTileBounds(bounds, z);
        
        for (int x = tileBounds.minX; x <= tileBounds.maxX; x++) {
          for (int y = tileBounds.minY; y <= tileBounds.maxY; y++) {
            // Check if tile exists in cache
            final exists = await _offlineMapService.hasTile(z, x, y);
            if (!exists) {
              missingCount++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking missing tiles: $e');
    }
    
    return missingCount;
  }
  
  /// Add download request to queue and process it
  void _addToQueue(_DownloadRequest request) {
    debugPrint('FlightPlanTileDownloadService: Adding download request to queue');
    
    // Check if this flight plan is already in queue
    final existingIndex = _downloadQueue.indexWhere((r) => r.flightPlanId == request.flightPlanId);
    if (existingIndex != -1) {
      // Replace existing request with new one
      _downloadQueue[existingIndex] = request;
    } else {
      _downloadQueue.add(request);
    }
    
    debugPrint('FlightPlanTileDownloadService: Queue size: ${_downloadQueue.length}, Processing: $_isProcessingQueue');
    
    // Start processing queue if not already running
    if (!_isProcessingQueue) {
      _processQueue();
    }
  }
  
  /// Process download queue sequentially
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _downloadQueue.isEmpty) {
      return;
    }
    
    debugPrint('FlightPlanTileDownloadService: Starting queue processing');
    _isProcessingQueue = true;
    
    try {
      while (_downloadQueue.isNotEmpty) {
        final request = _downloadQueue.removeAt(0);
        debugPrint('FlightPlanTileDownloadService: Processing download for flight plan ${request.flightPlanId}');
        
        // Skip if already downloading
        if (_activeDownloads.containsKey(request.flightPlanId)) {
          debugPrint('FlightPlanTileDownloadService: Skipping - already downloading');
          continue;
        }
        
        await _downloadInBackground(
          flightPlanId: request.flightPlanId,
          bounds: request.bounds,
          minZoom: request.minZoom,
          maxZoom: request.maxZoom,
        );
      }
    } finally {
      _isProcessingQueue = false;
      debugPrint('FlightPlanTileDownloadService: Queue processing complete');
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

/// Completer that can be cancelled
class CancelableCompleter<T> {
  final _completer = Completer<T>();
  bool _isCanceled = false;
  
  bool get isCanceled => _isCanceled;
  CancelableOperation<T> get operation => CancelableOperation._(_completer.future, this);
  
  void complete([FutureOr<T>? value]) {
    if (!_isCanceled && !_completer.isCompleted) {
      _completer.complete(value);
    }
  }
  
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_isCanceled && !_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
  
  void cancel() {
    _isCanceled = true;
  }
}

/// Operation that can be cancelled
class CancelableOperation<T> {
  final Future<T> _future;
  final CancelableCompleter<T> _completer;
  
  CancelableOperation._(this._future, this._completer);
  
  Future<T> get value => _future;
  
  void cancel() {
    _completer.cancel();
  }
}

/// Download request for queue management
class _DownloadRequest {
  final String flightPlanId;
  final LatLngBounds bounds;
  final int minZoom;
  final int maxZoom;
  
  _DownloadRequest({
    required this.flightPlanId,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
  });
}

/// Result of flight plan tile validation
class FlightPlanValidationResult {
  final FlightPlan flightPlan;
  final int missingTiles;
  final int totalTiles;
  
  FlightPlanValidationResult({
    required this.flightPlan,
    required this.missingTiles,
    required this.totalTiles,
  });
  
  double get percentageMissing => (missingTiles / totalTiles) * 100;
}