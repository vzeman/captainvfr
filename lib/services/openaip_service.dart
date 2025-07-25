import 'dart:developer' as developer;
import 'package:latlong2/latlong.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import '../models/obstacle.dart';
import '../models/hotspot.dart';
import 'cache_service.dart';
import 'tiled_data_loader.dart';

class OpenAIPService {
  static final OpenAIPService _instance = OpenAIPService._internal();
  factory OpenAIPService() => _instance;
  OpenAIPService._internal();

  final CacheService _cacheService = CacheService();
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  bool _initialized = false;
  
  // In-memory cache for reporting points (similar to airports)
  List<ReportingPoint> _reportingPointsInMemory = [];
  bool _reportingPointsLoaded = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      developer.log('🚀 Initializing OpenAIP service with offline data...');
      
      // Load cached data if available
      await _loadCachedData();
      
      _initialized = true;
      developer.log('✅ OpenAIP service initialized with offline data');
    } catch (e) {
      developer.log('❌ Error initializing OpenAIP service: $e');
    }
  }

  Future<void> _loadCachedData() async {
    try {
      // Load reporting points from cache
      final cachedPoints = await getCachedReportingPoints();
      if (cachedPoints.isNotEmpty) {
        developer.log(
          '📍 Loaded ${cachedPoints.length} reporting points from cache',
        );
      }
      
      // Load airspaces from cache
      final cachedAirspaces = await getCachedAirspaces();
      if (cachedAirspaces.isNotEmpty) {
        developer.log(
          '🌍 Loaded ${cachedAirspaces.length} airspaces from cache',
        );
      }
    } catch (e) {
      developer.log('❌ Error loading cached data: $e');
    }
  }


  // Get airspaces for a specific area using tiled data
  Future<List<Airspace>> getAirspacesForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    try {
      // First try to get from tiled data
      final tiledAirspaces = await _tiledDataLoader.loadAirspacesForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      if (tiledAirspaces.isNotEmpty) {
        return tiledAirspaces;
      }
      
      // Fall back to cached data
      final cachedAirspaces = await getCachedAirspaces();
      return cachedAirspaces.where((airspace) {
        // Filter cached airspaces to only those in the requested area
        return airspace.geometry.any(
          (point) =>
              point.latitude >= minLat &&
              point.latitude <= maxLat &&
              point.longitude >= minLon &&
              point.longitude <= maxLon,
        );
      }).toList();
    } catch (e) {
      developer.log('❌ Error loading airspaces for area: $e');
      return [];
    }
  }


  Future<List<Airspace>> getCachedAirspaces() async {
    try {
      final cached = await _cacheService.getCachedAirspaces();
      return cached;
    } catch (e) {
      developer.log('❌ Error retrieving cached airspaces: $e');
      return [];
    }
  }

  Future<List<Airspace>> searchAirspaces(String query) async {
    try {
      final allAirspaces = await getCachedAirspaces();
      final searchQuery = query.toLowerCase();

      return allAirspaces.where((airspace) {
        return airspace.name.toLowerCase().contains(searchQuery) ||
            (airspace.type?.toLowerCase().contains(searchQuery) ?? false) ||
            (airspace.icaoClass?.toLowerCase().contains(searchQuery) ?? false);
      }).toList();
    } catch (e) {
      developer.log('❌ Error searching airspaces: $e');
      return [];
    }
  }

  Future<List<Airspace>> getAirspacesAtPosition(
    LatLng position,
    double altitudeFt, {
    String altitudeReference = 'MSL',
  }) async {
    try {
      // Ensure the service is initialized
      await initialize();

      final cachedAirspaces = await getCachedAirspaces();

      return cachedAirspaces.where((airspace) {
        return airspace.containsPoint(position) &&
            airspace.isAtAltitude(altitudeFt, reference: altitudeReference) &&
            airspace.isActiveAt(DateTime.now());
      }).toList();
    } catch (e) {
      developer.log('❌ Error getting airspaces at position: $e');
      return [];
    }
  }


  // Progressive loading for airspaces based on current map bounds
  Future<void> loadAirspacesForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    Function()? onDataLoaded,
  }) async {
    try {
      // Use tiled data loader to get airspaces for the area
      final tiledAirspaces = await _tiledDataLoader.loadAirspacesForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      if (tiledAirspaces.isNotEmpty) {
        developer.log(
          '✅ Loaded ${tiledAirspaces.length} airspaces from tiles',
        );
        
        // Cache for offline use
        await _cacheService.cacheAirspaces(tiledAirspaces);
        
        // Notify that new data is available
        onDataLoaded?.call();
      } else {
        // If no tiled data, try cache
        final cachedAirspaces = await getCachedAirspaces();
        if (cachedAirspaces.isNotEmpty) {
          final airspacesInBounds = cachedAirspaces.where((airspace) {
            return airspace.geometry.any(
              (point) =>
                  point.latitude >= minLat &&
                  point.latitude <= maxLat &&
                  point.longitude >= minLon &&
                  point.longitude <= maxLon,
            );
          }).toList();
          
          if (airspacesInBounds.isNotEmpty) {
            developer.log('📍 Found ${airspacesInBounds.length} airspaces in bounds from cache');
            onDataLoaded?.call();
          }
        }
      }
    } catch (e) {
      developer.log('❌ Error loading airspaces for bounds: $e');
    }
  }


  // Progressive loading for reporting points based on current map bounds
  Future<void> loadReportingPointsForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    Function()? onDataLoaded,
  }) async {
    try {
      // Use tiled data loader to get reporting points for the area
      final tiledPoints = await _tiledDataLoader.loadReportingPointsForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      if (tiledPoints.isNotEmpty) {
        developer.log(
          '✅ Loaded ${tiledPoints.length} reporting points from tiles',
        );
        
        // Update in-memory cache
        _reportingPointsInMemory = tiledPoints;
        _reportingPointsLoaded = true;
        
        // Cache for offline use
        await _cacheReportingPoints(tiledPoints, append: false);
        
        // Notify that new data is available
        onDataLoaded?.call();
      } else {
        // If no tiled data, try cache
        final cachedPoints = await getCachedReportingPoints();
        if (cachedPoints.isNotEmpty) {
          onDataLoaded?.call();
        }
      }
    } catch (e) {
      developer.log('❌ Error loading reporting points: $e');
      // Try to load from cache as fallback
      try {
        final cachedPoints = await getCachedReportingPoints();
        if (cachedPoints.isNotEmpty) {
          onDataLoaded?.call();
        }
      } catch (cacheError) {
        developer.log('❌ Error loading from cache: $cacheError');
      }
    }
  }

  // Reporting Points Methods


  Future<void> _cacheReportingPoints(
    List<ReportingPoint> reportingPoints, {
    bool append = false,
  }) async {
    try {
      if (append) {
        await _cacheService.appendReportingPoints(reportingPoints);
        developer.log('✅ Appended ${reportingPoints.length} reporting points');
        
        // Update in-memory cache by appending new points
        _reportingPointsInMemory.addAll(reportingPoints);
      } else {
        await _cacheService.cacheReportingPoints(reportingPoints);
        developer.log('✅ Cached ${reportingPoints.length} reporting points');
        
        // Update in-memory cache completely
        _reportingPointsInMemory = reportingPoints;
        _reportingPointsLoaded = true;
      }
    } catch (e) {
      developer.log('❌ Error caching reporting points: $e');
    }
  }

  Future<List<ReportingPoint>> getCachedReportingPoints() async {
    // Return from memory if already loaded
    if (_reportingPointsLoaded && _reportingPointsInMemory.isNotEmpty) {
      return _reportingPointsInMemory;
    }
    
    try {
      final cached = await _cacheService.getCachedReportingPoints();
      
      // Store in memory for fast access
      _reportingPointsInMemory = cached;
      _reportingPointsLoaded = true;
      
      return cached;
    } catch (e) {
      developer.log('❌ Error retrieving cached reporting points: $e');
      return [];
    }
  }

  /// Get reporting points in bounds - optimized for performance
  List<ReportingPoint> getReportingPointsInBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) {
    // Direct in-memory filtering (similar to airports)
    if (!_reportingPointsLoaded || _reportingPointsInMemory.isEmpty) {
      return [];
    }
    
    return _reportingPointsInMemory.where((point) {
      final lat = point.position.latitude;
      final lng = point.position.longitude;
      return lat >= minLat &&
             lat <= maxLat &&
             lng >= minLon &&
             lng <= maxLon;
    }).toList();
  }

  Future<List<ReportingPoint>> searchReportingPoints(String query) async {
    try {
      final allPoints = await getCachedReportingPoints();
      final searchQuery = query.toLowerCase();

      return allPoints.where((point) {
        return point.name.toLowerCase().contains(searchQuery) ||
            (point.type?.toLowerCase().contains(searchQuery) ?? false) ||
            (point.description?.toLowerCase().contains(searchQuery) ?? false);
      }).toList();
    } catch (e) {
      developer.log('❌ Error searching reporting points: $e');
      return [];
    }
  }

  
  Future<void> loadObstaclesForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    Function()? onDataLoaded,
  }) async {
    try {
      // Use tiled data loader to get obstacles for the area
      final tiledObstacles = await _tiledDataLoader.loadObstaclesForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      if (tiledObstacles.isNotEmpty) {
        developer.log(
          '✅ Loaded ${tiledObstacles.length} obstacles from tiles',
        );
        
        // Notify that new data is available
        onDataLoaded?.call();
      }
    } catch (e) {
      developer.log('❌ Error loading obstacles from tiles: $e');
    }
  }
  
  Future<List<Obstacle>> getObstaclesForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    try {
      // Use tiled data loader to get obstacles for the area
      final tiledObstacles = await _tiledDataLoader.loadObstaclesForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      return tiledObstacles;
    } catch (e) {
      developer.log('❌ Error loading obstacles: $e');
      return [];
    }
  }
  
  Future<void> loadHotspotsForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    Function()? onDataLoaded,
  }) async {
    try {
      // Use tiled data loader to get hotspots for the area
      final tiledHotspots = await _tiledDataLoader.loadHotspotsForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      if (tiledHotspots.isNotEmpty) {
        developer.log(
          '✅ Loaded ${tiledHotspots.length} hotspots from tiles',
        );
        
        // Notify that new data is available
        onDataLoaded?.call();
      }
    } catch (e) {
      developer.log('❌ Error loading hotspots from tiles: $e');
    }
  }
  
  Future<List<Hotspot>> getHotspotsForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    try {
      // Use tiled data loader to get hotspots for the area
      final tiledHotspots = await _tiledDataLoader.loadHotspotsForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      return tiledHotspots;
    } catch (e) {
      developer.log('❌ Error loading hotspots: $e');
      return [];
    }
  }
}
