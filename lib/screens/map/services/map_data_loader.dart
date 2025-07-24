import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:logger/logger.dart';
import '../../../models/airport.dart';
import '../../../models/runway.dart';
import '../../../models/navaid.dart';
import '../../../models/obstacle.dart';
import '../../../models/hotspot.dart';
import '../../../models/airspace.dart';
import '../../../models/reporting_point.dart';
import '../../../services/airport_service.dart';
import '../../../services/runway_service.dart';
import '../../../services/navaid_service.dart';
import '../../../services/weather_service.dart';
import '../../../services/openaip_service.dart';
import '../../../services/spatial_airspace_service.dart';
import '../../../utils/frame_aware_scheduler.dart';

class MapDataLoader {
  final Logger _logger = Logger(level: Level.warning);
  final FrameAwareScheduler _scheduler = FrameAwareScheduler();
  
  // Services
  final AirportService? airportService;
  final RunwayService? runwayService;
  final NavaidService? navaidService;
  final WeatherService? weatherService;
  final OpenAIPService openAIPService;
  final SpatialAirspaceService spatialAirspaceService;
  
  // Debounce timers
  Timer? _airportLoadTimer;
  Timer? _weatherLoadTimer;
  Timer? _notamPrefetchTimer;
  int _notamFetchGeneration = 0;
  
  // Data update callbacks
  final Function(List<Airport>) onAirportsLoaded;
  final Function(Map<String, List<Runway>>) onRunwaysLoaded;
  final Function(List<Navaid>) onNavaidsLoaded;
  final Function(List<Airspace>) onAirspacesLoaded;
  final Function(List<ReportingPoint>) onReportingPointsLoaded;
  final Function(List<Obstacle>) onObstaclesLoaded;
  final Function(List<Hotspot>) onHotspotsLoaded;
  
  MapDataLoader({
    required this.airportService,
    required this.runwayService,
    required this.navaidService,
    required this.weatherService,
    required this.openAIPService,
    required this.spatialAirspaceService,
    required this.onAirportsLoaded,
    required this.onRunwaysLoaded,
    required this.onNavaidsLoaded,
    required this.onAirspacesLoaded,
    required this.onReportingPointsLoaded,
    required this.onObstaclesLoaded,
    required this.onHotspotsLoaded,
  });
  
