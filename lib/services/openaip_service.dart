import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import 'cache_service.dart';

class OpenAIPService {
  static final OpenAIPService _instance = OpenAIPService._internal();
  factory OpenAIPService() => _instance;
  OpenAIPService._internal();

  static const String _baseUrl = 'https://api.core.openaip.net/api';
  static const String _airspacesEndpoint = '/airspaces';
  static const String _reportingPointsEndpoint = '/reporting-points';
  
  final CacheService _cacheService = CacheService();
  String? _apiKey;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final settingsBox = await Hive.openBox('settings');
      final storedApiKey = settingsBox.get('openaip_api_key', defaultValue: '');
      if (storedApiKey.isNotEmpty) {
        _apiKey = storedApiKey;
        developer.log('✅ OpenAIP API key loaded from storage: ${storedApiKey.substring(0, 4)}... (${storedApiKey.length} chars)');
        
        // Load reporting points and airspaces on startup if cache is empty
        await _initializeReportingPoints();
        await _initializeAirspaces();
      } else {
        developer.log('⚠️ No OpenAIP API key found in storage');
      }
      _initialized = true;
    } catch (e) {
      developer.log('❌ Error loading OpenAIP API key from storage: $e');
    }
  }
  
  Future<void> _initializeReportingPoints() async {
    try {
      final cachedPoints = await getCachedReportingPoints();
      if (cachedPoints.isEmpty) {
        developer.log('📍 No cached reporting points found, loading all from API...');
        await fetchAllReportingPoints();
      } else {
        developer.log('✅ Found ${cachedPoints.length} cached reporting points, skipping API load');
      }
    } catch (e) {
      developer.log('❌ Error initializing reporting points: $e');
    }
  }
  
  Future<void> _initializeAirspaces() async {
    try {
      final cachedAirspaces = await getCachedAirspaces();
      if (cachedAirspaces.isEmpty) {
        developer.log('🌍 No cached airspaces found, loading all from API...');
        // fetchAllAirspaces already handles caching internally
        await fetchAllAirspaces();
      } else {
        developer.log('✅ Found ${cachedAirspaces.length} cached airspaces, skipping API load');
      }
    } catch (e) {
      developer.log('❌ Error initializing airspaces: $e');
    }
  }

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
    developer.log('✅ OpenAIP API key set: ${apiKey.isNotEmpty ? "Yes (${apiKey.length} chars)" : "Empty"}');
  }
  
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  
  String? get apiKey => _apiKey;

  Future<List<Airspace>> _fetchAirspacesRaw({
    LatLng? position,
    double? distanceNm,
    String? country,
    String? type,
    String? icaoClass,
    String? activity,
    List<double>? bbox,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      if (_apiKey == null || _apiKey!.isEmpty) {
        developer.log('❌ OpenAIP API key not set for airspaces');
        return getCachedAirspaces();
      }
      
      developer.log('🌍 Fetching airspaces - Page: $page, Limit: $limit${bbox != null ? ', BBox: $bbox' : ''}${position != null && distanceNm != null ? ', Position: ${position.latitude},${position.longitude}, Distance: ${distanceNm}nm' : ''}${country != null ? ', Country: $country' : ''}${type != null ? ', Type: $type' : ''}');

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (position != null && distanceNm != null) {
        queryParams['pos'] = '${position.latitude},${position.longitude}';
        queryParams['dist'] = distanceNm.toString();
      }

      if (bbox != null && bbox.length == 4) {
        queryParams['bbox'] = bbox.join(',');
      }

      if (country != null) queryParams['country'] = country;
      if (type != null) queryParams['type'] = type;
      if (icaoClass != null) queryParams['icaoClass'] = icaoClass;
      if (activity != null) queryParams['activity'] = activity;

      final uri = Uri.parse('$_baseUrl$_airspacesEndpoint').replace(queryParameters: queryParams);
      developer.log('🌐 API Request URL: $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'x-openaip-api-key': _apiKey!,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? data['data'] ?? data ?? [];
        
        developer.log('📊 API Response structure: ${data.keys.toList()}');
        developer.log('📊 Items count: ${items.length}');
        
        // Log first few IDs to check for issues
        if (items.isNotEmpty) {
          final firstFewIds = items.take(5).map((item) => item['_id'] ?? item['id']).toList();
          developer.log('📊 First few IDs from API: $firstFewIds');
          
          // Log what ID fields are available in first item
          final firstItem = items.first as Map<String, dynamic>;
          developer.log('📊 Available ID fields in first item: ${firstItem.keys.where((k) => k.contains('id') || k.contains('Id')).toList()}');
          
          // Check how many have null/empty IDs
          final emptyIdCount = items.where((item) => 
            (item['_id'] == null || item['_id'].toString().isEmpty) &&
            (item['id'] == null || item['id'].toString().isEmpty)
          ).length;
          if (emptyIdCount > 0) {
            developer.log('⚠️ Found $emptyIdCount items with null/empty IDs out of ${items.length}');
          }
        }
        
        final airspaces = items
            .map((json) => Airspace.fromJson(json))
            .toList();
            
        // Check for duplicate IDs after parsing
        final ids = airspaces.map((a) => a.id).toSet();
        if (ids.length != airspaces.length) {
          developer.log('⚠️ Duplicate IDs found! ${airspaces.length} airspaces but only ${ids.length} unique IDs');
          
          // Find which IDs are duplicated
          final idCounts = <String, int>{};
          for (final airspace in airspaces) {
            idCounts[airspace.id] = (idCounts[airspace.id] ?? 0) + 1;
          }
          final duplicates = idCounts.entries.where((e) => e.value > 1).take(5);
          developer.log('📊 Most duplicated IDs: ${duplicates.map((e) => "${e.key}: ${e.value} times").join(", ")}');
        }

        developer.log('✅ Fetched ${airspaces.length} airspaces from OpenAIP');
        return airspaces;
      } else if (response.statusCode == 429) {
        developer.log('⚠️ Rate limit hit (429). Waiting 60 seconds before retry...');
        await Future.delayed(const Duration(seconds: 60));
        developer.log('🔄 Retrying after rate limit wait...');
        // Recursive retry with same parameters
        return _fetchAirspacesRaw(
          position: position,
          distanceNm: distanceNm,
          country: country,
          type: type,
          icaoClass: icaoClass,
          activity: activity,
          bbox: bbox,
          page: page,
          limit: limit,
        );
      } else {
        developer.log('❌ Failed to fetch airspaces: ${response.statusCode} - ${response.body}');
        return getCachedAirspaces();
      }
    } catch (e) {
      developer.log('❌ Error fetching airspaces from OpenAIP: $e');
      return getCachedAirspaces();
    }
  }

  Future<List<Airspace>> fetchAirspaces({
    LatLng? position,
    double? distanceNm,
    String? country,
    String? type,
    String? icaoClass,
    String? activity,
    List<double>? bbox,
    int page = 1,
    int limit = 100,
  }) async {
    return _fetchAirspacesRaw(
      position: position,
      distanceNm: distanceNm,
      country: country,
      type: type,
      icaoClass: icaoClass,
      activity: activity,
      bbox: bbox,
      page: page,
      limit: limit,
    );
  }

  Future<List<Airspace>> fetchAirspacesInBoundingBox(
    double minLat,
    double minLon,
    double maxLat,
    double maxLon,
  ) async {
    return fetchAirspaces(
      bbox: [minLon, minLat, maxLon, maxLat],
      limit: 500,
    );
  }

  Future<List<Airspace>> fetchAirspacesNearPosition(
    LatLng position, {
    double radiusNm = 50,
  }) async {
    return fetchAirspaces(
      position: position,
      distanceNm: radiusNm,
      limit: 200,
    );
  }

  Future<void> _cacheAirspaces(List<Airspace> airspaces, {bool append = false}) async {
    try {
      if (append) {
        await _cacheService.appendAirspaces(airspaces);
        developer.log('✅ Appended ${airspaces.length} airspaces');
      } else {
        await _cacheService.cacheAirspaces(airspaces);
        developer.log('✅ Cached ${airspaces.length} airspaces');
      }
    } catch (e) {
      developer.log('❌ Error caching airspaces: $e');
    }
  }

  Future<List<Airspace>> getCachedAirspaces() async {
    try {
      final cached = await _cacheService.getCachedAirspaces();
      developer.log('✅ Retrieved ${cached.length} cached airspaces');
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

  Future<List<Airspace>> fetchAllAirspaces() async {
    developer.log('🔄 Fetching all airspaces worldwide using tile-based approach...');
    
    List<Airspace> allAirspaces = [];
    
    // Clear cache at the beginning for a fresh start
    try {
      // First check how many we have before clearing
      final existingCount = (await getCachedAirspaces()).length;
      developer.log('📊 Existing airspaces in cache before clear: $existingCount');
      
      await _cacheService.clearAirspacesCache();
      developer.log('🧹 Cleared airspaces cache for fresh fetch');
      
      // Verify it's actually cleared
      final afterClearCount = (await getCachedAirspaces()).length;
      developer.log('📊 Airspaces in cache after clear: $afterClearCount');
    } catch (e) {
      developer.log('⚠️ Error clearing airspaces cache: $e');
    }
    
    // Split the world into 20 tiles (5x4 grid)
    const int tilesX = 5;
    const int tilesY = 4;
    const double worldWidth = 360.0; // -180 to 180
    const double worldHeight = 180.0; // -90 to 90
    const double tileWidth = worldWidth / tilesX;
    const double tileHeight = worldHeight / tilesY;
    
    int totalTiles = tilesX * tilesY;
    int completedTiles = 0;
    
    // Iterate through each tile
    for (int y = 0; y < tilesY; y++) {
      for (int x = 0; x < tilesX; x++) {
        // Calculate tile boundaries
        double minLon = -180.0 + (x * tileWidth);
        double maxLon = minLon + tileWidth;
        double minLat = -90.0 + (y * tileHeight);
        double maxLat = minLat + tileHeight;
        
        developer.log('🗺️ Fetching tile ${completedTiles + 1}/$totalTiles: [$minLon, $minLat, $maxLon, $maxLat]');
        
        try {
          // Fetch airspaces for this tile with pagination
          int page = 1;
          bool hasMore = true;
          int tileAirspaces = 0;
          List<Airspace> tileAirspacesList = [];
          
          while (hasMore) {
            final airspaces = await _fetchAirspacesRaw(
              bbox: [minLon, minLat, maxLon, maxLat],
              page: page,
              limit: 1000, // Maximum allowed by API
            );
            
            if (airspaces.isEmpty) {
              hasMore = false;
            } else {
              allAirspaces.addAll(airspaces);
              tileAirspacesList.addAll(airspaces);
              tileAirspaces += airspaces.length;
              page++;
              
              // Small delay between pages
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }
          
          completedTiles++;
          developer.log('✅ Tile $completedTiles/$totalTiles completed with $tileAirspaces airspaces (total: ${allAirspaces.length})');
          
          // Append airspaces from this tile to cache (don't clear existing ones)
          if (tileAirspacesList.isNotEmpty) {
            await _cacheAirspaces(tileAirspacesList, append: true);
            developer.log('💾 Appended $tileAirspaces airspaces from tile $completedTiles');
          }
          
          // Delay between tiles to avoid rate limiting
          await Future.delayed(const Duration(seconds: 1));
          
        } catch (e) {
          developer.log('❌ Error fetching tile ${completedTiles + 1}/$totalTiles: $e');
          // Continue with next tile even if one fails
          completedTiles++;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    
    developer.log('✅ Completed fetching airspaces: ${allAirspaces.length} total from $completedTiles tiles');
    
    // Final verification of what's in cache
    try {
      final finalCachedCount = (await getCachedAirspaces()).length;
      developer.log('📊 Final count in cache: $finalCachedCount');
      
      if (finalCachedCount != allAirspaces.length) {
        developer.log('⚠️ Mismatch! Fetched ${allAirspaces.length} but cache has $finalCachedCount');
        
        // Try one final cache update with all airspaces
        if (allAirspaces.isNotEmpty) {
          developer.log('🔄 Attempting final cache update with all ${allAirspaces.length} airspaces...');
          await _cacheAirspaces(allAirspaces, append: false);
          
          final afterFinalUpdate = (await getCachedAirspaces()).length;
          developer.log('📊 Cache count after final update: $afterFinalUpdate');
        }
      }
    } catch (e) {
      developer.log('❌ Error during final cache verification: $e');
    }
    
    return allAirspaces;
  }

  Future<void> refreshAirspacesCache({
    LatLng? centerPosition,
    double? radiusNm,
  }) async {
    try {
      // Always fetch all airspaces when refresh is requested
      final airspaces = await fetchAllAirspaces();
      
      if (airspaces.isNotEmpty) {
        developer.log('✅ Refreshed airspaces cache with ${airspaces.length} items');
      }
    } catch (e) {
      developer.log('❌ Error refreshing airspaces cache: $e');
    }
  }

  // Reporting Points Methods

  Future<List<ReportingPoint>> _fetchReportingPointsRaw({
    LatLng? position,
    double? distanceM,
    String? country,
    String? airport,
    List<double>? bbox,
    int page = 1,
    int limit = 1000,
  }) async {
    try {
      if (_apiKey == null || _apiKey!.isEmpty) {
        developer.log('❌ OpenAIP API key not set for reporting points');
        return getCachedReportingPoints();
      }
      
      developer.log('📍 Fetching reporting points - Page: $page, Limit: $limit${bbox != null ? ', BBox: $bbox' : ''}${position != null && distanceM != null ? ', Position: ${position.latitude},${position.longitude}, Distance: ${distanceM}m' : ''}${country != null ? ', Country: $country' : ''}${airport != null ? ', Airport: $airport' : ''}');

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (position != null && distanceM != null) {
        queryParams['pos'] = '${position.latitude},${position.longitude}';
        queryParams['dist'] = distanceM.toString();
      }

      if (bbox != null && bbox.length == 4) {
        queryParams['bbox'] = bbox.join(',');
      }

      if (country != null) queryParams['country'] = country;
      if (airport != null) queryParams['airport'] = airport;

      final uri = Uri.parse('$_baseUrl$_reportingPointsEndpoint').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'x-openaip-api-key': _apiKey!,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? data['data'] ?? data ?? [];
        
        final reportingPoints = items
            .map((json) => ReportingPoint.fromJson(json))
            .toList();

        if (reportingPoints.isNotEmpty) {
          await _cacheReportingPoints(reportingPoints);
        }

        developer.log('✅ Fetched ${reportingPoints.length} reporting points from OpenAIP');
        return reportingPoints;
      } else if (response.statusCode == 429) {
        developer.log('⚠️ Rate limit hit (429). Waiting 60 seconds before retry...');
        await Future.delayed(const Duration(seconds: 60));
        developer.log('🔄 Retrying after rate limit wait...');
        // Recursive retry with same parameters
        return _fetchReportingPointsRaw(
          position: position,
          distanceM: distanceM,
          country: country,
          airport: airport,
          bbox: bbox,
          page: page,
          limit: limit,
        );
      } else {
        developer.log('❌ Failed to fetch reporting points: ${response.statusCode} - ${response.body}');
        return getCachedReportingPoints();
      }
    } catch (e) {
      developer.log('❌ Error fetching reporting points from OpenAIP: $e');
      return getCachedReportingPoints();
    }
  }

  Future<List<ReportingPoint>> fetchReportingPoints({
    LatLng? position,
    double? distanceM,
    String? country,
    String? airport,
    List<double>? bbox,
    int page = 1,
    int limit = 1000,
  }) async {
    return _fetchReportingPointsRaw(
      position: position,
      distanceM: distanceM,
      country: country,
      airport: airport,
      bbox: bbox,
      page: page,
      limit: limit,
    );
  }

  Future<List<ReportingPoint>> fetchAllReportingPoints() async {
    developer.log('🔄 Fetching all reporting points worldwide using tile-based approach...');
    
    List<ReportingPoint> allPoints = [];
    
    // Clear cache at the beginning for a fresh start
    try {
      await _cacheService.clearReportingPointsCache();
      developer.log('🧹 Cleared reporting points cache for fresh fetch');
    } catch (e) {
      developer.log('⚠️ Error clearing reporting points cache: $e');
    }
    
    // Split the world into 20 tiles (5x4 grid)
    const int tilesX = 5;
    const int tilesY = 4;
    const double worldWidth = 360.0; // -180 to 180
    const double worldHeight = 180.0; // -90 to 90
    const double tileWidth = worldWidth / tilesX;
    const double tileHeight = worldHeight / tilesY;
    
    int totalTiles = tilesX * tilesY;
    int completedTiles = 0;
    
    // Iterate through each tile
    for (int y = 0; y < tilesY; y++) {
      for (int x = 0; x < tilesX; x++) {
        // Calculate tile boundaries
        double minLon = -180.0 + (x * tileWidth);
        double maxLon = minLon + tileWidth;
        double minLat = -90.0 + (y * tileHeight);
        double maxLat = minLat + tileHeight;
        
        developer.log('🗺️ Fetching tile ${completedTiles + 1}/$totalTiles: [$minLon, $minLat, $maxLon, $maxLat]');
        
        try {
          // Fetch reporting points for this tile with pagination
          int page = 1;
          bool hasMore = true;
          int tilePoints = 0;
          List<ReportingPoint> tilePointsList = [];
          
          while (hasMore) {
            final points = await _fetchReportingPointsRaw(
              bbox: [minLon, minLat, maxLon, maxLat],
              page: page,
              limit: 1000, // Maximum allowed by API
            );
            
            if (points.isEmpty) {
              hasMore = false;
            } else {
              allPoints.addAll(points);
              tilePointsList.addAll(points);
              tilePoints += points.length;
              page++;
              
              // Small delay between pages
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }
          
          completedTiles++;
          developer.log('✅ Tile $completedTiles/$totalTiles completed with $tilePoints reporting points (total: ${allPoints.length})');
          
          // Append reporting points from this tile to cache (don't clear existing ones)
          if (tilePointsList.isNotEmpty) {
            await _cacheReportingPoints(tilePointsList, append: true);
            developer.log('💾 Appended $tilePoints reporting points from tile $completedTiles');
          }
          
          // Delay between tiles to avoid rate limiting
          await Future.delayed(const Duration(seconds: 1));
          
        } catch (e) {
          developer.log('❌ Error fetching tile ${completedTiles + 1}/$totalTiles: $e');
          // Continue with next tile even if one fails
          completedTiles++;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    
    developer.log('✅ Completed fetching reporting points: ${allPoints.length} total from $completedTiles tiles');
    
    return allPoints;
  }

  Future<List<ReportingPoint>> fetchReportingPointsInBoundingBox(
    double minLat,
    double minLon,
    double maxLat,
    double maxLon,
  ) async {
    return fetchReportingPoints(
      bbox: [minLon, minLat, maxLon, maxLat],
      limit: 1000, // Maximum allowed by API
    );
  }

  Future<List<ReportingPoint>> fetchReportingPointsNearPosition(
    LatLng position, {
    double radiusM = 50000, // 50km default
  }) async {
    return fetchReportingPoints(
      position: position,
      distanceM: radiusM,
      limit: 500,
    );
  }

  Future<void> _cacheReportingPoints(List<ReportingPoint> reportingPoints, {bool append = false}) async {
    try {
      if (append) {
        await _cacheService.appendReportingPoints(reportingPoints);
        developer.log('✅ Appended ${reportingPoints.length} reporting points');
      } else {
        await _cacheService.cacheReportingPoints(reportingPoints);
        developer.log('✅ Cached ${reportingPoints.length} reporting points');
      }
    } catch (e) {
      developer.log('❌ Error caching reporting points: $e');
    }
  }

  Future<List<ReportingPoint>> getCachedReportingPoints() async {
    try {
      final cached = await _cacheService.getCachedReportingPoints();
      developer.log('✅ Retrieved ${cached.length} cached reporting points');
      return cached;
    } catch (e) {
      developer.log('❌ Error retrieving cached reporting points: $e');
      return [];
    }
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

  Future<void> refreshReportingPointsCache({bool forceRefresh = false}) async {
    try {
      // Always fetch all reporting points when refresh is requested
      final reportingPoints = await fetchAllReportingPoints();
      
      if (reportingPoints.isNotEmpty) {
        developer.log('✅ Refreshed reporting points cache with ${reportingPoints.length} items');
      }
    } catch (e) {
      developer.log('❌ Error refreshing reporting points cache: $e');
    }
  }
}