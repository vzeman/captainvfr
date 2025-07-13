import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'flight_log_screen.dart';
import 'offline_data_screen.dart';
import 'flight_plans_screen.dart';
import 'aircraft_settings_screen.dart';
import 'checklist_settings_screen.dart';
import 'licenses_screen.dart';
import 'calculators_screen.dart';
import 'settings_screen.dart';
import '../models/airport.dart';
import '../models/navaid.dart';
import '../models/flight_segment.dart' as flight_seg;
import '../models/flight_plan.dart';
import '../services/airport_service.dart';
import '../services/navaid_service.dart';
import '../services/flight_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/offline_map_service.dart';
import '../services/offline_tile_provider.dart';
import '../services/flight_plan_service.dart';
import '../widgets/navaid_marker.dart';
import '../widgets/optimized_marker_layer.dart';
import '../widgets/airport_info_sheet.dart';
import '../widgets/flight_dashboard.dart';
import '../widgets/airport_search_delegate.dart';
import '../widgets/metar_overlay.dart';
import '../widgets/flight_plan_overlay.dart';
import '../widgets/flight_planning_panel.dart';
import '../widgets/license_warning_widget.dart';
import '../widgets/floating_waypoint_panel.dart';
import '../widgets/spatial_airspaces_overlay.dart';
import '../widgets/airspace_flight_info.dart';
import '../services/openaip_service.dart';
import '../services/spatial_airspace_service.dart';
import '../services/settings_service.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import '../utils/airspace_utils.dart';
import '../widgets/loading_progress_bar.dart';
import '../widgets/themed_dialog.dart';
import '../services/cache_service.dart';
import '../services/notam_service_v3.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // Services
  late final FlightService _flightService;
  late final AirportService _airportService;
  late final NavaidService _navaidService;
  late final LocationService _locationService;
  late final WeatherService _weatherService;
  OfflineMapService?
  _offlineMapService; // Make nullable to prevent LateInitializationError
  late final FlightPlanService _flightPlanService;
  OpenAIPService? _openAIPService;
  SpatialAirspaceService? _spatialAirspaceService;
  late final MapController _mapController;
  late final CacheService _cacheService;

  // Getter to ensure OpenAIPService is available
  OpenAIPService get openAIPService {
    if (_openAIPService == null && mounted) {
      try {
        _openAIPService = Provider.of<OpenAIPService>(context, listen: false);
      } catch (e) {
        // debugPrint('⚠️ OpenAIPService still not available, using singleton');
        _openAIPService =
            OpenAIPService(); // This returns the singleton instance
      }
    }
    return _openAIPService!;
  }

  // Getter to ensure SpatialAirspaceService is available
  SpatialAirspaceService get spatialAirspaceService {
    _spatialAirspaceService ??= SpatialAirspaceService(openAIPService);
    return _spatialAirspaceService!;
  }

  final GlobalKey _mapKey = GlobalKey();

  // State variables
  bool _isLocationLoaded = false; // Track if location has been loaded
  bool _showStats = false;
  bool _showNavaids = true; // Toggle for navaid display
  bool _showMetar = true; // Toggle for METAR overlay (default on)
  bool _showHeliports = false; // Toggle for heliport display (default hidden)
  bool _showSmallAirports =
      true; // Toggle for small airport display (default visible)
  bool _showAirspaces = true; // Toggle for airspaces display
  bool _servicesInitialized = false;
  bool _isInitializing = false; // Guard against concurrent initialization
  bool _showFlightPlanning = false; // Toggle for integrated flight planning
  String _errorMessage = '';
  Timer? _debounceTimer;
  Timer? _airspaceDebounceTimer;
  Timer? _notamPrefetchTimer;
  bool _waypointJustTapped =
      false; // Flag to prevent airspace popup when waypoint is tapped
  int _notamFetchGeneration =
      0; // Track NOTAM fetch generations to cancel outdated requests

  // Flight data panel position state
  Offset _flightDataPanelPosition = const Offset(
    8,
    220,
  ); // Default to bottom with minimal margin for phones
  bool _flightDashboardExpanded =
      true; // Track expanded state of flight dashboard

  // Airspace panel visibility and position
  bool _showCurrentAirspacePanel =
      true; // Control visibility of current airspace panel
  Offset? _airspacePanelPosition; // Will be calculated dynamically to center initially

  // Toggle panel position
  double _togglePanelRightPosition = 16.0; // Default position from right edge
  double _togglePanelTopPosition =
      0.02; // Default position as percentage from top (2% - very top)

  // Flight planning panel position and state
  Offset _flightPlanningPanelPosition = const Offset(
    16,
    100,
  ); // Default position
  bool _flightPlanningExpanded =
      true; // Track expanded state of flight planning panel

  // Waypoint selection state
  int? _selectedWaypointIndex;
  bool _isDraggingWaypoint = false;

  // Location and map state
  Position? _currentPosition;
  List<LatLng> _flightPathPoints = [];
  List<flight_seg.FlightSegment> _flightSegments = [];
  List<Airport> _airports = [];
  List<Navaid> _navaids = [];
  List<Airspace> _airspaces = [];
  List<ReportingPoint> _reportingPoints = [];

  // UI state
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Map settings
  static const double _initialZoom = 12.0;
  static const double _maxZoom = 18.0;
  static const double _minZoom = 3.0;

  // Auto-centering control
  bool _autoCenteringEnabled = true;
  Timer? _autoCenteringTimer;
  static const Duration _autoCenteringDelay = Duration(minutes: 3);
  bool _wasTracking = false;

  @override
  void initState() {
    super.initState();

    // Initialize map controller
    _mapController = MapController();

    // Start location loading in background without blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationInBackground();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize services from Provider to ensure they're properly initialized
    if (!_servicesInitialized) {
      try {
        _flightService = Provider.of<FlightService>(context, listen: false);
        _locationService = Provider.of<LocationService>(context, listen: false);
        _airportService = Provider.of<AirportService>(context, listen: false);
        _navaidService = Provider.of<NavaidService>(context, listen: false);
        _weatherService = Provider.of<WeatherService>(context, listen: false);
        _flightPlanService = Provider.of<FlightPlanService>(
          context,
          listen: false,
        );
        
        // Set up callback to focus map on first waypoint when flight plan is loaded
        _flightPlanService.onFlightPlanLoaded = (flightPlan) {
          if (flightPlan.waypoints.isNotEmpty) {
            final firstWaypoint = flightPlan.waypoints.first;
            _mapController.move(
              LatLng(firstWaypoint.latitude, firstWaypoint.longitude),
              12.0, // Good zoom level to see waypoint and surrounding area
            );
            
            // Load data for the new area
            _loadAirports();
            if (_showNavaids) {
              _loadNavaids();
            }
            if (_showAirspaces) {
              _loadAirspaces();
              _loadReportingPoints();
            }
            if (_showMetar) {
              _loadWeatherForVisibleAirports();
            }
          }
        };
        
        _cacheService = Provider.of<CacheService>(context, listen: false);

        // Try to get OpenAIPService, but don't fail if it's not available yet
        try {
          _openAIPService = Provider.of<OpenAIPService>(context, listen: false);
        } catch (e) {
          // debugPrint('⚠️ OpenAIPService not available yet, will retry later');
          // We'll initialize it later in the build cycle
        }

        // Initialize services with caching
        _initializeServices();

        // Listen to flight service updates
        _setupFlightServiceListener();

        // Listen to cache updates
        _setupCacheListener();

        // Start loading data in background if location is already available
        if (_currentPosition != null && !_isLocationLoaded) {
          _onLocationLoaded();
        }

        _servicesInitialized = true;
      } catch (e) {
        // debugPrint('Error initializing services: $e');
      }
    }
  }

  // Setup listener for cache updates
  void _setupCacheListener() {
    _cacheService.addListener(_onCacheUpdated);
  }

  // Handle cache updates
  void _onCacheUpdated() {
    // Refresh airspaces if they're enabled
    if (_showAirspaces && mounted) {
      _refreshAirspacesDisplay();
      _refreshReportingPointsDisplay();
    }

    // Could also refresh other data types here if needed
  }

  // Setup listener for flight service updates
  void _setupFlightServiceListener() {
    _flightService.addListener(_onFlightPathUpdated);
    _flightPlanService.addListener(_onFlightPlanUpdated);
  }

  // Handle flight path updates from the flight service
  void _onFlightPathUpdated() {
    if (mounted) {
      setState(() {
        // Check if tracking just started
        if (_flightService.isTracking && !_wasTracking) {
          // Re-enable auto-centering when tracking starts
          _autoCenteringEnabled = true;
          _autoCenteringTimer?.cancel();
        }
        _wasTracking = _flightService.isTracking;

        // Convert flight points to LatLng for map visualization
        _flightPathPoints = _flightService.flightPath
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        // Update flight segments for visualization
        _flightSegments = _flightService.flightSegments;

        // Update current position if tracking
        if (_flightService.isTracking && _flightPathPoints.isNotEmpty) {
          final lastPoint = _flightService.flightPath.last;
          _currentPosition = Position(
            latitude: lastPoint.latitude,
            longitude: lastPoint.longitude,
            timestamp: DateTime.now(),
            accuracy: lastPoint.accuracy,
            altitude: lastPoint.altitude,
            heading: _flightService.currentHeading ?? lastPoint.heading,
            speed: lastPoint.speed,
            speedAccuracy: lastPoint.speedAccuracy,
            altitudeAccuracy: lastPoint.verticalAccuracy,
            headingAccuracy: lastPoint.headingAccuracy,
          );

          // Update map position and rotation during tracking only if auto-centering is enabled
          if (_autoCenteringEnabled) {
            final settings = Provider.of<SettingsService>(
              context,
              listen: false,
            );
            if (settings.rotateMapWithHeading) {
              // Move and rotate map
              _mapController.moveAndRotate(
                LatLng(lastPoint.latitude, lastPoint.longitude),
                _mapController.camera.zoom,
                -(_flightService.currentHeading ??
                    lastPoint.heading), // Negate for map rotation
              );
            } else {
              // Just move map
              _mapController.move(
                LatLng(lastPoint.latitude, lastPoint.longitude),
                _mapController.camera.zoom,
              );
            }
          }
        } else if (!_flightService.isTracking && _currentPosition != null) {
          // When not tracking, still update heading from sensors if available
          final currentHeading = _flightService.currentHeading;
          if (currentHeading != null &&
              (_currentPosition!.heading - currentHeading).abs() > 1.0) {
            _currentPosition = Position(
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
              timestamp: _currentPosition!.timestamp,
              accuracy: _currentPosition!.accuracy,
              altitude: _currentPosition!.altitude,
              heading: currentHeading,
              speed: _currentPosition!.speed,
              speedAccuracy: _currentPosition!.speedAccuracy,
              altitudeAccuracy: _currentPosition!.altitudeAccuracy,
              headingAccuracy: _currentPosition!.headingAccuracy,
            );
          }
        }
      });
    }
  }

  // Handle flight plan updates from the flight plan service
  void _onFlightPlanUpdated() {
    if (mounted) {
      setState(() {
        // Show flight plan panel when a plan is loaded
        if (_flightPlanService.currentFlightPlan != null) {
          _showFlightPlanning = true;
        }
      });

      // Prefetch NOTAMs for airports in the flight plan when it changes
      if (_flightPlanService.currentFlightPlan != null) {
        _prefetchFlightPlanNotams();
      }
    }
  }

  @override
  void dispose() {
    _flightService.removeListener(_onFlightPathUpdated);
    _flightPlanService.removeListener(_onFlightPlanUpdated);
    _cacheService.removeListener(_onCacheUpdated);
    _debounceTimer?.cancel();
    _airspaceDebounceTimer?.cancel();
    _notamPrefetchTimer?.cancel();
    _autoCenteringTimer?.cancel();
    _mapController.dispose();
    _flightService.dispose();
    _spatialAirspaceService?.dispose();
    super.dispose();
  }

  // Initialize location in background without blocking the UI
  Future<void> _initLocationInBackground() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _errorMessage = '';
        });

        // Location loaded successfully, handle the rest
        _onLocationLoaded();
      }
    } catch (e) {
      // debugPrint('Error initializing location: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Location unavailable - using default position';
        });

        // Use a default position if location fails
        setState(() {
          // Default to San Francisco or any other default location
          _currentPosition = Position(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        });

        // Still trigger loading with default position
        _onLocationLoaded();
      }
    }
  }

  // Handle actions after location is loaded
  void _onLocationLoaded() {
    if (_isLocationLoaded) return; // Prevent duplicate calls
    _isLocationLoaded = true;

    // Wait for the next frame to ensure FlutterMap is rendered before using MapController
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentPosition != null) {
        try {
          final settings = Provider.of<SettingsService>(context, listen: false);
          if (settings.rotateMapWithHeading &&
              _flightService.isTracking &&
              _flightService.currentHeading != null) {
            _mapController.moveAndRotate(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              _initialZoom,
              -_flightService.currentHeading!,
            );
          } else {
            _mapController.move(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              _initialZoom,
            );
          }
        } catch (e) {
          // debugPrint('Error moving map: $e');
          // Fallback: try again after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _currentPosition != null) {
              try {
                _mapController.move(
                  LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  _initialZoom,
                );
              } catch (e) {
                // debugPrint('Error moving map (retry): $e');
              }
            }
          });
        }

        // Start loading data progressively
        _loadAirports();

        // Load navaids if they should be shown
        if (_showNavaids) {
          _loadNavaids();
        }

        // Load airspaces if they should be shown
        if (_showAirspaces) {
          _loadAirspaces();
          _loadReportingPoints();
        }
      }
    });
  }

  // Load airports in the current map view with debouncing
  Future<void> _loadAirports() async {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();

    // Set a new debounce timer (300ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      try {
        // Check if map controller is ready
        if (!mounted) {
          // debugPrint('📍 _loadAirports: Widget not mounted, returning');
          return;
        }

        final bounds = _mapController.camera.visibleBounds;
        final zoom = _mapController.camera.zoom;

        // Get airports within the current map bounds
        final airports = await _airportService.getAirportsInBounds(
          bounds.southWest,
          bounds.northEast,
        );

        if (mounted) {
          setState(() {
            _airports = airports;
          });

          // Refresh weather data for visible airports if METAR overlay is enabled
          if (_showMetar) {
            _refreshWeatherForVisibleAirports(airports);
          }

          // If we're at a high zoom level, also load nearby airports just outside the view
          if (zoom > 10) {
            final radiusKm = _calculateRadiusForZoom(zoom);
            _loadNearbyAirports(bounds.center, radiusKm * 1.5);
          }
        }
      } catch (e) {
        // debugPrint('Error loading airports: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load airports. Please try again.';
          });
        }
      }
    });
  }

  /// Refresh weather data for visible airports when map focus changes
  Future<void> _refreshWeatherForVisibleAirports(List<Airport> airports) async {
    if (!_showMetar || airports.isEmpty) return;

    try {
      // Filter airports that should have weather data (medium/large airports)
      final airportsNeedingWeather = airports.where((airport) {
        return _shouldFetchWeatherForAirport(airport);
      }).toList();

      if (airportsNeedingWeather.isEmpty) return;

      // Get ICAO codes for airports that need weather refresh
      final icaoCodes = airportsNeedingWeather.map((a) => a.icao).toList();

      // debugPrint('🌤️ Refreshing weather for ${icaoCodes.length} visible airports');

      // Fetch weather data for visible airports
      final metarData = await _weatherService.getMetarsForAirports(icaoCodes);
      final tafData = await _weatherService.getTafsForAirports(icaoCodes);

      // Update airports with fresh weather data
      for (final airport in airportsNeedingWeather) {
        final metar = metarData[airport.icao];
        final taf = tafData[airport.icao];

        if (metar != null) {
          airport.updateWeather(metar, taf: taf);
        }
      }

      // Trigger UI update to show fresh weather data
      if (mounted) {
        setState(() {
          // Update the airports list to reflect new weather data
          _airports = [...airports];
        });
      }

      // debugPrint('✅ Weather refresh completed for visible airports');
    } catch (e) {
      // debugPrint('❌ Error refreshing weather for visible airports: $e');
    }
  }

  /// Check if weather data should be fetched for this airport type
  bool _shouldFetchWeatherForAirport(Airport airport) {
    // Only fetch weather for medium and large airports
    // Small airports, heliports, seaplane bases typically don't have weather stations
    switch (airport.type.toLowerCase()) {
      case 'large_airport':
      case 'medium_airport':
        return true;
      case 'small_airport':
      case 'heliport':
      case 'seaplane_base':
      case 'closed':
        return false;
      default:
        // For unknown types, check if it has an ICAO code
        // Airports with proper ICAO codes are more likely to have weather data
        return airport.icao.length == 4 &&
            RegExp(r'^[A-Z]{4}$').hasMatch(airport.icao);
    }
  }

  // Calculate radius in kilometers based on zoom level
  double _calculateRadiusForZoom(double zoom) {
    // These values can be adjusted based on testing
    if (zoom > 14) return 20.0; // Very close zoom
    if (zoom > 12) return 50.0; // Close zoom
    if (zoom > 9) return 100.0; // Medium zoom
    return 200.0; // Far zoom
  }

  // Load additional nearby airports that might be just outside the current view
  Future<void> _loadNearbyAirports(LatLng center, double radiusKm) async {
    try {
      final nearbyAirports = _airportService.findAirportsNearby(
        center,
        radiusKm: radiusKm,
      );

      // Filter out airports we already have
      final newAirports = nearbyAirports
          .where((a) => !_airports.any((existing) => existing.icao == a.icao))
          .toList();

      if (newAirports.isNotEmpty && mounted) {
        setState(() {
          _airports = [..._airports, ...newAirports];
        });
      }
    } catch (e) {
      // debugPrint('Error loading nearby airports: $e');
    }
  }

  // Load navaids in the current map view
  Future<void> _loadNavaids() async {
    if (!_showNavaids) {
      return;
    }

    try {
      // Check if map controller is ready
      if (!mounted) {
        return;
      }

      // Ensure navaids are fetched
      await _navaidService.fetchNavaids();

      final totalNavaids = _navaidService.navaids.length;

      if (totalNavaids == 0) {
        return;
      }

      final bounds = _mapController.camera.visibleBounds;

      final navaids = _navaidService.getNavaidsInBounds(
        bounds.southWest,
        bounds.northEast,
      );

      if (mounted) {
        setState(() {
          _navaids = navaids;
        });
      }
    } catch (e) {
      // debugPrint('❌ Error loading navaids: $e');
    }
  }

  // Load airspaces in the current map view
  Future<void> _loadAirspaces() async {
    if (!_showAirspaces) {
      return;
    }

    // Cancel any pending debounce timer
    _airspaceDebounceTimer?.cancel();

    // Set a new debounce timer (500ms delay for airspaces)
    _airspaceDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _loadAirspacesDebounced();
    });
  }

  Future<void> _loadAirspacesDebounced() async {
    // Check if we have API key (either user or default)
    if (!openAIPService.hasApiKey) {
      // debugPrint('🌍 _loadAirspaces: No API key available');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please set your OpenAIP API key in Offline Data settings to view airspaces',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      // First, load from cache for immediate display
      final cachedAirspaces = await openAIPService.getCachedAirspaces();

      if (cachedAirspaces.isNotEmpty) {
        if (mounted) {
          setState(() {
            _airspaces = cachedAirspaces;
          });
          
          // Spatial index will be built automatically by the service
        }
      }

      // Then progressively load data for current bounds
      final bounds = _mapController.camera.visibleBounds;

      // Load airspaces for current map bounds
      await openAIPService.loadAirspacesForBounds(
        minLat: bounds.southWest.latitude,
        minLon: bounds.southWest.longitude,
        maxLat: bounds.northEast.latitude,
        maxLon: bounds.northEast.longitude,
        onDataLoaded: () {
          // Refresh the display when new data is loaded
          if (mounted) {
            _refreshAirspacesDisplay();
          }
        },
      );
    } catch (e) {
      // debugPrint('❌ Error loading airspaces: $e');
      // debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Refresh airspaces display when new data is available
  Future<void> _refreshAirspacesDisplay() async {
    try {
      final airspaces = await openAIPService.getCachedAirspaces();
      if (mounted) {
        setState(() {
          _airspaces = airspaces;
        });
        
        // Spatial index will be updated automatically by the service
      }
    } catch (e) {
      // debugPrint('❌ Error refreshing airspaces display: $e');
    }
  }

  // Load reporting points in the current map view
  Future<void> _loadReportingPoints() async {
    if (!_showAirspaces) {
      return;
    }

    try {
      // First load from cache for immediate display
      final cachedPoints = await openAIPService.getCachedReportingPoints();

      if (cachedPoints.isNotEmpty) {
        if (mounted) {
          setState(() {
            _reportingPoints = cachedPoints;
          });
        }
      }

      // Then progressively load for current bounds if we have an API key
      if (openAIPService.hasApiKey) {
        final bounds = _mapController.camera.visibleBounds;

        // Load reporting points for current area
        await openAIPService.loadReportingPointsForBounds(
          minLat: bounds.southWest.latitude,
          minLon: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLon: bounds.northEast.longitude,
          onDataLoaded: () {
            // Refresh the display when new data is loaded
            if (mounted) {
              _refreshReportingPointsDisplay();
            }
          },
        );
      }
    } catch (e) {
      // debugPrint('❌ Error loading reporting points: $e');
    }
  }

  // Refresh reporting points display when new data is available
  Future<void> _refreshReportingPointsDisplay() async {
    try {
      final points = await openAIPService.getCachedReportingPoints();
      if (mounted) {
        setState(() {
          _reportingPoints = points;
        });
      }
    } catch (e) {
      // debugPrint('❌ Error refreshing reporting points display: $e');
    }
  }

  // Center map on current location
  Future<void> _centerOnLocation() async {
    try {
      final position = await _locationService.getLastKnownOrCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          // Re-enable auto-centering when user manually centers
          _autoCenteringEnabled = true;
        });

        // Cancel any existing auto-centering timer
        _autoCenteringTimer?.cancel();

        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _mapController.camera.zoom,
        );
        _loadAirports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    }
  }

  // Calculate centered position for airspace panel
  Offset _getCenteredAirspacePanelPosition(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Calculate panel width based on constraints from the UI
    final panelWidth = isPhone
        ? screenSize.width - 16
        : (isTablet ? 500 : 600);
    
    // Center horizontally
    final leftPosition = (screenSize.width - panelWidth) / 2;
    
    // Position at bottom with some margin
    final bottomPosition = 100.0;
    
    final centeredPosition = Offset(leftPosition, bottomPosition);
    
    return centeredPosition;
  }

  // Toggle flight dashboard visibility
  void _toggleStats() {
    setState(() {
      _showStats = !_showStats;
    });
  }

  // Toggle navaid visibility
  void _toggleNavaids() {
    setState(() {
      _showNavaids = !_showNavaids;
    });

    // Load navaids immediately when toggled on
    if (_showNavaids) {
      _loadNavaids();
    } else {
      setState(() {
        _navaids = [];
      });
    }
  }

  // Toggle METAR overlay visibility
  void _toggleMetar() async {
    setState(() {
      _showMetar = !_showMetar;
    });

    // When METAR overlay is turned on, load weather for currently visible airports
    if (_showMetar) {
      try {
        await _loadWeatherForVisibleAirports();
      } catch (e) {
        debugPrint('Error loading weather: $e');
      }
    }
  }

  // Toggle heliport visibility
  void _toggleHeliports() {
    setState(() {
      _showHeliports = !_showHeliports;
    });
  }

  // Toggle small airport visibility
  void _toggleSmallAirports() {
    setState(() {
      _showSmallAirports = !_showSmallAirports;
    });
  }

  // Toggle airspaces visibility
  void _toggleAirspaces() {
    if (!_showAirspaces) {
      // Turning airspaces ON
      setState(() {
        _showAirspaces = true;
      });
      _loadAirspaces();
      _loadReportingPoints();
    } else {
      // Turning airspaces OFF - clear data immediately before setState
      _airspaces = [];
      _reportingPoints = [];
      // Clear the spatial index to free memory
      spatialAirspaceService.clearIndex();
      
      // Now update UI
      setState(() {
        _showAirspaces = false;
      });
    }
  }

  // Handle map tap - updated to support flight planning and airspace selection
  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    // If a waypoint was just tapped, ignore this map tap
    if (_waypointJustTapped) {
      return;
    }

    // If in flight planning mode and panel is visible, add waypoint
    // Only allow adding waypoints when the flight planning panel is shown and in edit mode
    if (_flightPlanService.isPlanning && _showFlightPlanning) {
      _flightPlanService.addWaypoint(point);
      return;
    }

    // Check if any airspaces contain the tapped point
    if (_showAirspaces && _airspaces.isNotEmpty) {
      final tappedAirspaces = _airspaces.where((airspace) {
        return airspace.containsPoint(point);
      }).toList();

      if (tappedAirspaces.isNotEmpty) {
        _showAirspacesAtPoint(tappedAirspaces, point);
        return;
      }
    }

    // Otherwise, close any open dialogs or menus
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // Show list of airspaces at a given point
  // Prefetch NOTAMs for airports in flight plan
  Future<void> _prefetchFlightPlanNotams() async {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan == null) return;

    final airportIcaos = <String>[];
    for (final waypoint in flightPlan.waypoints) {
      if (waypoint.type == WaypointType.airport && waypoint.name != null) {
        // Extract ICAO code from waypoint name (usually in format "ICAO - Airport Name")
        final parts = waypoint.name!.split(' - ');
        if (parts.isNotEmpty && parts[0].length == 4) {
          airportIcaos.add(parts[0]);
        }
      }
    }

    if (airportIcaos.isNotEmpty) {
      // debugPrint('Prefetching NOTAMs for flight plan airports: $airportIcaos');
      try {
        final notamService = NotamServiceV3(); // Using V3 as primary
        await notamService.prefetchNotamsForAirports(airportIcaos);
      } catch (e) {
        // debugPrint('Error prefetching flight plan NOTAMs: $e');
      }
    }
  }

  // Prefetch NOTAMs for visible airports with debouncing
  void _schedulePrefetchVisibleAirportNotams() {
    // Cancel any existing timer
    _notamPrefetchTimer?.cancel();

    // Increment generation to cancel any pending fetches
    _notamFetchGeneration++;

    // Only prefetch NOTAMs when zoomed in enough (zoom > 11)
    if (_mapController.camera.zoom <= 11) {
      // debugPrint('Skipping NOTAM prefetch - zoom level too low: ${_mapController.camera.zoom}');
      return;
    }

    // Schedule a new prefetch after 5 seconds of inactivity (increased from 2)
    final currentGeneration = _notamFetchGeneration;
    _notamPrefetchTimer = Timer(const Duration(seconds: 5), () async {
      // Only proceed if this is still the latest generation
      if (currentGeneration == _notamFetchGeneration) {
        await _prefetchVisibleAirportNotams(currentGeneration);
      }
    });
  }

  // Prefetch NOTAMs for visible airports
  Future<void> _prefetchVisibleAirportNotams(int generation) async {
    if (_airports.isEmpty) return;

    // Check if this generation is still current
    if (generation != _notamFetchGeneration) {
      // debugPrint('Cancelling outdated NOTAM prefetch (generation $generation != $_notamFetchGeneration)');
      return;
    }

    final bounds = _mapController.camera.visibleBounds;

    // Filter visible airports and prioritize by type
    final visibleAirports = _airports.where((airport) {
      return bounds.contains(airport.position);
    }).toList();

    // Sort by priority: large > medium > small > heliport > closed
    visibleAirports.sort((a, b) {
      const priorities = {
        'large_airport': 0,
        'medium_airport': 1,
        'small_airport': 2,
        'heliport': 3,
        'closed': 4,
      };
      final aPriority = priorities[a.type] ?? 5;
      final bPriority = priorities[b.type] ?? 5;
      return aPriority.compareTo(bPriority);
    });

    // Limit to 10 airports (reduced from 20) and exclude small airports, heliports and closed airports
    final priorityAirports = visibleAirports
        .where(
          (a) =>
              a.type != 'small_airport' &&
              a.type != 'heliport' &&
              a.type != 'closed',
        )
        .take(10)
        .toList();

    if (priorityAirports.isNotEmpty) {
      // Final check before making the request
      if (generation != _notamFetchGeneration) {
        // debugPrint('Cancelling NOTAM prefetch before request (generation $generation != $_notamFetchGeneration)');
        return;
      }

      final icaoCodes = priorityAirports.map((a) => a.icao).toList();
      // debugPrint('Prefetching NOTAMs for ${icaoCodes.length} large/medium airports at zoom ${_mapController.camera.zoom}');
      try {
        final notamService = NotamServiceV3(); // Using V3 as primary
        await notamService.prefetchNotamsForAirports(icaoCodes);

        // Check one more time after the async operation
        if (generation != _notamFetchGeneration) {
          // debugPrint('NOTAM prefetch completed but is now outdated (generation $generation != $_notamFetchGeneration)');
        }
      } catch (e) {
        // debugPrint('Error prefetching visible airport NOTAMs: $e');
      }
    }
  }

  void _showAirspacesAtPoint(List<Airspace> airspaces, LatLng point) async {
    if (!mounted) return;

    // Get current altitude if available
    final currentAltitudeFt = _currentPosition?.altitude != null
        ? _currentPosition!.altitude *
              3.28084 // Convert meters to feet
        : null;

    // Sort airspaces by altitude (lower first)
    airspaces.sort((a, b) {
      final altA = a.lowerLimitFt ?? 0;
      final altB = b.lowerLimitFt ?? 0;
      return altA.compareTo(altB);
    });

    // If only one airspace, show it directly
    if (airspaces.length == 1) {
      _onAirspaceSelected(airspaces.first);
      return;
    }

    // Show selection dialog for multiple airspaces
    await ThemedDialog.show(
      context: context,
      title: 'Airspaces at Location',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentAltitudeFt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: IntrinsicWidth(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1A448AFF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x33448AFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.height,
                        size: 16,
                        color: Color(0xFF448AFF),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Current altitude: ${currentAltitudeFt.round()} ft',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ...airspaces.map<Widget>((airspace) {
            // Check if current altitude is within this airspace
            final isAtCurrentAltitude =
                currentAltitudeFt != null &&
                airspace.isAtAltitude(currentAltitudeFt);

            return Container(
              decoration: isAtCurrentAltitude
                  ? BoxDecoration(
                      color: const Color(0x1A448AFF),
                      border: Border.all(
                        color: const Color(0xFF448AFF),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : BoxDecoration(
                      border: Border.all(
                        color: const Color(0x33448AFF),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(context).pop();
                    _onAirspaceSelected(airspace);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          _getAirspaceIcon(airspace.type),
                          color: _getAirspaceColor(
                            airspace.type,
                            airspace.icaoClass,
                          ),
                          size: isAtCurrentAltitude ? 28 : 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                airspace.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AirspaceUtils.getAirspaceTypeName(airspace.type)} ${AirspaceUtils.getIcaoClassName(airspace.icaoClass)}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                airspace.altitudeRange,
                                style: TextStyle(
                                  color: const Color(0xFF448AFF),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.white30),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  IconData _getAirspaceIcon(String? type) {
    if (type == null) return Icons.layers;

    switch (type.toUpperCase()) {
      case 'CTR':
      case 'ATZ':
        return Icons.flight_land;
      case 'D':
      case 'DANGER':
      case 'P':
      case 'PROHIBITED':
        return Icons.warning;
      case 'R':
      case 'RESTRICTED':
        return Icons.block;
      case 'TMA':
        return Icons.flight_takeoff;
      case 'TMZ':
      case 'RMZ':
        return Icons.radio;
      default:
        return Icons.layers;
    }
  }

  Color _getAirspaceColor(String? type, String? icaoClass) {
    if (type == null) return Colors.grey;

    switch (type.toUpperCase()) {
      case 'CTR':
      case 'D':
      case 'DANGER':
      case 'P':
      case 'PROHIBITED':
        return Colors.red;
      case 'TMA':
      case 'R':
      case 'RESTRICTED':
        return Colors.orange;
      case 'ATZ':
        return Colors.blue;
      case 'TSA':
        return Colors.purple;
      case 'TRA':
        return Colors.purple.shade700;
      case 'GLIDING':
        return Colors.green;
      case 'TMZ':
        return Colors.amber;
      case 'RMZ':
        return Colors.yellow.shade700;
      default:
        // Check ICAO class if type doesn't match
        if (icaoClass != null) {
          switch (icaoClass.toUpperCase()) {
            case 'A':
              return Colors.red.shade800;
            case 'B':
              return Colors.red.shade600;
            case 'C':
              return Colors.orange.shade600;
            case 'D':
              return Colors.blue.shade600;
            case 'E':
              return Colors.green.shade600;
            case 'F':
              return Colors.green.shade400;
            case 'G':
              return Colors.grey;
            default:
              return Colors.grey.shade600;
          }
        }
        return Colors.grey.shade600;
    }
  }

  // Handle waypoint tap for selection
  void _onWaypointTapped(int index) {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan != null &&
        index >= 0 &&
        index < flightPlan.waypoints.length) {
      setState(() {
        _selectedWaypointIndex = _selectedWaypointIndex == index ? null : index;
        _waypointJustTapped = true;
      });
      // Reset the flag after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _waypointJustTapped = false;
          });
        }
      });
    }
  }

  // Handle waypoint move via drag and drop
  void _onWaypointMoved(int index, LatLng newPosition) {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan != null &&
        index >= 0 &&
        index < flightPlan.waypoints.length) {
      // Update waypoint position
      _flightPlanService.updateWaypointPosition(index, newPosition);
    }
  }

  // Handle airport selection
  Future<void> _onAirportSelected(Airport airport) async {
    // debugPrint('_onAirportSelected called for ${airport.icao} - ${airport.name}');

    // If in flight planning mode and panel is visible, add airport as waypoint instead of showing details
    if (_flightPlanService.isPlanning && _showFlightPlanning) {
      // debugPrint('Flight planning mode active - adding airport as waypoint');
      _flightPlanService.addAirportWaypoint(airport);
      // debugPrint('Added airport waypoint: ${airport.icao} - ${airport.name}');
      return;
    }

    if (!mounted) {
      // debugPrint('Context not mounted, returning early');
      return;
    }

    try {
      // debugPrint('Showing bottom sheet for ${airport.icao}');
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => AirportInfoSheet(
          airport: airport,
          weatherService: _weatherService,
          onClose: () {
            // debugPrint('Closing bottom sheet for ${airport.icao}');
            Navigator.of(context).pop();
          },
        ),
      );
      // debugPrint('Bottom sheet closed for ${airport.icao}');
    } catch (e) {
      // debugPrint('Error showing bottom sheet for ${airport.icao}: $e');
      // debugPrint('Stack trace: $stackTrace');
      // Try to show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error showing airport details')),
        );
      }
    }
  }

  // Handle airport selection from search
  void _onAirportSelectedFromSearch(Airport airport) {
    // Focus map on the selected airport
    _mapController.move(
      airport.position,
      14.0, // Zoom level for airport focus
    );

    // Load airports in the new area
    _loadAirports();

    // Load navaids if they're enabled
    if (_showNavaids) {
      _loadNavaids();
    }

    // Load airspaces and reporting points if they're enabled
    if (_showAirspaces) {
      _loadAirspaces();
      _loadReportingPoints();
    }

    // Load weather data for new airports if METAR overlay is enabled
    if (_showMetar) {
      _loadWeatherForVisibleAirports();
    }

    // Show airport info sheet
    _onAirportSelected(airport);
  }

  // Show airport search
  void _showAirportSearch() {
    showSearch(
      context: context,
      delegate: AirportSearchDelegate(
        airportService: _airportService,
        onAirportSelected: _onAirportSelectedFromSearch,
      ),
    );
  }

  // Handle navaid selection
  Future<void> _onNavaidSelected(Navaid navaid) async {
    // debugPrint('_onNavaidSelected called for ${navaid.ident} - ${navaid.name}');

    // If in flight planning mode and panel is visible, add navaid as waypoint instead of showing details
    if (_flightPlanService.isPlanning && _showFlightPlanning) {
      // debugPrint('Flight planning mode active - adding navaid as waypoint');
      _flightPlanService.addNavaidWaypoint(navaid);
      // debugPrint('Added navaid waypoint: ${navaid.ident} - ${navaid.name}');
      return;
    }

    if (!mounted) {
      // debugPrint('Context not mounted, returning early');
      return;
    }

    try {
      // debugPrint('Showing bottom sheet for ${navaid.ident}');
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => NavaidInfoSheet(
          navaid: navaid,
          onClose: () {
            Navigator.of(context).pop();
          },
        ),
      );
      // debugPrint('Bottom sheet closed for ${navaid.ident}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error showing navaid details')),
        );
      }
    }
  }

  // Handle airspace selection
  Future<void> _onAirspaceSelected(Airspace airspace) async {
    if (!mounted) {
      return;
    }

    try {
      // Create a themed dialog to show airspace information
      await ThemedDialog.show(
        context: context,
        title: airspace.name,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (airspace.type != null)
              _buildThemedInfoRow(
                'Type',
                AirspaceUtils.getAirspaceTypeName(airspace.type),
              ),
            if (airspace.icaoClass != null)
              _buildThemedInfoRow(
                'ICAO Class',
                AirspaceUtils.getIcaoClassName(airspace.icaoClass),
              ),
            if (airspace.activity != null)
              _buildThemedInfoRow(
                'Activity',
                AirspaceUtils.getActivityName(airspace.activity),
              ),
            _buildThemedInfoRow('Altitude', airspace.altitudeRange),
            if (airspace.country != null)
              _buildThemedInfoRow('Country', airspace.country!),
            // Extract and display frequency if available in remarks
            if (airspace.remarks != null &&
                _extractFrequency(airspace.remarks!) != null)
              _buildThemedInfoRow(
                'Frequency',
                _extractFrequency(airspace.remarks!)!,
              ),
            if (airspace.onDemand == true)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '⚠️ On Demand',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            if (airspace.onRequest == true)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '⚠️ On Request',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            if (airspace.byNotam == true)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '⚠️ By NOTAM',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            if (airspace.remarks != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remarks:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF448AFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      airspace.remarks!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    } catch (e) {
      // debugPrint('Error showing airspace details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error showing airspace details')),
        );
      }
    }
  }

  // Handle reporting point selection
  Future<void> _onReportingPointSelected(ReportingPoint point) async {
    // If in flight planning mode and panel is visible, add reporting point as waypoint instead of showing details
    if (_flightPlanService.isPlanning && _showFlightPlanning) {
      _flightPlanService.addReportingPointWaypoint(point);
      return;
    }
    
    if (!mounted) {
      return;
    }

    try {
      // Create a themed dialog to show reporting point information
      await ThemedDialog.show(
        context: context,
        title: point.displayName,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemedInfoRow('Name', point.name),
            if (point.type != null) _buildThemedInfoRow('Type', point.type!),
            if (point.elevationString.isNotEmpty)
              _buildThemedInfoRow('Elevation', point.elevationString),
            if (point.country != null)
              _buildThemedInfoRow('Country', point.country!),
            if (point.state != null) _buildThemedInfoRow('State', point.state!),
            if (point.airportName != null)
              _buildThemedInfoRow('Airport', point.airportName!),
            if (point.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF448AFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.description!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            if (point.remarks != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remarks:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF448AFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.remarks!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            if (point.tags != null && point.tags!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tags:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF448AFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.tags!.join(', '),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    } catch (e) {
      // debugPrint('Error showing reporting point details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error showing reporting point details'),
          ),
        );
      }
    }
  }

  Widget _buildThemedInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF448AFF),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  /// Extract frequency information from remarks or other text
  String? _extractFrequency(String text) {
    // Common frequency patterns:
    // - 123.456 MHz
    // - 123.45 MHz
    // - 123.4 MHz
    // - FREQ: 123.456
    // - Frequency: 123.456
    // - Tower 123.456
    // - APP 123.456
    final frequencyPattern = RegExp(
      r'(?:freq(?:uency)?|tower|app|ground|atis|approach|departure|center|control|radio)?\s*:?\s*(\d{3}\.\d{1,3})(?:\s*mhz)?',
      caseSensitive: false,
    );

    final match = frequencyPattern.firstMatch(text);
    if (match != null) {
      final freq = match.group(1);
      return '$freq MHz';
    }

    return null;
  }

  /// Initialize services with cached data
  Future<void> _initializeServices() async {
    // Guard against concurrent initialization
    if (_isInitializing) return;

    _isInitializing = true; // Set the guard flag

    try {
      await _airportService.initialize();
      await _navaidService.initialize();

      // Initialize offline map service
      _offlineMapService = OfflineMapService();
      await _offlineMapService!.initialize(); // Use ! since we just assigned it

      // Only set servicesInitialized to true after all async initialization completes
      if (mounted) {
        setState(() {
          _servicesInitialized = true;
        });
      }
    } catch (e) {
      // debugPrint('⚠️ Error initializing services: $e');
      // Don't set _servicesInitialized = true if initialization failed
    } finally {
      _isInitializing = false; // Reset the guard flag
    }
  }

  // Load weather data for airports currently visible on the map
  Future<void> _loadWeatherForVisibleAirports() async {
    if (_airports.isEmpty) return;

    try {
      // Get the current map bounds
      final bounds = _mapController.camera.visibleBounds;
      
      // Get only the airports that are actually visible on the map (same filtering as markers)
      final visibleAirports = _airports.where((airport) {
        // First check if airport is within visible bounds
        if (!bounds.contains(airport.position)) {
          return false;
        }
        
        // Filter heliports based on toggle
        if (airport.type == 'heliport' && !_showHeliports) {
          return false;
        }
        // Filter small airports based on toggle
        if (airport.type == 'small_airport' && !_showSmallAirports) {
          return false;
        }
        // Filter closed airports (use correct lowercase "closed" check)
        if (airport.type.toLowerCase() == 'closed') {
          return false;
        }
        // Show medium and large airports always, and show small airports/heliports based on toggles
        return true;
      }).toList();

      if (visibleAirports.isEmpty) return;

      // Get only the ICAOs of airports that are actually visible
      final visibleAirportIcaos = visibleAirports
          .map((airport) => airport.icao)
          .toList();

      // Fetch weather data for visible airports
      await _weatherService.initialize();
      final metarData = await _weatherService.getMetarsForAirports(
        visibleAirportIcaos,
      );
      final tafData = await _weatherService.getTafsForAirports(
        visibleAirportIcaos,
      );

      // Update only the visible airports with weather data
      bool hasUpdates = false;
      for (final airport in visibleAirports) {
        final metar = metarData[airport.icao];
        final taf = tafData[airport.icao];
        if (metar != null) {
          airport.updateWeather(metar, taf: taf);
          hasUpdates = true;
        }
      }

      // Trigger UI update if we got new weather data
      if (hasUpdates && mounted) {
        setState(() {
          // Force rebuild to show updated weather data
        });
      }
    } catch (e) {
      // debugPrint('❌ Error loading weather for visible airports: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          // Map layer
          FlutterMap(
            key: _mapKey,
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    )
                  : const LatLng(
                      37.7749,
                      -122.4194,
                    ), // Default to San Francisco
              initialZoom: _initialZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              interactionOptions: InteractionOptions(
                flags: _isDraggingWaypoint
                    ? InteractiveFlag
                          .none // Disable all map interactions when dragging waypoint
                    : InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPosition, point) => _onMapTapped(tapPosition, point),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  // Disable auto-centering when user manually moves the map
                  if (_autoCenteringEnabled && _flightService.isTracking) {
                    setState(() {
                      _autoCenteringEnabled = false;
                    });

                    // Cancel any existing timer
                    _autoCenteringTimer?.cancel();

                    // Start a new timer to re-enable auto-centering after 3 minutes
                    _autoCenteringTimer = Timer(_autoCenteringDelay, () {
                      if (mounted && _flightService.isTracking) {
                        setState(() {
                          _autoCenteringEnabled = true;
                        });
                      }
                    });
                  }

                  _loadAirports();
                  // Also load navaids if they're enabled
                  if (_showNavaids) {
                    _loadNavaids();
                  }
                  // Load airspaces and reporting points if they're enabled
                  if (_showAirspaces) {
                    _loadAirspaces();
                    _loadReportingPoints();
                  }
                  // Load weather data for new airports if METAR overlay is enabled
                  if (_showMetar) {
                    _loadWeatherForVisibleAirports();
                  }
                  // Prefetch NOTAMs for visible airports
                  _schedulePrefetchVisibleAirportNotams();
                }
              },
            ),
            children: [
              // Tile layer with offline support
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.captainvfr',
                tileProvider: _servicesInitialized && _offlineMapService != null
                    ? OfflineTileProvider(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        offlineMapService: _offlineMapService!,
                        userAgentPackageName: 'com.example.captainvfr',
                      )
                    : null,
              ),
              // Airspaces overlay (spatial indexed)
              if (_showAirspaces)
                SpatialAirspacesOverlay(
                  spatialService: spatialAirspaceService,
                  showAirspacesLayer: _showAirspaces,
                  onAirspaceTap: _onAirspaceSelected,
                  currentAltitude: _currentPosition?.altitude ?? 0,
                ),
              // Reporting points overlay (optimized)
              if (_showAirspaces && _reportingPoints.isNotEmpty)
                OptimizedReportingPointsLayer(
                  reportingPoints: _reportingPoints,
                  onReportingPointTap: _onReportingPointSelected,
                ),
              // Airport markers with tap handling (optimized)
              OptimizedAirportMarkersLayer(
                airports: _airports.where((airport) {
                  // Filter heliports based on toggle
                  if (airport.type == 'heliport' && !_showHeliports) {
                    return false;
                  }
                  // Filter small airports based on toggle
                  if (airport.type == 'small_airport' && !_showSmallAirports) {
                    return false;
                  }
                  // Show medium and large airports always, and show small airports/heliports based on toggles
                  return true;
                }).toList(),
                onAirportTap: _onAirportSelected,
              ),
              // Navaid markers (optimized)
              if (_showNavaids && _navaids.isNotEmpty)
                OptimizedNavaidMarkersLayer(
                  navaids: _navaids,
                  onNavaidTap: _onNavaidSelected,
                ),
              // METAR overlay
              if (_showMetar)
                MetarOverlay(
                  airports: _airports,
                  showMetarLayer: _showMetar,
                  onAirportTap: _onAirportSelected,
                ),
              // Flight plan overlays - add before current position marker
              Consumer<FlightPlanService>(
                builder: (context, flightPlanService, child) {
                  final flightPlan = flightPlanService.currentFlightPlan;
                  if (flightPlan == null ||
                      flightPlan.waypoints.isEmpty ||
                      !flightPlanService.isFlightPlanVisible) {
                    return const SizedBox.shrink();
                  }

                  return Stack(
                    children: [
                      // Flight plan route lines
                      PolylineLayer(
                        polylines: FlightPlanOverlay.buildFlightPath(
                          flightPlan,
                        ),
                      ),
                      // Highlight next segment when tracking
                      if (_flightService.isTracking && _currentPosition != null)
                        PolylineLayer(
                          polylines: FlightPlanOverlay.buildNextSegment(
                            flightPlan,
                            LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                          ),
                        ),
                      // Waypoint markers
                      MarkerLayer(
                        markers: FlightPlanOverlay.buildWaypointMarkers(
                          flightPlan,
                          _onWaypointTapped,
                          _onWaypointMoved,
                          _selectedWaypointIndex,
                          (isDragging) {
                            setState(() {
                              _isDraggingWaypoint = isDragging;
                            });
                          },
                          _mapKey,
                          flightPlanService.isPlanning,
                        ),
                      ),
                      // Waypoint name labels (only show when zoomed in)
                      if (_mapController.camera.zoom > 11)
                        MarkerLayer(
                          markers: FlightPlanOverlay.buildWaypointLabels(
                            flightPlan,
                            _selectedWaypointIndex,
                          ),
                        ),
                      // Segment labels (distance, heading, time)
                      Builder(
                        builder: (context) {
                          return MarkerLayer(
                            markers: FlightPlanOverlay.buildSegmentLabels(
                              flightPlan,
                              context,
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              // Flight path layer - moved here to be above airspaces
              if (_flightPathPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _flightPathPoints,
                      color: Colors.red,
                      strokeWidth: 6.0,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),
              // Flight segment markers
              if (_flightSegments.isNotEmpty)
                MarkerLayer(
                  markers: _flightSegments
                      .map(
                        (segment) => [
                          // Start marker
                          Marker(
                            point: segment.startLatLng,
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _getSegmentColor(segment.type),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _getSegmentIcon(segment.type),
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // End marker
                          Marker(
                            point: segment.endLatLng,
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _getSegmentColor(
                                  segment.type,
                                ).withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.flag,
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                      .expand((markers) => markers)
                      .toList(),
                ),
              // Current position marker
              if (_currentPosition != null)
                Consumer<SettingsService>(
                  builder: (context, settings, child) {
                    // When rotateMapWithHeading is ON: map rotates, so aircraft marker stays pointing north (no rotation)
                    // When rotateMapWithHeading is OFF: map stays north, so aircraft marker rotates to show heading
                    final shouldRotateMarker = !settings.rotateMapWithHeading;
                    final markerRotation = shouldRotateMarker ? (_currentPosition?.heading ?? 0) * pi / 180 : 0.0;
                    
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          width: 30,
                          height: 30,
                          child: Transform.rotate(
                            angle: markerRotation,
                            child: const Icon(
                              Icons.flight,
                              color: Colors.blue,
                              size: 30,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
          // Vertical layer controls - draggable in both directions
          Positioned(
            top: MediaQuery.of(context).padding.top + (MediaQuery.of(context).size.height * _togglePanelTopPosition),
            right: _togglePanelRightPosition,
            child: SizedBox(
              width: 50, // Fixed width to constrain the draggable
              child: Draggable<String>(
                data: 'toggle_panel',
                // Remove axis constraint to allow both horizontal and vertical movement
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 50, // Fixed width for feedback
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.explore, size: 20, color: Colors.grey),
                        SizedBox(height: 4),
                        Icon(Icons.cloud, size: 20, color: Colors.grey),
                        SizedBox(height: 4),
                        Icon(Icons.adjust, size: 20, color: Colors.grey),
                        SizedBox(height: 4),
                        Icon(
                          Icons.airplanemode_active,
                          size: 20,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 4),
                        Icon(Icons.layers, size: 20, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          'A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                childWhenDragging: const SizedBox(
                  width: 50,
                ), // Maintain space when dragging
                onDragEnd: (details) {
                  setState(() {
                    final screenSize = MediaQuery.of(context).size;
                    final safeAreaTop = MediaQuery.of(context).padding.top;
                    final dragX = details.offset.dx;
                    final dragY = details.offset.dy;

                    // Calculate new right position
                    // dragX is from left, we need distance from right
                    double newRightPosition =
                        screenSize.width - dragX - 50; // 50 is panel width

                    // Calculate new top position as percentage, accounting for safe area
                    double adjustedDragY = dragY - safeAreaTop;
                    double newTopPosition = adjustedDragY / screenSize.height;

                    // Constrain to screen bounds
                    newRightPosition = newRightPosition.clamp(
                      0.0,
                      screenSize.width - 60,
                    );
                    newTopPosition = newTopPosition.clamp(
                      0.0, // Allow positioning at the very top
                      0.85,
                    ); // Keep between 0% and 85% of screen height

                    _togglePanelRightPosition = newRightPosition;
                    _togglePanelTopPosition = newTopPosition;
                  });
                },
                child: Container(
                  width: 50, // Ensure consistent width
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle indicator
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      _buildLayerToggle(
                        icon: _showNavaids
                            ? Icons.explore
                            : Icons.explore_outlined,
                        tooltip: 'Toggle Navaids',
                        isActive: _showNavaids,
                        onPressed: () {
                          _toggleNavaids();
                        },
                      ),
                      _buildLayerToggle(
                        icon: _showMetar ? Icons.cloud : Icons.cloud_outlined,
                        tooltip: 'Toggle METAR Overlay',
                        isActive: _showMetar,
                        onPressed: () {
                          _toggleMetar();
                        },
                      ),
                      _buildLayerToggle(
                        icon: _showHeliports
                            ? Icons.adjust
                            : Icons.radio_button_unchecked,
                        tooltip: 'Toggle Heliports',
                        isActive: _showHeliports,
                        onPressed: _toggleHeliports,
                      ),
                      _buildLayerToggle(
                        icon: _showSmallAirports
                            ? Icons.airplanemode_active
                            : Icons.airplanemode_inactive,
                        tooltip: 'Toggle Small Airports',
                        isActive: _showSmallAirports,
                        onPressed: _toggleSmallAirports,
                      ),
                      _buildLayerToggle(
                        icon: _showAirspaces
                            ? Icons.layers
                            : Icons.layers_outlined,
                        tooltip: 'Toggle Airspaces',
                        isActive: _showAirspaces,
                        onPressed: _toggleAirspaces,
                      ),
                      _buildLayerToggle(
                        icon: _showCurrentAirspacePanel
                            ? Icons.account_tree
                            : Icons.account_tree_outlined,
                        tooltip: 'Toggle Current Airspace Panel',
                        isActive: _showCurrentAirspacePanel,
                        onPressed: () {
                          setState(() {
                            _showCurrentAirspacePanel =
                                !_showCurrentAirspacePanel;
                            // Reset position when toggling on to ensure it centers
                            if (_showCurrentAirspacePanel) {
                              _airspacePanelPosition = null;
                            }
                          });
                          
                        },
                      ),
                      _buildLayerToggle(
                        icon: _showFlightPlanning
                            ? Icons.route
                            : Icons.route_outlined,
                        tooltip: 'Toggle Flight Planning',
                        isActive: _showFlightPlanning,
                        onPressed: () {
                          setState(() {
                            _showFlightPlanning = !_showFlightPlanning;
                            // Auto-create flight plan if none exists (with planning mode OFF)
                            if (_showFlightPlanning &&
                                _flightPlanService.currentFlightPlan == null) {
                              _flightPlanService.createNewFlightPlan(
                                enablePlanning: false,
                              );
                            }
                            // Sync flight plan visibility with panel visibility
                            _flightPlanService.setFlightPlanVisibility(
                              _showFlightPlanning,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Flight dashboard overlay - show when toggle is active
          if (_showStats)
            Positioned(
              left: _flightDataPanelPosition.dx,
              bottom: _flightDataPanelPosition
                  .dy, // Use positive value for bottom positioning
              child: Draggable<String>(
                data: 'flight_panel',
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width < 600
                        ? MediaQuery.of(context).size.width -
                              16 // Phone width
                        : 600, // Tablet/desktop max width
                    child: FlightDashboard(
                      isExpanded: _flightDashboardExpanded,
                      onExpandedChanged: (expanded) {
                        // Don't update state during drag
                      },
                    ),
                  ),
                ),
                childWhenDragging: Container(), // Empty container when dragging
                onDragEnd: (details) {
                  setState(() {
                    // Calculate new position based on drag end position
                    final screenSize = MediaQuery.of(context).size;
                    final isPhone = screenSize.width < 600;

                    double newX = details.offset.dx;
                    double newY = details.offset.dy;

                    // Get panel dimensions
                    final panelWidth = isPhone ? screenSize.width - 16 : 600;
                    final panelHeight = _flightDashboardExpanded ? 260 : 60;

                    // Convert screen coordinates to bottom-relative positioning
                    double bottomDistance =
                        screenSize.height - newY - panelHeight;

                    // Constrain to screen bounds with margins
                    final minMargin = isPhone ? 8.0 : 16.0;

                    // Allow full horizontal movement on tablets/desktop
                    if (!isPhone) {
                      newX = newX.clamp(
                        minMargin,
                        screenSize.width - panelWidth - minMargin,
                      );
                    } else {
                      // On phones, keep centered
                      newX = minMargin;
                    }

                    bottomDistance = bottomDistance.clamp(
                      16.0,
                      screenSize.height - panelHeight - 100,
                    );

                    _flightDataPanelPosition = Offset(newX, bottomDistance);
                  });
                },
                child: SizedBox(
                  width: MediaQuery.of(context).size.width < 600
                      ? MediaQuery.of(context).size.width -
                            16 // Phone width
                      : 600, // Tablet/desktop max width
                  child: FlightDashboard(
                    isExpanded: _flightDashboardExpanded,
                    onExpandedChanged: (expanded) {
                      setState(() {
                        _flightDashboardExpanded = expanded;
                      });
                    },
                  ),
                ),
              ),
            ),

          // Airspace information panel
          if (_showCurrentAirspacePanel) ...[
            Builder(
              builder: (context) {
                final position = _airspacePanelPosition ?? _getCenteredAirspacePanelPosition(context);
                return Positioned(
                  left: position.dx,
                  bottom: position.dy,
              child: Draggable<String>(
                data: 'airspace_panel',
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width < 600
                          ? MediaQuery.of(context).size.width - 16
                          : MediaQuery.of(context).size.width < 1200
                          ? 500
                          : 600,
                    ),
                    child: Builder(
                      builder: (context) {
                        // Always show airspace panel
                        LatLng position;
                        double altitude = 0.0;
                        double heading = 0.0;
                        double speed = 0.0;
                        
                        if (_currentPosition != null) {
                          // Use actual GPS position if available
                          position = LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          );
                          altitude = _currentPosition!.altitude;
                          heading = _currentPosition!.heading;
                          speed = _currentPosition!.speed;
                        } else {
                          // Use map center as position
                          final mapController = MapController.maybeOf(context);
                          if (mapController != null) {
                            try {
                              position = mapController.camera.center;
                            } catch (e) {
                              // Default position if map not ready
                              position = LatLng(50.0, 14.0); // Default to central Europe
                            }
                          } else {
                            position = LatLng(50.0, 14.0); // Default to central Europe
                          }
                        }
                        
                        return AirspaceFlightInfo(
                          currentPosition: position,
                          currentAltitude: altitude,
                          currentHeading: heading,
                          currentSpeed: speed,
                          openAIPService: openAIPService,
                          onAirspaceSelected: _onAirspaceSelected,
                        );
                      },
                    ),
                  ),
                ),
                childWhenDragging: Container(), // Empty container when dragging
                onDragEnd: (details) {
                  setState(() {
                    // Calculate new position based on drag end position
                    final screenSize = MediaQuery.of(context).size;
                    final isPhone = screenSize.width < 600;
                    final isTablet =
                        screenSize.width >= 600 && screenSize.width < 1200;

                    double newX = details.offset.dx;
                    double newY = details.offset.dy;

                    // Get panel dimensions based on device type
                    final panelWidth = isPhone
                        ? screenSize.width - 16
                        : (isTablet ? 500 : 600);
                    final panelHeight = 200; // Approximate panel height

                    // Convert screen coordinates to bottom-relative positioning
                    double bottomDistance =
                        screenSize.height - newY - panelHeight;

                    // Constrain horizontal position based on device type
                    if (isPhone) {
                      // On phones, keep it centered
                      newX = 0;
                    } else {
                      // On tablets/desktop, allow horizontal movement
                      newX = newX.clamp(
                        0.0,
                        screenSize.width - panelWidth - 16,
                      );
                    }

                    // Constrain vertical position
                    bottomDistance = bottomDistance.clamp(
                      10.0,
                      screenSize.height - panelHeight - 100,
                    );

                    _airspacePanelPosition = Offset(newX, bottomDistance);
                  });
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width < 600
                        ? MediaQuery.of(context).size.width - 16
                        : MediaQuery.of(context).size.width < 1200
                        ? 500
                        : 600,
                  ),
                  child: Builder(
                    builder: (context) {
                      // Always show airspace panel
                      LatLng position;
                      double altitude = 0.0;
                      double heading = 0.0;
                      double speed = 0.0;
                      
                      if (_currentPosition != null) {
                        // Use actual GPS position if available
                        position = LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        );
                        altitude = _currentPosition!.altitude;
                        heading = _currentPosition!.heading;
                        speed = _currentPosition!.speed;
                      } else {
                        // Use map center as position
                        final mapController = MapController.maybeOf(context);
                        if (mapController != null) {
                          try {
                            position = mapController.camera.center;
                          } catch (e) {
                            // Default position if map not ready
                            position = LatLng(50.0, 14.0); // Default to central Europe
                          }
                        } else {
                          position = LatLng(50.0, 14.0); // Default to central Europe
                        }
                      }

                      return AirspaceFlightInfo(
                        currentPosition: position,
                        currentAltitude: altitude,
                        currentHeading: heading,
                        currentSpeed: speed,
                        openAIPService: openAIPService,
                        onAirspaceSelected: _onAirspaceSelected,
                        onClose: () {
                          setState(() {
                            _showCurrentAirspacePanel = false;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            );
              },
            ),
          ],

          // Navigation and action controls positioned on the left side
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16, // Align with standard padding
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6, // Limit to 60% of screen width
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu, color: Colors.black),
                    tooltip: 'Menu',
                    onSelected: (value) {
                      if (value == 'flight_log') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FlightLogScreen(),
                          ),
                        );
                      } else if (value == 'offline_maps') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OfflineDataScreen(),
                          ),
                        );
                      } else if (value == 'flight_plans') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FlightPlansScreen(),
                          ),
                        );
                      } else if (value == 'toggle_flight_planning') {
                        setState(() {
                          _showFlightPlanning = !_showFlightPlanning;
                          // Auto-create flight plan if none exists (with planning mode OFF)
                          if (_showFlightPlanning &&
                              _flightPlanService.currentFlightPlan == null) {
                            _flightPlanService.createNewFlightPlan(
                              enablePlanning: false,
                            );
                          }
                          // Sync flight plan visibility with panel visibility
                          _flightPlanService.setFlightPlanVisibility(
                            _showFlightPlanning,
                          );
                        });
                        // Note: Planning mode is NOT automatically enabled when showing the panel
                        // Users must explicitly enable it from within the panel
                        // debugPrint('Flight planning panel toggled: $_showFlightPlanning');
                      } else if (value == 'checklists') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ChecklistSettingsScreen(),
                          ),
                        );
                      } else if (value == 'airplane_settings') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AircraftSettingsScreen(),
                          ),
                        );
                      } else if (value == 'licenses') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LicensesScreen(),
                          ),
                        );
                      } else if (value == 'calculators') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CalculatorsScreen(),
                          ),
                        );
                      } else if (value == 'settings') {
                        SettingsDialog.show(context);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'flight_plans',
                        child: Row(
                          children: [
                            Icon(Icons.flight_takeoff, size: 20),
                            SizedBox(width: 8),
                            Text('Flight Plans'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'flight_log',
                        child: Row(
                          children: [
                            Icon(Icons.flight, size: 20),
                            SizedBox(width: 8),
                            Text('Flight Log'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'checklists',
                        child: Row(
                          children: [
                            Icon(Icons.list, size: 20),
                            SizedBox(width: 8),
                            Text('Checklists'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'airplane_settings',
                        child: Row(
                          children: [
                            Icon(Icons.flight, size: 20),
                            SizedBox(width: 8),
                            Text('Aircrafts'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'licenses',
                        child: Row(
                          children: [
                            Icon(Icons.card_membership, size: 20),
                            SizedBox(width: 8),
                            Text('Licenses'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'calculators',
                        child: Row(
                          children: [
                            Icon(Icons.calculate, size: 20),
                            SizedBox(width: 8),
                            Text('Calculators'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'offline_maps',
                        child: Row(
                          children: [
                            Icon(Icons.map, size: 20),
                            SizedBox(width: 8),
                            Text('Offline Data'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings, size: 20),
                            SizedBox(width: 8),
                            Text('Settings'),
                          ],
                        ),
                      ),
                    ],
                    offset: const Offset(0, 48), // Move popup down to avoid overlapping with top panel
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.black),
                    onPressed: _showAirportSearch,
                    tooltip: 'Search airports',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.my_location,
                      color: _autoCenteringEnabled ? Colors.black : Colors.grey,
                    ),
                    onPressed: _centerOnLocation,
                    tooltip: _autoCenteringEnabled
                        ? 'Center on location'
                        : 'Center on location (auto-centering paused)',
                  ),
                  IconButton(
                    icon: Icon(
                      _showStats ? Icons.dashboard : Icons.dashboard_outlined,
                      color: _showStats ? Colors.blue : Colors.black,
                    ),
                    onPressed: _toggleStats,
                    tooltip: 'Toggle flight dashboard',
                  ),
                ],
              ),
            ),
            ),
          ),
          // Location loading indicator (small, non-blocking)
          if (!_isLocationLoaded)
            const Positioned(
              top: 60,
              right: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Getting location...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Error message
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // License warning widget - only show when not tracking
          if (!_flightService.isTracking)
            const Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: LicenseWarningWidget(),
            ),

          // Flight planning UI panels
          Consumer<FlightPlanService>(
            builder: (context, flightPlanService, child) {
              return Stack(
                children: [
                  // Flight Planning Panel - new unified draggable panel
                  if (_showFlightPlanning)
                    Positioned(
                      left: _flightPlanningPanelPosition.dx,
                      top: _flightPlanningPanelPosition.dy,
                      child: Draggable<String>(
                        data: 'flight_planning_panel',
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width < 600
                                ? MediaQuery.of(context).size.width - 16
                                : 600,
                            child: FlightPlanningPanel(
                              isExpanded: _flightPlanningExpanded,
                              onClose: () {
                                setState(() {
                                  _showFlightPlanning = false;
                                });
                                // Stop planning mode - check if we need to toggle
                                if (_flightPlanService.isPlanning) {
                                  _flightPlanService.togglePlanningMode();
                                }
                                // Hide flight plan layer on map
                                _flightPlanService.setFlightPlanVisibility(
                                  false,
                                );
                                // debugPrint('Flight planning closed from panel');
                              },
                            ),
                          ),
                        ),
                        childWhenDragging: Container(),
                        onDragEnd: (details) {
                          setState(() {
                            final screenSize = MediaQuery.of(context).size;
                            final isPhone = screenSize.width < 600;

                            double newX = details.offset.dx;
                            double newY = details.offset.dy;

                            final panelWidth = isPhone
                                ? screenSize.width - 16
                                : 600;
                            final panelHeight = _flightPlanningExpanded
                                ? 600
                                : 50;

                            // Constrain position
                            final minMargin = isPhone ? 8.0 : 16.0;

                            if (!isPhone) {
                              newX = newX.clamp(
                                minMargin,
                                screenSize.width - panelWidth - minMargin,
                              );
                            } else {
                              newX = minMargin;
                            }

                            newY = newY.clamp(
                              MediaQuery.of(context).padding.top + 60,
                              screenSize.height - panelHeight - 100,
                            );

                            _flightPlanningPanelPosition = Offset(newX, newY);
                          });
                        },
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width < 600
                              ? MediaQuery.of(context).size.width - 16
                              : 600,
                          child: FlightPlanningPanel(
                            isExpanded: _flightPlanningExpanded,
                            onExpandedChanged: (expanded) {
                              setState(() {
                                _flightPlanningExpanded = expanded;
                              });
                            },
                            onClose: () {
                              setState(() {
                                _showFlightPlanning = false;
                              });
                              // Stop planning mode - check if we need to toggle
                              if (_flightPlanService.isPlanning) {
                                _flightPlanService.togglePlanningMode();
                              }
                              // Hide flight plan layer on map
                              _flightPlanService.setFlightPlanVisibility(false);
                              // debugPrint('Flight planning closed from panel');
                            },
                          ),
                        ),
                      ),
                    ),
                  // Floating waypoint panel for selected waypoint
                  if (_selectedWaypointIndex != null &&
                      flightPlanService.currentFlightPlan != null &&
                      _selectedWaypointIndex! <
                          flightPlanService.currentFlightPlan!.waypoints.length)
                    FloatingWaypointPanel(
                      waypointIndex: _selectedWaypointIndex!,
                      onClose: () {
                        setState(() {
                          _selectedWaypointIndex = null;
                        });
                      },
                    ),
                ],
              );
            },
          ),
          // Loading progress bar at the top
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LoadingProgressBar(),
          ),
          
          // Zoom controls in bottom left corner
          Positioned(
            bottom: 20,
            left: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom in button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      if (currentZoom < _maxZoom) {
                        _mapController.move(
                          _mapController.camera.center,
                          currentZoom + 1,
                        );
                        // Trigger updates for all layers
                        _loadAirports();
                        if (_showNavaids) _loadNavaids();
                      }
                    },
                    tooltip: 'Zoom In',
                  ),
                ),
                const SizedBox(height: 4),
                // Zoom out button
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      if (currentZoom > _minZoom) {
                        _mapController.move(
                          _mapController.camera.center,
                          currentZoom - 1,
                        );
                        // Trigger updates for all layers
                        _loadAirports();
                        if (_showNavaids) _loadNavaids();
                      }
                    },
                    tooltip: 'Zoom Out',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerToggle({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: isActive ? Colors.blue : Colors.black),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }


  Color _getSegmentColor(String segmentType) {
    switch (segmentType) {
      case 'takeoff':
        return Colors.green;
      case 'landing':
        return Colors.red;
      case 'cruise':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getSegmentIcon(String segmentType) {
    switch (segmentType) {
      case 'takeoff':
        return Icons.arrow_upward;
      case 'landing':
        return Icons.arrow_downward;
      case 'cruise':
        return Icons.flight;
      default:
        return Icons.circle;
    }
  }
}
