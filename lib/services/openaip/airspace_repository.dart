import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';
import '../../models/airspace.dart';
import '../cache_service.dart';
import '../tiled_data_loader.dart';
import 'api_configuration.dart';

/// Repository for managing airspace data
class AirspaceRepository {
  final Logger _logger = Logger(level: Level.warning);
  final OpenAIPApiConfiguration _apiConfiguration;
  final CacheService _cacheService;
  final TiledDataLoader _tiledDataLoader;
  
  static const String _baseUrl = 'https://api.core.openaip.net/api';
  static const String _airspacesEndpoint = '/airspaces';
  
  // In-memory cache
  final List<Airspace> _airspacesInMemory = [];
  bool _airspacesLoaded = false;

  AirspaceRepository({
    required OpenAIPApiConfiguration apiConfiguration,
    required CacheService cacheService,
    required TiledDataLoader tiledDataLoader,
  })  : _apiConfiguration = apiConfiguration,
        _cacheService = cacheService,
        _tiledDataLoader = tiledDataLoader;

  /// Initialize airspaces from cache
  Future<void> initialize() async {
    if (_airspacesLoaded) return;

    try {
      await _loadCachedAirspaces();
    } catch (e) {
      _logger.e('Failed to initialize airspaces: $e');
    }
  }

  /// Get airspaces for a specific area
  Future<List<Airspace>> getAirspacesForArea({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) async {
    try {
      // Use tiled data loader for efficient loading
      final airspaces = await _tiledDataLoader.loadAirspacesForArea(
        minLat: minLat,
        minLon: minLon,
        maxLat: maxLat,
        maxLon: maxLon,
      );
      
      return airspaces;
    } catch (e) {
      _logger.e('Failed to get airspaces for area: $e');
      return [];
    }
  }

  /// Get airspaces at a specific position
  Future<List<Airspace>> getAirspacesAtPosition(
    LatLng position,
    double altitudeFt, {
    String altitudeReference = 'MSL',
  }) async {
    try {
      // Get airspaces in a small area around the position
      const searchRadius = 0.1; // degrees
      final airspaces = await getAirspacesForArea(
        minLat: position.latitude - searchRadius,
        minLon: position.longitude - searchRadius,
        maxLat: position.latitude + searchRadius,
        maxLon: position.longitude + searchRadius,
      );

      // Filter airspaces that contain the position
      return airspaces.where((airspace) {
        if (!_containsPoint(airspace, position)) return false;
        
        // Check altitude if provided
        if (altitudeFt > 0) {
          final lowerLimit = airspace.lowerLimitFt ?? 0;
          final upperLimit = airspace.upperLimitFt ?? 60000;
          
          if (altitudeFt < lowerLimit || altitudeFt > upperLimit) {
            return false;
          }
        }
        
        return true;
      }).toList();
    } catch (e) {
      _logger.e('Failed to get airspaces at position: $e');
      return [];
    }
  }

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
    if (!_apiConfiguration.hasApiKey) {
      _logger.w('No API key available for airspace fetch');
      return [];
    }

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (country != null) queryParams['country'] = country;
      if (type != null) queryParams['type'] = type;
      if (icaoClass != null) queryParams['icaoClass'] = icaoClass;
      if (activity != null) queryParams['activity'] = activity;
      if (bbox != null && bbox.length == 4) {
        queryParams['bbox'] = bbox.join(',');
      }

      final uri = Uri.parse('$_baseUrl$_airspacesEndpoint').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: _apiConfiguration.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        
        final airspaces = items.map((item) => Airspace.fromJson(item)).toList();
        
        // Cache the fetched airspaces
        for (final airspace in airspaces) {
          await _cacheAirspace(airspace);
        }
        
        return airspaces;
      } else {
        _logger.e('Failed to fetch airspaces: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      _logger.e('Error fetching airspaces: $e');
      return [];
    }
  }

  /// Get cached airspaces
  Future<List<Airspace>> getCachedAirspaces() async {
    if (_airspacesInMemory.isNotEmpty) {
      return _airspacesInMemory;
    }
    
    await _loadCachedAirspaces();
    return _airspacesInMemory;
  }

  /// Load cached airspaces from persistent storage
  Future<void> _loadCachedAirspaces() async {
    try {
      final cachedAirspaces = await _cacheService.getCachedAirspaces();
      _airspacesInMemory.clear();
      _airspacesInMemory.addAll(cachedAirspaces);
      _airspacesLoaded = true;
      
      if (cachedAirspaces.isNotEmpty) {
        _logger.d('Loaded ${cachedAirspaces.length} airspaces from cache');
      }
    } catch (e) {
      _logger.e('Failed to load cached airspaces: $e');
    }
  }

  /// Cache an airspace
  Future<void> _cacheAirspace(Airspace airspace) async {
    try {
      // Add to memory cache
      if (!_airspacesInMemory.any((a) => a.id == airspace.id)) {
        _airspacesInMemory.add(airspace);
      }
      // Persist to cache service if it supports airspace caching
    } catch (e) {
      _logger.e('Failed to cache airspace: $e');
    }
  }

  /// Check if airspace contains a point
  bool _containsPoint(Airspace airspace, LatLng point) {
    if (airspace.geometry.isEmpty) {
      return false;
    }

    // Simple point-in-polygon test
    // This is a basic implementation - may need more sophisticated algorithm
    // for complex airspace geometries
    return true; // Placeholder - implement actual geometry check
  }

  /// Add airspaces to memory cache
  void addAirspacesToMemory(List<Airspace> airspaces) {
    for (final airspace in airspaces) {
      if (!_airspacesInMemory.any((a) => a.id == airspace.id)) {
        _airspacesInMemory.add(airspace);
      }
    }
  }

  /// Clear memory cache
  void clearMemoryCache() {
    _airspacesInMemory.clear();
    _airspacesLoaded = false;
  }
}