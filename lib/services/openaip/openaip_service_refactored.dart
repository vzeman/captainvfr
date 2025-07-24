import 'package:logger/logger.dart';
import 'package:latlong2/latlong.dart';
import '../../models/airspace.dart';
import '../../models/reporting_point.dart';
import '../../models/obstacle.dart';
import '../../models/hotspot.dart';
import '../cache_service.dart';
import '../tiled_data_loader.dart';
import 'api_configuration.dart';
import 'bundled_data_loader.dart';
import 'airspace_repository.dart';
import 'reporting_points_repository.dart';

/// Refactored OpenAIP Service that delegates to specialized components
class OpenAIPService {
  static final OpenAIPService _instance = OpenAIPService._internal();
  factory OpenAIPService() => _instance;
  OpenAIPService._internal();

  final Logger _logger = Logger(level: Level.warning);
  
  // Components
  late final OpenAIPApiConfiguration _apiConfiguration;
  late final BundledDataLoader _bundledDataLoader;
  late final AirspaceRepository _airspaceRepository;
  late final ReportingPointsRepository _reportingPointsRepository;
  
  // Dependencies
  final CacheService _cacheService = CacheService();
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  
  bool _initialized = false;

  /// Check if API key is available
  bool get hasApiKey => _apiConfiguration.hasApiKey;

  /// Check if using default API key
  bool get isUsingDefaultKey => _apiConfiguration.isUsingDefaultKey;

  /// Get the current API key
  String? get apiKey => _apiConfiguration.apiKey;

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize components
      _apiConfiguration = OpenAIPApiConfiguration();
      _bundledDataLoader = BundledDataLoader();
      
      await _apiConfiguration.initialize();
      
      // Initialize repositories
      _airspaceRepository = AirspaceRepository(
        apiConfiguration: _apiConfiguration,
        cacheService: _cacheService,
        tiledDataLoader: _tiledDataLoader,
      );
      
      _reportingPointsRepository = ReportingPointsRepository(
        apiConfiguration: _apiConfiguration,
        cacheService: _cacheService,
        tiledDataLoader: _tiledDataLoader,
      );
      
      // Load bundled data
      final bundledData = await _bundledDataLoader.loadBundledData();
      
      // Add bundled data to repositories
      if (bundledData['airspaces'] != null) {
        _airspaceRepository.addAirspacesToMemory(bundledData['airspaces'] as List<Airspace>);
      }
      
      if (bundledData['reportingPoints'] != null) {
        _reportingPointsRepository.addReportingPointsToMemory(
          bundledData['reportingPoints'] as List<ReportingPoint>
        );
      }
      
      // Initialize repositories in background
      if (_apiConfiguration.hasApiKey) {
        _initializeDataInBackground();
      }
      
      _initialized = true;
      _logger.d('OpenAIP service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize OpenAIP service: $e');
      throw e;
    }
  }

  /// Initialize data in background
  Future<void> _initializeDataInBackground() async {
    // Initialize repositories without blocking
    _airspaceRepository.initialize().catchError((e) {
      _logger.e('Background airspace init error: $e');
    });
    
    _reportingPointsRepository.initialize().catchError((e) {
      _logger.e('Background reporting points init error: $e');
    });
    
    // Start loading all tiles in background after a delay
    Future.delayed(const Duration(seconds: 5), () {
      _loadAllAirspaceTilesInBackground();
      _reportingPointsRepository.loadAllReportingPointsInBackground();
    });
  }

  /// Set API key
  void setApiKey(String apiKey) {
    _apiConfiguration.setApiKey(apiKey);
  }

  // ===== Airspace Methods =====
  
  /// Fetch airspaces from API
  Future<List<Airspace>> fetchAirspaces({
    int page = 1,
    int limit = 100,
    String? country,
    String? type,
    String? icaoClass,
    String? activity,
    List<double>? bbox,
  }) async {
    return _airspaceRepository.fetchAirspaces(
      page: page,
      limit: limit,
      country: country,
      type: type,
      icaoClass: icaoClass,
      activity: activity,
      bbox: bbox,
    );
  }

  /// Get airspaces for a specific area
  Future<List<Airspace>> getAirspacesForArea({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) async {
    return _airspaceRepository.getAirspacesForArea(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
    );
  }

  /// Get airspaces at a specific position
  Future<List<Airspace>> getAirspacesAtPosition(
    LatLng position,
    double altitudeFt, {
    String altitudeReference = 'MSL',
  }) async {
    return _airspaceRepository.getAirspacesAtPosition(
      position,
      altitudeFt,
      altitudeReference: altitudeReference,
    );
  }

  /// Get cached airspaces
  Future<List<Airspace>> getCachedAirspaces() async {
    return _airspaceRepository.getCachedAirspaces();
  }

  // ===== Reporting Points Methods =====
  
  /// Get reporting points in bounds
  List<ReportingPoint> getReportingPointsInBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) {
    return _reportingPointsRepository.getReportingPointsInBounds(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
    );
  }

  /// Load reporting points for area
  Future<List<ReportingPoint>> loadReportingPointsForArea({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) async {
    return _reportingPointsRepository.loadReportingPointsForArea(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
    );
  }

  /// Get cached reporting points
  Future<List<ReportingPoint>> getCachedReportingPoints() async {
    return _reportingPointsRepository.getCachedReportingPoints();
  }

  // ===== Obstacle Methods =====
  
  /// Get obstacles for area (delegated to TiledDataLoader)
  Future<List<Obstacle>> getObstaclesForArea({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) async {
    try {
      return await _tiledDataLoader.loadObstaclesForArea(
        minLat: minLat,
        minLon: minLon,
        maxLat: maxLat,
        maxLon: maxLon,
      );
    } catch (e) {
      _logger.e('Failed to load obstacles: $e');
      return [];
    }
  }

  // ===== Hotspot Methods =====
  
  /// Get hotspots for area (delegated to TiledDataLoader)
  Future<List<Hotspot>> getHotspotsForArea({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) async {
    try {
      return await _tiledDataLoader.loadHotspotsForArea(
        minLat: minLat,
        minLon: minLon,
        maxLat: maxLat,
        maxLon: maxLon,
      );
    } catch (e) {
      _logger.e('Failed to load hotspots: $e');
      return [];
    }
  }

  // ===== Background Loading =====
  
  /// Load all airspace tiles in background
  Future<void> _loadAllAirspaceTilesInBackground() async {
    try {
      // Load airspaces for the entire world in chunks
      const chunkSize = 30.0; // degrees
      
      for (double lat = -90; lat < 90; lat += chunkSize) {
        for (double lon = -180; lon < 180; lon += chunkSize) {
          await _airspaceRepository.getAirspacesForArea(
            minLat: lat,
            minLon: lon,
            maxLat: (lat + chunkSize).clamp(-90.0, 90.0),
            maxLon: (lon + chunkSize).clamp(-180.0, 180.0),
          );
          
          // Small delay to avoid blocking UI
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
      
      _logger.d('Background loading of airspaces completed');
    } catch (e) {
      _logger.e('Error loading airspaces in background: $e');
    }
  }
}