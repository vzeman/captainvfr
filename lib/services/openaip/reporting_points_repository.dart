import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../../models/reporting_point.dart';
import '../cache_service.dart';
import '../tiled_data_loader.dart';
import 'api_configuration.dart';

/// Repository for managing reporting points data
class ReportingPointsRepository {
  final Logger _logger = Logger(level: Level.warning);
  final OpenAIPApiConfiguration _apiConfiguration;
  final CacheService _cacheService;
  final TiledDataLoader _tiledDataLoader;
  
  static const String _baseUrl = 'https://api.core.openaip.net/api';
  static const String _reportingPointsEndpoint = '/reporting-points';
  
  // In-memory cache for reporting points
  final List<ReportingPoint> _reportingPointsInMemory = [];
  bool _reportingPointsLoaded = false;

  ReportingPointsRepository({
    required OpenAIPApiConfiguration apiConfiguration,
    required CacheService cacheService,
    required TiledDataLoader tiledDataLoader,
  })  : _apiConfiguration = apiConfiguration,
        _cacheService = cacheService,
        _tiledDataLoader = tiledDataLoader;

  /// Initialize reporting points
  Future<void> initialize() async {
    if (_reportingPointsLoaded) return;

    try {
      await _loadCachedReportingPoints();
      
      // Don't load all points at startup - let the map load them progressively
      _logger.d('Reporting points initialized - will load on demand');
    } catch (e) {
      _logger.e('Failed to initialize reporting points: $e');
    }
  }

  /// Get reporting points for a specific area
  List<ReportingPoint> getReportingPointsInBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) {
    // First check memory cache
    if (_reportingPointsInMemory.isNotEmpty) {
      return _reportingPointsInMemory.where((point) {
        return point.latitude >= minLat &&
               point.latitude <= maxLat &&
               point.longitude >= minLon &&
               point.longitude <= maxLon;
      }).toList();
    }
    
    // If no data in memory, return empty list (data will be loaded on demand)
    return [];
  }

  /// Load reporting points from tiled data
  Future<List<ReportingPoint>> loadReportingPointsForArea({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) async {
    try {
      final points = await _tiledDataLoader.loadReportingPointsForArea(
        minLat: minLat,
        minLon: minLon,
        maxLat: maxLat,
        maxLon: maxLon,
      );
      
      // Add to memory cache
      addReportingPointsToMemory(points);
      
      return points;
    } catch (e) {
      _logger.e('Failed to load reporting points for area: $e');
      return [];
    }
  }

  /// Fetch reporting points from API
  Future<List<ReportingPoint>> fetchReportingPoints({
    int page = 1,
    int limit = 100,
    String? country,
    String? type,
    List<double>? bbox,
  }) async {
    if (!_apiConfiguration.hasApiKey) {
      _logger.w('No API key available for reporting points fetch');
      return [];
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (country != null) queryParams['country'] = country;
      if (type != null) queryParams['type'] = type;
      if (bbox != null && bbox.length == 4) {
        queryParams['bbox'] = bbox.join(',');
      }

      final uri = Uri.parse('$_baseUrl$_reportingPointsEndpoint').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: _apiConfiguration.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        
        final points = items.map((item) => ReportingPoint.fromJson(item)).toList();
        
        // Add to memory cache
        addReportingPointsToMemory(points);
        
        return points;
      } else {
        _logger.e('Failed to fetch reporting points: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      _logger.e('Error fetching reporting points: $e');
      return [];
    }
  }

  /// Get cached reporting points
  Future<List<ReportingPoint>> getCachedReportingPoints() async {
    if (_reportingPointsInMemory.isNotEmpty) {
      return _reportingPointsInMemory;
    }
    
    await _loadCachedReportingPoints();
    return _reportingPointsInMemory;
  }

  /// Load cached reporting points from persistent storage
  Future<void> _loadCachedReportingPoints() async {
    try {
      final cachedPoints = await _cacheService.getCachedReportingPoints();
      _reportingPointsInMemory.clear();
      _reportingPointsInMemory.addAll(cachedPoints);
      _reportingPointsLoaded = true;
      
      if (cachedPoints.isNotEmpty) {
        _logger.d('Loaded ${cachedPoints.length} reporting points from cache');
      }
    } catch (e) {
      _logger.e('Failed to load cached reporting points: $e');
    }
  }

  /// Add reporting points to memory cache
  void addReportingPointsToMemory(List<ReportingPoint> points) {
    for (final point in points) {
      if (!_reportingPointsInMemory.any((p) => p.id == point.id)) {
        _reportingPointsInMemory.add(point);
      }
    }
  }

  /// Clear memory cache
  void clearMemoryCache() {
    _reportingPointsInMemory.clear();
    _reportingPointsLoaded = false;
  }

  /// Load all reporting points in background
  Future<void> loadAllReportingPointsInBackground() async {
    try {
      // Load reporting points for the entire world in chunks
      const chunkSize = 30.0; // degrees
      
      for (double lat = -90; lat < 90; lat += chunkSize) {
        for (double lon = -180; lon < 180; lon += chunkSize) {
          await loadReportingPointsForArea(
            minLat: lat,
            minLon: lon,
            maxLat: (lat + chunkSize).clamp(-90.0, 90.0),
            maxLon: (lon + chunkSize).clamp(-180.0, 180.0),
          );
          
          // Small delay to avoid blocking UI
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
      
      _logger.d('Background loading of reporting points completed');
    } catch (e) {
      _logger.e('Error loading reporting points in background: $e');
    }
  }
}