  // Load airports with debouncing
  Future<void> loadAirports(MapCamera camera, {bool showMetar = false}) async {
    if (airportService == null || runwayService == null) {
      _logger.w('Airport or runway service not initialized');
      return;
    }
    
    _airportLoadTimer?.cancel();
    _airportLoadTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final bounds = camera.visibleBounds;
        
        // Load airports in bounds
        final airports = await airportService!.getAirportsInBounds(
          bounds.southWest,
          bounds.northEast,
        );
        
        // For now, just use airports in bounds
        final nearbyAirports = <Airport>[];
        
        // Combine and deduplicate
        final allAirports = <String, Airport>{};
        for (final airport in [...airports, ...nearbyAirports]) {
          allAirports[airport.icao] = airport;
        }
        
        final uniqueAirports = allAirports.values.toList();
        onAirportsLoaded(uniqueAirports);
        
        // Load runways for airports
        final runwayMap = <String, List<Runway>>{};
        for (final airport in uniqueAirports) {
          final runways = runwayService!.getRunwaysForAirport(airport.icao);
          if (runways.isNotEmpty) {
            runwayMap[airport.icao] = runways;
          }
        }
        onRunwaysLoaded(runwayMap);
        
        // Load weather if enabled
        if (showMetar) {
          await refreshWeatherForAirports(uniqueAirports);
        }
      } catch (e) {
        _logger.e('Error loading airports: $e');
      }
    });
  }
  
  // Load navaids
  Future<void> loadNavaids(MapCamera camera) async {
    if (navaidService == null) {
      _logger.w('Navaid service not initialized');
      return;
    }
    
    try {
      final bounds = camera.visibleBounds;
      final navaids = navaidService!.getNavaidsInBounds(
        bounds.southWest,
        bounds.northEast,
      );
      onNavaidsLoaded(navaids);
    } catch (e) {
      _logger.e('Error loading navaids: $e');
    }
  }
  
  // Load airspaces with debouncing
  Future<void> loadAirspaces(MapCamera camera) async {
    _scheduler.scheduleOperation(
      id: 'load_airspaces',
      operation: () => _loadAirspacesInternal(camera),
      debounce: const Duration(milliseconds: 500),
    );
  }
  
  Future<void> _loadAirspacesInternal(MapCamera camera) async {
    try {
      final bounds = camera.visibleBounds;
      
      // Load airspaces from OpenAIP
      final airspaces = await openAIPService.getAirspacesAtPosition(
        bounds.center,
        0.0, // altitude in feet
      );
      
      onAirspacesLoaded(airspaces);
      
      // Update spatial index
      // The spatial service maintains its own index internally
    } catch (e) {
      _logger.e('Error loading airspaces: $e');
    }
  }
  
  // Load reporting points
  Future<void> loadReportingPoints(MapCamera camera) async {
    try {
      final bounds = camera.visibleBounds;
      final reportingPoints = openAIPService.getReportingPointsInBounds(
        minLat: bounds.southWest.latitude,
        minLon: bounds.southWest.longitude,
        maxLat: bounds.northEast.latitude,
        maxLon: bounds.northEast.longitude,
      );
      onReportingPointsLoaded(reportingPoints);
    } catch (e) {
      _logger.e('Error loading reporting points: $e');
    }
  }
  
  // Load obstacles
  Future<void> loadObstacles(MapCamera camera) async {
    try {
      final bounds = camera.visibleBounds;
      final obstacles = await openAIPService.getObstaclesForArea(
        minLat: bounds.southWest.latitude,
        minLon: bounds.southWest.longitude,
        maxLat: bounds.northEast.latitude,
        maxLon: bounds.northEast.longitude,
      );
      onObstaclesLoaded(obstacles);
    } catch (e) {
      _logger.e('Error loading obstacles: $e');
    }
  }
  
  // Load hotspots
  Future<void> loadHotspots(MapCamera camera) async {
    try {
      final bounds = camera.visibleBounds;
      final hotspots = await openAIPService.getHotspotsForArea(
        minLat: bounds.southWest.latitude,
        minLon: bounds.southWest.longitude,
        maxLat: bounds.northEast.latitude,
        maxLon: bounds.northEast.longitude,
      );
      onHotspotsLoaded(hotspots);
    } catch (e) {
      _logger.e('Error loading hotspots: $e');
    }
  }
  
  // Refresh weather for airports
  Future<void> refreshWeatherForAirports(List<Airport> airports) async {
    if (weatherService == null) return;
    
    _weatherLoadTimer?.cancel();
    _weatherLoadTimer = Timer(const Duration(milliseconds: 500), () async {
      final airportsNeedingWeather = airports.where((airport) {
        return _shouldFetchWeatherForAirport(airport);
      }).toList();
      
      if (airportsNeedingWeather.isEmpty) return;
      
      // Batch weather requests
      const batchSize = 10;
      for (int i = 0; i < airportsNeedingWeather.length; i += batchSize) {
        final batch = airportsNeedingWeather.skip(i).take(batchSize).toList();
        final futures = batch.map((airport) => 
          weatherService!.getMetar(airport.icao).catchError((e) {
            _logger.w('Failed to fetch weather for ${airport.icao}: $e');
            return null;
          })
        );
        
        await Future.wait(futures);
        
        // Small delay between batches
        if (i + batchSize < airportsNeedingWeather.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    });
  }
  
  bool _shouldFetchWeatherForAirport(Airport airport) {
    // Skip closed airports and seaplane bases
    if (airport.type == 'closed' || airport.type == 'seaplane_base') {
      return false;
    }
    
    // Only fetch for airports with ICAO codes
    if (airport.icao.isEmpty || airport.icao.length != 4) {
      return false;
    }
    
    // For now, always fetch weather data
    // TODO: Add caching logic to check if weather was recently fetched
    return true;
  }
  
  // Schedule NOTAM prefetch for visible airports
  void schedulePrefetchNotams(MapCamera camera) {
    _notamPrefetchTimer?.cancel();
    _notamFetchGeneration++;
    
    // Only prefetch NOTAMs when zoomed in enough
    if (camera.zoom <= 11) {
      return;
    }
    
    final currentGeneration = _notamFetchGeneration;
    _notamPrefetchTimer = Timer(const Duration(seconds: 5), () async {
      if (currentGeneration == _notamFetchGeneration) {
        await _prefetchVisibleAirportNotams(camera, currentGeneration);
      }
    });
  }
  
  Future<void> _prefetchVisibleAirportNotams(MapCamera camera, int generation) async {
    if (generation != _notamFetchGeneration) return;
    
    // final bounds = camera.visibleBounds; // Unused for now
    
    // Get visible airports from the current data
    // This would need to be passed in or stored locally
    // For now, we'll skip the implementation
  }
  
  // Schedule map data loading with appropriate priorities
  void scheduleMapDataLoading({
    required MapCamera camera,
    required bool showNavaids,
    required bool showAirspaces,
    required bool showObstacles,
    required bool showHotspots,
    required bool showMetar,
  }) {
    // Load airports first (highest priority)
    _scheduler.scheduleOperation(
      id: 'load_airports',
      operation: () => loadAirports(camera, showMetar: showMetar),
      debounce: const Duration(milliseconds: 300),
      highPriority: true,
    );
    
    // Load navaids with delay
    if (showNavaids) {
      _scheduler.scheduleOperation(
        id: 'load_navaids',
        operation: () => loadNavaids(camera),
        debounce: const Duration(milliseconds: 600),
      );
    }
    
    // Reporting points with more delay
    if (showAirspaces) {
      _scheduler.scheduleOperation(
        id: 'load_reporting_points',
        operation: () => loadReportingPoints(camera),
        debounce: const Duration(milliseconds: 800),
      );
    }
    
    // Obstacles with delay
    if (showObstacles) {
      _scheduler.scheduleOperation(
        id: 'load_obstacles',
        operation: () => loadObstacles(camera),
        debounce: const Duration(milliseconds: 900),
      );
    }
    
    // Hotspots with delay  
    if (showHotspots) {
      _scheduler.scheduleOperation(
        id: 'load_hotspots',
        operation: () => loadHotspots(camera),
        debounce: const Duration(milliseconds: 950),
      );
    }
    
    // Weather data with even more delay
    if (showMetar) {
      _scheduler.scheduleOperation(
        id: 'load_weather',
        operation: () => loadAirports(camera, showMetar: true),
        debounce: const Duration(milliseconds: 1000),
      );
    }
    
    // NOTAMs with lowest priority
    _scheduler.scheduleOperation(
      id: 'prefetch_notams',
      operation: () => schedulePrefetchNotams(camera),
      debounce: const Duration(milliseconds: 1500),
    );
  }
  
  void dispose() {
    _airportLoadTimer?.cancel();
    _weatherLoadTimer?.cancel();
    _notamPrefetchTimer?.cancel();
  }
}