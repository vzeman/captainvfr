import 'dart:developer' as developer;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import '../models/obstacle.dart';
import '../models/hotspot.dart';
import '../models/openaip_runway.dart';
import '../models/openaip_frequency.dart';
import 'cache_service.dart';
import 'tiled_data_loader.dart';

class OpenAIPService {
  static final OpenAIPService _instance = OpenAIPService._internal();
  factory OpenAIPService() => _instance;
  OpenAIPService._internal();

  final CacheService _cacheService = CacheService();
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  bool _initialized = false;
  
  // OpenAIP API configuration
  static const String _baseUrl = 'https://api.airlabs.co/v1';
  static const String _openAipBaseUrl = 'https://api.openaip.net';
  static const String OPENAIP_API_KEY = String.fromEnvironment('OPENAIP_API_KEY');
  
  // Rate limiting
  DateTime? _lastApiCall;
  static const Duration _minTimeBetweenCalls = Duration(milliseconds: 100);
  
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
        _reportingPointsInMemory = cachedPoints;
        _reportingPointsLoaded = true;
      } else {
        developer.log(
          '⚠️ No reporting points found in cache. Data will be loaded from tiles on demand.',
        );
      }
      
      // Load airspaces from cache
      final cachedAirspaces = await getCachedAirspaces();
      if (cachedAirspaces.isNotEmpty) {
        developer.log(
          '🌍 Loaded ${cachedAirspaces.length} airspaces from cache',
        );
      } else {
        developer.log(
          '⚠️ No airspaces found in cache. Data will be loaded from tiles on demand.',
        );
      }
      
      // If both cache and tiles are empty, log a warning
      if (cachedPoints.isEmpty && cachedAirspaces.isEmpty) {
        developer.log(
          '⚠️ No offline data found in cache. Make sure aviation data tiles are included in assets.',
        );
      }
    } catch (e) {
      developer.log('❌ Error loading cached data: $e');
      developer.log(
        '⚠️ Will attempt to load data from tiles when needed.',
      );
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
        developer.log(
          '📦 Loaded ${tiledAirspaces.length} airspaces from tiles for area: '
          '[$minLat,$minLon to $maxLat,$maxLon]',
        );
        return tiledAirspaces;
      }
      
      // Fall back to cached data
      developer.log(
        '⚠️ No tiled data found for area, checking cache...',
      );
      final cachedAirspaces = await getCachedAirspaces();
      
      if (cachedAirspaces.isEmpty) {
        developer.log(
          '⚠️ No airspaces found in cache or tiles for area: '
          '[$minLat,$minLon to $maxLat,$maxLon]',
        );
        return [];
      }
      
      final airspacesInArea = cachedAirspaces.where((airspace) {
        // Filter cached airspaces to only those in the requested area
        return airspace.geometry.any(
          (point) =>
              point.latitude >= minLat &&
              point.latitude <= maxLat &&
              point.longitude >= minLon &&
              point.longitude <= maxLon,
        );
      }).toList();
      
      developer.log(
        '📍 Found ${airspacesInArea.length} airspaces in cache for area',
      );
      
      return airspacesInArea;
    } catch (e) {
      developer.log('❌ Error loading airspaces for area: $e');
      developer.log('Stack trace: ${StackTrace.current}');
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
      
      // First try to get from tiled data for a small area around the position
      final buffer = 0.1; // 0.1 degree buffer around position
      final tiledAirspaces = await _tiledDataLoader.loadAirspacesForArea(
        minLat: position.latitude - buffer,
        maxLat: position.latitude + buffer,
        minLon: position.longitude - buffer,
        maxLon: position.longitude + buffer,
      );
      
      // Filter airspaces that contain the position and altitude
      var airspacesAtPosition = tiledAirspaces.where((airspace) {
        final containsPoint = airspace.containsPoint(position);
        final atAltitude = airspace.isAtAltitude(altitudeFt, reference: altitudeReference);
        final isActive = airspace.isActiveAt(DateTime.now());

        return containsPoint && atAltitude && isActive;
      }).toList();
      
      if (airspacesAtPosition.isNotEmpty) {
        return airspacesAtPosition;
      }
      
      // Fall back to cached airspaces if no tiled data
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

        // Update in-memory cache by appending new points
        _reportingPointsInMemory.addAll(reportingPoints);
      } else {
        await _cacheService.cacheReportingPoints(reportingPoints);

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
  
  // ============== OpenAIP Airport/Runway/Frequency API Methods ==============
  
  /// Rate-limited API call helper
  Future<void> _enforceRateLimit() async {
    if (_lastApiCall != null) {
      final timeSinceLastCall = DateTime.now().difference(_lastApiCall!);
      if (timeSinceLastCall < _minTimeBetweenCalls) {
        await Future.delayed(_minTimeBetweenCalls - timeSinceLastCall);
      }
    }
    _lastApiCall = DateTime.now();
  }
  
  /// Get airport details from OpenAIP including runways and frequencies
  Future<Map<String, dynamic>?> getAirportDetails(String icaoCode) async {
    if (OPENAIP_API_KEY.isEmpty) {
      developer.log('⚠️ OpenAIP API key not configured');
      return null;
    }
    
    try {
      await _enforceRateLimit();
      
      final url = Uri.parse('$_openAipBaseUrl/airports/$icaoCode');
      final response = await http.get(
        url,
        headers: {
          'x-openaip-api-key': OPENAIP_API_KEY,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        developer.log('Airport $icaoCode not found in OpenAIP');
        return null;
      } else {
        developer.log('Error fetching airport $icaoCode: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      developer.log('❌ Error fetching OpenAIP airport details for $icaoCode: $e');
      return null;
    }
  }
  
  /// Get runways for an airport from OpenAIP
  Future<List<OpenAIPRunway>> getAirportRunways(String icaoCode) async {
    try {
      final airportDetails = await getAirportDetails(icaoCode);
      if (airportDetails == null) return [];
      
      final runwaysData = airportDetails['runways'] as List<dynamic>?;
      if (runwaysData == null) return [];
      
      return runwaysData
          .map((runway) => OpenAIPRunway.fromJson(runway as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('❌ Error parsing OpenAIP runways for $icaoCode: $e');
      return [];
    }
  }
  
  /// Get frequencies for an airport from OpenAIP
  Future<List<OpenAIPFrequency>> getAirportFrequencies(String icaoCode) async {
    try {
      final airportDetails = await getAirportDetails(icaoCode);
      if (airportDetails == null) return [];
      
      final frequenciesData = airportDetails['frequencies'] as List<dynamic>?;
      if (frequenciesData == null) return [];
      
      return frequenciesData
          .map((freq) => OpenAIPFrequency.fromJson(
                freq as Map<String, dynamic>,
                icaoCode,
              ))
          .toList();
    } catch (e) {
      developer.log('❌ Error parsing OpenAIP frequencies for $icaoCode: $e');
      return [];
    }
  }
  
  /// Get all airports in a bounding box from OpenAIP
  Future<List<Map<String, dynamic>>> getAirportsInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    int limit = 100,
  }) async {
    if (OPENAIP_API_KEY.isEmpty) {
      developer.log('⚠️ OpenAIP API key not configured');
      return [];
    }
    
    try {
      await _enforceRateLimit();
      
      // OpenAIP API endpoint for searching airports in bounds
      final url = Uri.parse('$_openAipBaseUrl/airports').replace(
        queryParameters: {
          'bbox': '$minLon,$minLat,$maxLon,$maxLat',
          'limit': limit.toString(),
        },
      );
      
      final response = await http.get(
        url,
        headers: {
          'x-openaip-api-key': OPENAIP_API_KEY,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['items'] is List) {
          return (data['items'] as List).cast<Map<String, dynamic>>();
        }
      } else {
        developer.log('Error fetching airports in bounds: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Error fetching OpenAIP airports in bounds: $e');
    }
    
    return [];
  }
  
  /// Load OpenAIP runways from tiled data
  Future<List<OpenAIPRunway>> loadOpenAIPRunwaysForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    try {
      final runwayData = await _tiledDataLoader.loadOpenAIPRunwaysForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      // Convert to OpenAIPRunway objects
      final runways = <OpenAIPRunway>[];
      for (final data in runwayData) {
        try {
          final runway = OpenAIPRunway.fromJson(data);
          runways.add(runway);
        } catch (e) {
          // Skip malformed runway data
        }
      }
      
      developer.log('📦 Loaded ${runways.length} OpenAIP runways from tiles for area: [$minLat,$minLon to $maxLat,$maxLon]');
      return runways;
    } catch (e) {
      developer.log('❌ Error loading OpenAIP runways from tiles: $e');
      return [];
    }
  }
  
  /// Load OpenAIP frequencies from tiled data
  Future<List<OpenAIPFrequency>> loadOpenAIPFrequenciesForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    try {
      final frequencyData = await _tiledDataLoader.loadOpenAIPFrequenciesForArea(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      
      // Convert to OpenAIPFrequency objects
      final frequencies = <OpenAIPFrequency>[];
      for (final data in frequencyData) {
        try {
          final frequency = OpenAIPFrequency.fromJson(
            data,
            data['airport_ident'] ?? '',
          );
          frequencies.add(frequency);
        } catch (e) {
          // Skip malformed frequency data
        }
      }
      
      developer.log('📦 Loaded ${frequencies.length} OpenAIP frequencies from tiles for area: [$minLat,$minLon to $maxLat,$maxLon]');
      return frequencies;
    } catch (e) {
      developer.log('❌ Error loading OpenAIP frequencies from tiles: $e');
      return [];
    }
  }
}
