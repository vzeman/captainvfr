import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

// Screens would be imported as needed

// Models
import '../models/airport.dart';
import '../models/runway.dart';
import '../models/navaid.dart';
import '../models/obstacle.dart';
import '../models/hotspot.dart';
import '../models/flight_segment.dart' as flight_seg;
import '../models/flight_plan.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';

// Services
import '../services/airport_service.dart';
import '../services/runway_service.dart';
import '../services/navaid_service.dart';
import '../services/flight_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/offline_map_service.dart';
import '../services/offline_tile_provider.dart';
import '../services/flight_plan_service.dart';
import '../services/openaip_service.dart';
import '../services/analytics_service.dart';
import '../services/spatial_airspace_service.dart';
import '../services/settings_service.dart';
import '../services/cache_service.dart';
import '../services/notam_service_v3.dart';

// Widgets
import '../widgets/navaid_marker.dart';
import '../widgets/optimized_marker_layer.dart';
import '../widgets/airport_info_sheet.dart';
import '../widgets/flight_dashboard.dart';
import '../widgets/airport_search_dialog.dart';
import '../widgets/metar_overlay.dart';
import '../widgets/flight_plan_overlay.dart';
import '../widgets/flight_planning_panel.dart';
import '../widgets/license_warning_widget.dart';
import '../widgets/floating_waypoint_panel.dart';
import '../widgets/optimized_spatial_airspaces_overlay.dart';
import '../widgets/airspace_flight_info.dart';
import '../widgets/loading_progress_bar.dart';
import '../widgets/themed_dialog.dart';
import '../widgets/performance_overlay_widget.dart';
import '../widgets/map_zoom_controls.dart';

// Utilities
import '../utils/frame_aware_scheduler.dart';
import '../utils/performance_monitor.dart';
import '../utils/airspace_utils.dart';

