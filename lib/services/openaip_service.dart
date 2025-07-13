import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import '../config/api_config.dart';
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

  /// Check if API key is available (either user-provided or default)
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Check if using default API key
  bool get isUsingDefaultKey => _apiKey == ApiConfig.defaultOpenAipApiKey;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final settingsBox = await Hive.openBox('settings');
      final storedApiKey = settingsBox.get('openaip_api_key', defaultValue: '');

      if (storedApiKey.isNotEmpty) {
        // User has provided their own API key
        _apiKey = storedApiKey;
        developer.log(
          '✅ OpenAIP API key loaded from storage: ${storedApiKey.substring(0, 4)}... (${storedApiKey.length} chars)',
        );
      } else if (ApiConfig.useDefaultApiKey &&
          ApiConfig.defaultOpenAipApiKey != 'YOUR_DEFAULT_API_KEY_HERE') {
        // Use default API key if enabled and configured
        _apiKey = ApiConfig.defaultOpenAipApiKey;
        developer.log('✅ Using default OpenAIP API key');
      } else {
        developer.log('⚠️ No OpenAIP API key configured');
      }

      if (_apiKey != null && _apiKey!.isNotEmpty) {
        // Start loading in background without blocking initialization
        // This allows the map to show immediately
        _initializeDataInBackground();
      }

      _initialized = true;
    } catch (e) {
      developer.log('❌ Error loading OpenAIP API key from storage: $e');
    }
  }

  // Initialize data in background without blocking
  Future<void> _initializeDataInBackground() async {
    // Don't await - let it run truly in background
    // This allows the app to start immediately
    _initializeReportingPoints().catchError((e) {
      developer.log('❌ Background reporting points init error: $e');
    });

    _initializeAirspaces().catchError((e) {
      developer.log('❌ Background airspaces init error: $e');
    });

    // Start loading all tiles in background after a delay
    Future.delayed(const Duration(seconds: 5), () {
      _loadAllAirspaceTilesInBackground();
      _loadAllReportingPointsInBackground();
    });
  }

  Future<void> _initializeReportingPoints() async {
    try {
      final cachedPoints = await getCachedReportingPoints();
      developer.log(
        '📍 Initial cache check: ${cachedPoints.length} reporting points found',
      );

      if (cachedPoints.isEmpty) {
        developer.log(
          '📍 No cached reporting points found, will load progressively as needed',
        );
        // Don't load all points at startup - let the map load them progressively
      } else {
        developer.log('✅ Found ${cachedPoints.length} cached reporting points');
      }
    } catch (e) {
      developer.log('❌ Error checking reporting points cache: $e');
    }
  }

  Future<void> _initializeAirspaces() async {
    try {
      final cachedAirspaces = await getCachedAirspaces();
      if (cachedAirspaces.isEmpty) {
        developer.log(
          '🌍 No cached airspaces found, will load progressively as needed',
        );
        // Don't load all airspaces at startup - let the map load them progressively
        // This allows the app to start immediately
      } else {
        developer.log('✅ Found ${cachedAirspaces.length} cached airspaces');
      }
    } catch (e) {
      developer.log('❌ Error checking airspaces cache: $e');
    }
  }

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
    developer.log(
      '✅ OpenAIP API key set: ${apiKey.isNotEmpty ? "Yes (${apiKey.length} chars)" : "Empty"}',
    );
  }

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

      developer.log(
        '🌍 Fetching airspaces - Page: $page, Limit: $limit${bbox != null ? ', BBox: $bbox' : ''}${position != null && distanceNm != null ? ', Position: ${position.latitude},${position.longitude}, Distance: ${distanceNm}nm' : ''}${country != null ? ', Country: $country' : ''}${type != null ? ', Type: $type' : ''}',
      );

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

      final uri = Uri.parse(
        '$_baseUrl$_airspacesEndpoint',
      ).replace(queryParameters: queryParams);
      developer.log('🌐 API Request URL: $uri');

      final response = await http
          .get(
            uri,
            headers: {
              'x-openaip-api-key': _apiKey!,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? data['data'] ?? data ?? [];

        developer.log('📊 API Response structure: ${data.keys.toList()}');
        developer.log('📊 Items count: ${items.length}');

        // Log first few IDs to check for issues
        if (items.isNotEmpty) {
          final firstFewIds = items
              .take(5)
              .map((item) => item['_id'] ?? item['id'])
              .toList();
          developer.log('📊 First few IDs from API: $firstFewIds');

          // Log what ID fields are available in first item
          final firstItem = items.first as Map<String, dynamic>;
          developer.log(
            '📊 Available ID fields in first item: ${firstItem.keys.where((k) => k.contains('id') || k.contains('Id')).toList()}',
          );

          // Check how many have null/empty IDs
          final emptyIdCount = items
              .where(
                (item) =>
                    (item['_id'] == null || item['_id'].toString().isEmpty) &&
                    (item['id'] == null || item['id'].toString().isEmpty),
              )
              .length;
          if (emptyIdCount > 0) {
            developer.log(
              '⚠️ Found $emptyIdCount items with null/empty IDs out of ${items.length}',
            );
          }
        }

        final airspaces = items.map((json) => Airspace.fromJson(json)).toList();

        // Check for duplicate IDs after parsing
        final ids = airspaces.map((a) => a.id).toSet();
        if (ids.length != airspaces.length) {
          developer.log(
            '⚠️ Duplicate IDs found! ${airspaces.length} airspaces but only ${ids.length} unique IDs',
          );

          // Find which IDs are duplicated
          final idCounts = <String, int>{};
          for (final airspace in airspaces) {
            idCounts[airspace.id] = (idCounts[airspace.id] ?? 0) + 1;
          }
          final duplicates = idCounts.entries.where((e) => e.value > 1).take(5);
          developer.log(
            '📊 Most duplicated IDs: ${duplicates.map((e) => "${e.key}: ${e.value} times").join(", ")}',
          );
        }

        return airspaces;
      } else if (response.statusCode == 429) {
        developer.log(
          '⚠️ Rate limit hit (429). Waiting 60 seconds before retry...',
        );
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
        developer.log(
          '❌ Failed to fetch airspaces: ${response.statusCode} - ${response.body}',
        );
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
    return fetchAirspaces(bbox: [minLon, minLat, maxLon, maxLat], limit: 500);
  }

  Future<List<Airspace>> fetchAirspacesNearPosition(
    LatLng position, {
    double radiusNm = 50,
  }) async {
    return fetchAirspaces(position: position, distanceNm: radiusNm, limit: 200);
  }

  Future<void> _cacheAirspaces(
    List<Airspace> airspaces, {
    bool append = false,
  }) async {
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
    developer.log(
      '🔄 Fetching all airspaces worldwide using tile-based approach...',
    );

    List<Airspace> allAirspaces = [];

    // Clear cache at the beginning for a fresh start
    try {
      // First check how many we have before clearing
      final existingCount = (await getCachedAirspaces()).length;
      developer.log(
        '📊 Existing airspaces in cache before clear: $existingCount',
      );

      await _cacheService.clearAirspacesCache();
      developer.log('🧹 Cleared airspaces cache for fresh fetch');

      // Verify it's actually cleared
      final afterClearCount = (await getCachedAirspaces()).length;
      developer.log('📊 Airspaces in cache after clear: $afterClearCount');
    } catch (e) {
      developer.log('⚠️ Error clearing airspaces cache: $e');
    }

    // Split the world into more tiles to avoid hitting API limits per tile
    // Using 10x8 grid (80 tiles) instead of 5x4 (20 tiles) for better granularity
    const int tilesX = 10;
    const int tilesY = 8;
    const double worldWidth = 360.0; // -180 to 180
    const double worldHeight = 180.0; // -90 to 90
    const double tileWidth = worldWidth / tilesX;
    const double tileHeight = worldHeight / tilesY;

    developer.log(
      '📐 Using ${tilesX}x$tilesY grid (${tilesX * tilesY} tiles) with tile size: $tileWidth° x $tileHeight°',
    );

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

        developer.log(
          '🗺️ Fetching tile ${completedTiles + 1}/$totalTiles: [$minLon, $minLat, $maxLon, $maxLat]',
        );

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
          developer.log(
            '✅ Tile $completedTiles/$totalTiles completed with $tileAirspaces airspaces (total: ${allAirspaces.length})',
          );

          // Append airspaces from this tile to cache (don't clear existing ones)
          if (tileAirspacesList.isNotEmpty) {
            await _cacheAirspaces(tileAirspacesList, append: true);
            developer.log(
              '💾 Appended $tileAirspaces airspaces from tile $completedTiles',
            );
          }

          // Smaller delay between tiles since we're using smaller tiles
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          developer.log(
            '❌ Error fetching tile ${completedTiles + 1}/$totalTiles: $e',
          );
          // Continue with next tile even if one fails
          completedTiles++;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    developer.log(
      '✅ Completed fetching airspaces: ${allAirspaces.length} total from $completedTiles tiles',
    );

    // Final verification of what's in cache
    try {
      final finalCachedCount = (await getCachedAirspaces()).length;

      if (finalCachedCount != allAirspaces.length) {
        // Try one final cache update with all airspaces
        if (allAirspaces.isNotEmpty) {
          developer.log(
            '🔄 Attempting final cache update with all ${allAirspaces.length} airspaces...',
          );
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
        developer.log(
          '✅ Refreshed airspaces cache with ${airspaces.length} items',
        );
      }
    } catch (e) {
      developer.log('❌ Error refreshing airspaces cache: $e');
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
    if (_apiKey == null || _apiKey!.isEmpty) {
      developer.log('❌ No API key for progressive airspace loading');
      return;
    }

    try {
      // Check if we already have data for this area in cache
      final cachedAirspaces = await getCachedAirspaces();

      if (cachedAirspaces.isNotEmpty) {
        final airspacesInBounds = cachedAirspaces.where((airspace) {
          // Simple check if airspace overlaps with bounds
          // This is a simplification - proper polygon intersection would be better
          return airspace.geometry.any(
            (point) =>
                point.latitude >= minLat &&
                point.latitude <= maxLat &&
                point.longitude >= minLon &&
                point.longitude <= maxLon,
          );
        }).toList();

        // If we have some data, use it first
        if (airspacesInBounds.isNotEmpty) {
          developer.log(
            '📦 Found ${airspacesInBounds.length} cached airspaces for bounds',
          );
          onDataLoaded?.call();
          return; // We have data, no need to fetch more for this area
        }
      }

      // Fetch fresh data for this area
      developer.log(
        '🔄 Loading airspaces for bounds: [$minLon, $minLat, $maxLon, $maxLat]',
      );

      final freshAirspaces = await _fetchAirspacesRaw(
        bbox: [minLon, minLat, maxLon, maxLat],
        limit: 1000,
      );

      if (freshAirspaces.isNotEmpty) {
        developer.log(
          '✅ Loaded ${freshAirspaces.length} airspaces for current bounds',
        );

        // Append to cache without clearing existing data
        await _cacheAirspaces(freshAirspaces, append: true);

        // Notify that new data is available
        onDataLoaded?.call();

        // Current tile loaded, all other tiles will be loaded by background process
      }
    } catch (e) {
      developer.log('❌ Error loading airspaces for bounds: $e');
    }
  }

  // Load all airspace tiles in background
  Future<void> _loadAllAirspaceTilesInBackground() async {
    // Check if we already have airspaces cached
    final cachedAirspaces = await getCachedAirspaces();
    if (cachedAirspaces.length > 1000) {
      developer.log(
        '🔄 Already have ${cachedAirspaces.length} airspaces cached, skipping full background load',
      );
      return;
    }

    developer.log('🌍 Starting background loading of ALL airspace tiles...');

    // Use the same tile grid as fetchAllAirspaces
    const int tilesX = 10;
    const int tilesY = 8;
    const double worldWidth = 360.0; // -180 to 180
    const double worldHeight = 180.0; // -90 to 90
    const double tileWidth = worldWidth / tilesX;
    const double tileHeight = worldHeight / tilesY;

    int totalTiles = tilesX * tilesY;
    int completedTiles = 0;
    Set<String> loadedTiles = {}; // Track which tiles we've loaded

    // Get already loaded tiles from cache to avoid re-loading
    final existingAirspaces = await getCachedAirspaces();
    for (final airspace in existingAirspaces) {
      // Determine which tile this airspace belongs to
      if (airspace.geometry.isNotEmpty) {
        final point = airspace.geometry.first;
        final tileX = ((point.longitude + 180) / tileWidth).floor();
        final tileY = ((point.latitude + 90) / tileHeight).floor();
        loadedTiles.add('$tileX,$tileY');
      }
    }

    developer.log(
      '📦 Found ${loadedTiles.length} tiles already loaded in cache',
    );

    // Load tiles in a smart order - start from center and spiral outward
    List<List<int>> tileOrder = [];

    // Create all tile coordinates
    for (int y = 0; y < tilesY; y++) {
      for (int x = 0; x < tilesX; x++) {
        tileOrder.add([x, y]);
      }
    }

    // Sort by distance from center (roughly where most users are)
    tileOrder.sort((a, b) {
      final centerX = tilesX / 2;
      final centerY = tilesY / 2;
      final distA = ((a[0] - centerX).abs() + (a[1] - centerY).abs());
      final distB = ((b[0] - centerX).abs() + (b[1] - centerY).abs());
      return distA.compareTo(distB);
    });

    // Load tiles
    for (final coords in tileOrder) {
      final x = coords[0];
      final y = coords[1];
      final tileKey = '$x,$y';

      // Skip if already loaded
      if (loadedTiles.contains(tileKey)) {
        completedTiles++;
        continue;
      }

      // Calculate tile boundaries
      double minLon = -180.0 + (x * tileWidth);
      double maxLon = minLon + tileWidth;
      double minLat = -90.0 + (y * tileHeight);
      double maxLat = minLat + tileHeight;

      try {
        // Longer delay between tiles to avoid rate limiting
        await Future.delayed(const Duration(seconds: 2));

        developer.log(
          '🗺️ Background loading tile ${completedTiles + 1}/$totalTiles: [$minLon, $minLat, $maxLon, $maxLat]',
        );

        // Fetch with pagination
        int page = 1;
        bool hasMore = true;
        int tileAirspaces = 0;

        while (hasMore) {
          final airspaces = await _fetchAirspacesRaw(
            bbox: [minLon, minLat, maxLon, maxLat],
            page: page,
            limit: 1000,
          );

          if (airspaces.isEmpty) {
            hasMore = false;
          } else {
            await _cacheAirspaces(airspaces, append: true);
            tileAirspaces += airspaces.length;
            page++;

            // Small delay between pages
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        completedTiles++;
        loadedTiles.add(tileKey);

        if (tileAirspaces > 0) {
          developer.log(
            '✅ Background loaded $tileAirspaces airspaces for tile $completedTiles/$totalTiles',
          );
        }

        // Check current cache size periodically
        if (completedTiles % 10 == 0) {
          final currentCache = await getCachedAirspaces();
          developer.log(
            '📊 Progress: $completedTiles/$totalTiles tiles, ${currentCache.length} total airspaces cached',
          );
        }
      } catch (e) {
        developer.log(
          '⚠️ Error loading background tile ${completedTiles + 1}/$totalTiles: $e',
        );
        completedTiles++;
        // Continue with next tile even if one fails
        await Future.delayed(
          const Duration(seconds: 5),
        ); // Longer delay after error
      }
    }

    final finalCache = await getCachedAirspaces();
    developer.log(
      '✅ Completed background loading of ALL tiles! Total airspaces cached: ${finalCache.length}',
    );
  }

  // Load all reporting points in background
  Future<void> _loadAllReportingPointsInBackground() async {
    // Check if we already have points cached
    final cachedPoints = await getCachedReportingPoints();
    if (cachedPoints.length > 1000) {
      developer.log(
        '🔄 Already have ${cachedPoints.length} reporting points cached, skipping full background load',
      );
      return;
    }

    developer.log('📍 Starting background loading of ALL reporting points...');

    // Similar approach but reporting points are global, not tile-based
    // We'll fetch them by country or in chunks
    try {
      // Start with a delay to not conflict with airspace loading
      await Future.delayed(const Duration(seconds: 30));

      developer.log('📍 Fetching all reporting points globally...');
      await fetchAllReportingPoints();

      final finalCache = await getCachedReportingPoints();
      developer.log(
        '✅ Completed background loading of reporting points! Total cached: ${finalCache.length}',
      );
    } catch (e) {
      developer.log('❌ Error in background reporting points load: $e');
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
    if (_apiKey == null || _apiKey!.isEmpty) {
      developer.log('❌ No API key for progressive reporting points loading');
      return;
    }

    try {
      // Check if we already have data for this area in cache
      final cachedPoints = await getCachedReportingPoints();

      if (cachedPoints.isNotEmpty) {
        final pointsInBounds = cachedPoints.where((point) {
          return point.position.latitude >= minLat &&
              point.position.latitude <= maxLat &&
              point.position.longitude >= minLon &&
              point.position.longitude <= maxLon;
        }).toList();

        // If we have some data, use it first
        if (pointsInBounds.isNotEmpty) {
          developer.log(
            '📦 Found ${pointsInBounds.length} cached reporting points for bounds',
          );
          onDataLoaded?.call();
          return; // We have data, no need to fetch more for this area
        }
      }

      final freshPoints = await _fetchReportingPointsRaw(
        bbox: [minLon, minLat, maxLon, maxLat],
        limit: 1000,
      );

      if (freshPoints.isNotEmpty) {
        developer.log(
          '✅ Loaded ${freshPoints.length} reporting points for current bounds',
        );

        // Append to cache without clearing existing data
        await _cacheReportingPoints(freshPoints, append: true);

        // Notify that new data is available
        onDataLoaded?.call();
      }
    } catch (e) {
      developer.log('❌ Error loading reporting points for bounds: $e');
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

      developer.log(
        '📍 Fetching reporting points - Page: $page, Limit: $limit${bbox != null ? ', BBox: $bbox' : ''}${position != null && distanceM != null ? ', Position: ${position.latitude},${position.longitude}, Distance: ${distanceM}m' : ''}${country != null ? ', Country: $country' : ''}${airport != null ? ', Airport: $airport' : ''}',
      );

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

      final uri = Uri.parse(
        '$_baseUrl$_reportingPointsEndpoint',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'x-openaip-api-key': _apiKey!,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? data['data'] ?? data ?? [];

        final reportingPoints = items
            .map((json) => ReportingPoint.fromJson(json))
            .toList();

        // Don't cache here - let the caller decide whether to cache
        // This prevents overwriting the cache when fetching individual tiles

        return reportingPoints;
      } else if (response.statusCode == 429) {
        developer.log(
          '⚠️ Rate limit hit (429). Waiting 60 seconds before retry...',
        );
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
        developer.log(
          '❌ Failed to fetch reporting points: ${response.statusCode} - ${response.body}',
        );
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
    developer.log(
      '🔄 Fetching all reporting points worldwide using tile-based approach...',
    );

    List<ReportingPoint> allPoints = [];

    // Clear cache at the beginning for a fresh start
    try {
      await _cacheService.clearReportingPointsCache();
      developer.log('🧹 Cleared reporting points cache for fresh fetch');
    } catch (e) {
      developer.log('⚠️ Error clearing reporting points cache: $e');
    }

    // Split the world into more tiles to avoid hitting API limits per tile
    // Using 10x8 grid (80 tiles) instead of 5x4 (20 tiles) for better granularity
    const int tilesX = 10;
    const int tilesY = 8;
    const double worldWidth = 360.0; // -180 to 180
    const double worldHeight = 180.0; // -90 to 90
    const double tileWidth = worldWidth / tilesX;
    const double tileHeight = worldHeight / tilesY;

    developer.log(
      '📐 Using ${tilesX}x$tilesY grid (${tilesX * tilesY} tiles) with tile size: $tileWidth° x $tileHeight°',
    );

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

        developer.log(
          '🗺️ Fetching tile ${completedTiles + 1}/$totalTiles: [$minLon, $minLat, $maxLon, $maxLat]',
        );

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
              developer.log(
                '🔍 Tile ${completedTiles + 1}: No more pages after page ${page - 1}',
              );
            } else {
              allPoints.addAll(points);
              tilePointsList.addAll(points);
              tilePoints += points.length;
              developer.log(
                '📊 Tile ${completedTiles + 1}, Page $page: Got ${points.length} points',
              );

              // Check if we got less than limit, indicating last page
              if (points.length < 1000) {
                hasMore = false;
                developer.log(
                  '🏁 Tile ${completedTiles + 1}: Last page reached (got ${points.length} < 1000)',
                );
              } else {
                // Check if we've hit a reasonable page limit to prevent infinite loops
                if (page >= 10) {
                  hasMore = false;
                  developer.log(
                    '⚠️ Tile ${completedTiles + 1}: Reached page limit (10 pages), stopping pagination',
                  );
                } else {
                  page++;
                  // Small delay between pages
                  await Future.delayed(const Duration(milliseconds: 200));
                }
              }
            }
          }

          completedTiles++;
          developer.log(
            '✅ Tile $completedTiles/$totalTiles completed with $tilePoints reporting points (total: ${allPoints.length})',
          );

          // Append reporting points from this tile to cache (don't clear existing ones)
          if (tilePointsList.isNotEmpty) {
            await _cacheReportingPoints(tilePointsList, append: true);
            developer.log(
              '💾 Appended $tilePoints reporting points from tile $completedTiles',
            );
          }

          // Smaller delay between tiles since we're using smaller tiles
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          developer.log(
            '❌ Error fetching tile ${completedTiles + 1}/$totalTiles: $e',
          );
          // Continue with next tile even if one fails
          completedTiles++;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    developer.log(
      '✅ Completed fetching reporting points: ${allPoints.length} total from $completedTiles tiles',
    );

    // Final cache verification
    final cachedCount = await getCachedReportingPoints();
    developer.log(
      '📊 Final verification - Points fetched: ${allPoints.length}, Points in cache: ${cachedCount.length}',
    );

    // Check for duplicates
    final uniqueIds = allPoints.map((p) => p.id).toSet();
    if (uniqueIds.length != allPoints.length) {
      developer.log(
        '⚠️ Found ${allPoints.length - uniqueIds.length} duplicate IDs in fetched data!',
      );

      // Log which IDs are duplicated
      final idCounts = <String, int>{};
      for (final point in allPoints) {
        idCounts[point.id] = (idCounts[point.id] ?? 0) + 1;
      }
      final duplicates = idCounts.entries.where((e) => e.value > 1).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      developer.log('📊 Top duplicate IDs:');
      for (int i = 0; i < duplicates.length.clamp(0, 5); i++) {
        developer.log(
          '  - ID "${duplicates[i].key}": ${duplicates[i].value} occurrences',
        );
      }
    }

    // Log geographic distribution
    if (allPoints.isNotEmpty) {
      final latitudes = allPoints.map((p) => p.position.latitude).toList()
        ..sort();
      final longitudes = allPoints.map((p) => p.position.longitude).toList()
        ..sort();
      developer.log('📍 Geographic distribution:');
      developer.log(
        '  - Latitude range: ${latitudes.first} to ${latitudes.last}',
      );
      developer.log(
        '  - Longitude range: ${longitudes.first} to ${longitudes.last}',
      );

      // Count points by region (rough estimation)
      final regions = <String, int>{};
      for (final point in allPoints) {
        final lat = point.position.latitude;
        final lon = point.position.longitude;
        String region = 'Unknown';

        if (lat > 35 && lat < 71 && lon > -10 && lon < 40) {
          region = 'Europe';
        } else if (lat > 20 && lat < 50 && lon > -130 && lon < -60) {
          region = 'North America';
        } else if (lat > -35 && lat < 35 && lon > -20 && lon < 60) {
          region = 'Africa';
        } else if (lat > -10 && lat < 55 && lon > 60 && lon < 150) {
          region = 'Asia';
        } else if (lat > -50 && lat < -10 && lon > -80 && lon < -35) {
          region = 'South America';
        } else if (lat > -50 && lat < -10 && lon > 110 && lon < 180) {
          region = 'Oceania';
        }

        regions[region] = (regions[region] ?? 0) + 1;
      }

      developer.log('📊 Points by region:');
      for (final entry in regions.entries) {
        developer.log('  - ${entry.key}: ${entry.value} points');
      }
    }

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

  Future<void> _cacheReportingPoints(
    List<ReportingPoint> reportingPoints, {
    bool append = false,
  }) async {
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
      developer.log('🔄 Starting reporting points cache refresh...');

      // Check current cache status
      final currentCached = await getCachedReportingPoints();
      developer.log(
        '📊 Current cache has ${currentCached.length} reporting points',
      );

      // Always fetch all reporting points when refresh is requested
      final reportingPoints = await fetchAllReportingPoints();

      if (reportingPoints.isNotEmpty) {
        developer.log(
          '✅ Refreshed reporting points cache with ${reportingPoints.length} items',
        );

        // Verify the refresh worked
        final newCached = await getCachedReportingPoints();
        developer.log(
          '📊 After refresh, cache has ${newCached.length} reporting points',
        );

        if (newCached.length < reportingPoints.length) {
          developer.log(
            '⚠️ Cache has fewer points than fetched! Cache: ${newCached.length}, Fetched: ${reportingPoints.length}',
          );
        }
      } else {
        developer.log('⚠️ No reporting points fetched during refresh');
      }
    } catch (e) {
      developer.log('❌ Error refreshing reporting points cache: $e');
      developer.log('❌ Stack trace: ${StackTrace.current}');
    }
  }
}