// Extracted components
import 'map/constants/map_constants.dart';
import 'map/controllers/map_state_controller.dart';
import 'map/components/position_tracking_button.dart';
import 'map/components/layer_toggle_button.dart';
import 'map/components/map_controls_panel.dart';
import 'map/components/map_dialogs.dart';
import 'map/utils/map_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  // Logger
  final Logger _logger = Logger(level: Level.warning);
  
  // Controllers
  late MapStateController _mapStateController;
  late MapController _mapController;
  
  // Services (initialized in initState)
  AirportService? _airportService;
  RunwayService? _runwayService;
  NavaidService? _navaidService;
  FlightService? _flightService;
  FlightPlanService? _flightPlanService;
  LocationService? _locationService;
  WeatherService? _weatherService;
  OfflineMapService? _offlineMapService;
  AnalyticsService? _analyticsService;
  SettingsService? _settingsService;
  
  OpenAIPService? _openAIPService;
  SpatialAirspaceService? _spatialAirspaceService;
  
  // Service initialization flags
  bool _servicesInitialized = false;
  
  // Map key
  final GlobalKey _mapKey = GlobalKey();
  
  // State variables for data
  List<Airport> _airports = [];
  Map<String, List<Runway>> _airportRunways = {};
  List<Navaid> _navaids = [];
  List<Airspace> _airspaces = [];
  List<ReportingPoint> _reportingPoints = [];
  List<Obstacle> _obstacles = [];
  List<Hotspot> _hotspots = [];
  
  // Flight planning state
  bool _showFlightPlanning = false;
  bool _isFlightPlanningExpanded = false;
  int? _selectedWaypointIndex;
  bool _waypointJustTapped = false;
  
  // Panel positions
  Offset _flightDataPanelPosition = MapConstants.defaultFlightDataPanelPosition;
  Offset _airspacePanelPosition = MapConstants.defaultAirspacePanelPosition;
  Offset _flightPlanningPanelPosition = MapConstants.defaultFlightPlanningPanelPosition;
  Offset _togglePanelPosition = MapConstants.defaultTogglePanelPosition;
  
  // UI state
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showAirspaceInfoPanel = false;
  List<Airspace> _selectedAirspaces = [];
  
  // Location stream
  StreamSubscription<Position>? _positionStreamSubscription;
  
  // Timers for NOTAM prefetching
  Timer? _notamPrefetchTimer;
  int _notamFetchGeneration = 0;
  
  // Getters for services
  OpenAIPService get openAIPService {
    _openAIPService ??= OpenAIPService();
    return _openAIPService!;
  }
  
  SpatialAirspaceService get spatialAirspaceService {
    _spatialAirspaceService ??= SpatialAirspaceService();
    return _spatialAirspaceService!;
  }
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _mapStateController = MapStateController();
    _mapController = MapController();
    
    // Add listener to app lifecycle
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize services and location in background
    _initServicesAndData();
    
    // Start location initialization
    _initLocationInBackground();
    
    // Load flight planning panel state
    _loadFlightPlanningPanelState();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize services if not already done
    if (!_servicesInitialized) {
      _initializeServices();
    }
    
    // Setup cache listener after services are initialized
    if (_servicesInitialized) {
      _setupCacheListener();
      _setupFlightServiceListener();
    }
  }
  
  void _initializeServices() {
    try {
      // Get services from context
      _airportService = context.read<AirportService>();
      _runwayService = context.read<RunwayService>();
      _navaidService = context.read<NavaidService>();
      _flightService = context.read<FlightService>();
      _flightPlanService = context.read<FlightPlanService>();
      _locationService = context.read<LocationService>();
      _weatherService = context.read<WeatherService>();
      _offlineMapService = context.read<OfflineMapService>();
      _analyticsService = context.read<AnalyticsService>();
      _settingsService = context.read<SettingsService>();
      
      _servicesInitialized = true;
      
      // Add listener for flight plan updates
      _flightPlanService?.addListener(_onFlightPlanUpdated);
    } catch (e) {
      _logger.e('Error initializing services: $e');
    }
  }
  
  // Initialize services and load initial data
  Future<void> _initServicesAndData() async {
    try {
      // Load initial map data after a small delay to ensure UI is built
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Load initial data based on current map view
      if (mounted && _mapController.camera != null) {
        await _loadAirports();
      }
    } catch (e) {
      _logger.e('Error initializing services and data: $e');
    }
  }
  
  // Setup listener for cache updates
  void _setupCacheListener() {
    CacheService().addUpdateListener(_onCacheUpdated);
  }
  
  // Handle cache updates
  void _onCacheUpdated() {
    if (!mounted) return;
    
    // Refresh the current view data
    _loadAirports();
    if (_mapStateController.showNavaids) _loadNavaids();
    if (_mapStateController.showAirspaces) {
      _loadAirspaces();
      _loadReportingPoints();
    }
    if (_mapStateController.showObstacles) _loadObstacles();
    if (_mapStateController.showHotspots) _loadHotspots();
  }
  
  // Setup listener for flight service updates
  void _setupFlightServiceListener() {
    _flightService?.addListener(_onFlightPathUpdated);
  }
  
  // Handle flight path updates from the flight service
  void _onFlightPathUpdated() {
    if (!mounted) return;
    
    // Check if auto-centering should be enabled for flight tracking
    if (_flightService != null && _flightService!.isTracking) {
      // During active flight tracking, keep auto-centering enabled
      if (!_mapStateController.autoCenteringEnabled) {
        setState(() {
          _mapStateController.enableAutoCentering();
        });
      }
      
      // Update map position to follow the aircraft
      final currentPosition = _flightService!.currentPosition;
      if (currentPosition != null && _mapStateController.autoCenteringEnabled) {
        _mapController.move(
          LatLng(currentPosition.latitude, currentPosition.longitude),
          _mapController.camera.zoom,
        );
      }
    }
  }
  
  // Handle flight plan updates from the flight plan service
  void _onFlightPlanUpdated() {
    if (!mounted) return;
    
    setState(() {
      _showFlightPlanning = _flightPlanService?.currentFlightPlan != null;
    });
    
    // Prefetch NOTAMs for airports in the flight plan
    if (_flightPlanService?.currentFlightPlan != null) {
      _prefetchFlightPlanNotams();
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _resumeAllTimers();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _pauseAllTimers();
        break;
    }
  }
  
  void _pauseAllTimers() {
    _mapStateController.pauseAllTimers();
    _notamPrefetchTimer?.cancel();
  }
  
  void _resumeAllTimers() {
    _mapStateController.resumeAllTimers();
    if (_mapStateController.positionTrackingEnabled) {
      _startPositionTracking();
    }
  }
  
  @override
  void dispose() {
    // Remove listeners
    WidgetsBinding.instance.removeObserver(this);
    _flightPlanService?.removeListener(_onFlightPlanUpdated);
    _flightService?.removeListener(_onFlightPathUpdated);
    CacheService().removeUpdateListener(_onCacheUpdated);
    
    // Cancel subscriptions
    _positionStreamSubscription?.cancel();
    _notamPrefetchTimer?.cancel();
    
    // Dispose controllers
    _mapStateController.dispose();
    _mapController.dispose();
    
    super.dispose();
  }
  
  // Initialize location in background without blocking the UI
  Future<void> _initLocationInBackground() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          await MapDialogs.showLocationServicesDisabledDialog(context);
        }
        return;
      }
      
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final shouldRequest = await MapDialogs.showLocationPermissionDialog(context);
          if (shouldRequest) {
            permission = await Geolocator.requestPermission();
          }
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          await MapDialogs.showOpenSettingsDialog(context);
        }
        return;
      }
      
      if (permission == LocationPermission.denied) {
        return;
      }
      
      // Get current location
      final position = await Geolocator.getCurrentPosition();
      
      if (mounted) {
        setState(() {
          _mapStateController.updatePosition(position);
        });
        
        // Move map to current location
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          MapConstants.initialZoom,
        );
        
        // Start location stream
        _startLocationStream();
        
        // Handle location loaded
        _onLocationLoaded();
      }
    } catch (e) {
      _logger.e('Error initializing location: $e');
      if (mounted) {
        await MapDialogs.showErrorDialog(context, 'Failed to get location: $e');
      }
    }
  }
  
  // Add location stream subscription
  void _startLocationStream() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _mapStateController.updatePosition(position);
        });
      }
    });
  }
  
  // Load flight planning panel expanded state from SharedPreferences
  Future<void> _loadFlightPlanningPanelState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isExpanded = prefs.getBool(MapConstants.keyFlightPlanningExpanded) ?? true;
      
      if (mounted) {
        setState(() {
          _isFlightPlanningExpanded = isExpanded;
        });
      }
    } catch (e) {
      _logger.e('Error loading flight planning panel state: $e');
    }
  }
  
  // Save flight planning panel expanded state to SharedPreferences
  Future<void> _saveFlightPlanningPanelState(bool isExpanded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(MapConstants.keyFlightPlanningExpanded, isExpanded);
    } catch (e) {
      _logger.e('Error saving flight planning panel state: $e');
    }
  }
  
  // Handle actions after location is loaded
  void _onLocationLoaded() {
    // Load nearby airports
    _loadNearbyAirports(
      LatLng(
        _mapStateController.currentPosition!.latitude,
        _mapStateController.currentPosition!.longitude,
      ),
      MapUtils.calculateRadiusForZoom(_mapController.camera.zoom),
    );
    
    // Load other map data if enabled
    if (_mapStateController.showNavaids) _loadNavaids();
    if (_mapStateController.showAirspaces) {
      _loadAirspaces();
      _loadReportingPoints();
    }
    if (_mapStateController.showObstacles) _loadObstacles();
    if (_mapStateController.showHotspots) _loadHotspots();
  }
  
  // Continue with remaining methods...
  // [The rest of the methods would be added here, properly refactored to use the extracted components]
  
  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }
  
  Widget _buildContent(BuildContext context) {
    // This will be the refactored build method using the extracted components
    return Container(); // Placeholder
  }
}