import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'flight_log_screen.dart';
import 'flight_plans_screen.dart';
import 'aircraft_settings_screen.dart';
import 'checklist_settings_screen.dart';
import 'calculators_screen.dart';
import 'settings_screen.dart';
import 'logbook/logbook_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../models/airport.dart';
import '../models/runway.dart';
import '../models/navaid.dart';
import '../models/obstacle.dart';
import '../models/hotspot.dart';
import '../models/flight_segment.dart' as flight_seg;
import '../models/flight_plan.dart';
import '../services/airport_service.dart';
import '../services/runway_service.dart';
import '../services/navaid_service.dart';
import '../services/flight_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/offline_map_service.dart';
import '../services/offline_tile_provider.dart';
import '../services/flight_plan_service.dart';
import '../services/flight_plan_tile_download_service.dart';
import '../screens/offline_data/controllers/offline_data_state_controller.dart';
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
import '../utils/frame_aware_scheduler.dart';
import '../widgets/sensor_notification_widget.dart';
import '../utils/performance_monitor.dart';
import '../services/openaip_service.dart';
import '../services/analytics_service.dart';
import '../services/spatial_airspace_service.dart';
import '../services/settings_service.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import '../utils/airspace_utils.dart';
import '../widgets/loading_progress_bar.dart';
import '../widgets/themed_dialog.dart';
import '../widgets/performance_overlay_widget.dart';
import '../widgets/map_zoom_controls.dart';
import '../services/cache_service.dart';
import '../services/notam_service_v3.dart';

// Extracted components
import 'map/constants/map_constants.dart';
import 'map/controllers/map_state_controller.dart';
import 'map/components/position_tracking_button.dart';
import 'map/components/layer_toggle_button.dart';

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
  
  // Services
  late final FlightService _flightService;
  late final AirportService _airportService;
  late final RunwayService _runwayService;
  late final NavaidService _navaidService;
  late final LocationService _locationService;
  late final WeatherService _weatherService;
  OfflineMapService?
  _offlineMapService; // Make nullable to prevent LateInitializationError
  late final FlightPlanService _flightPlanService;
  FlightPlanTileDownloadService? _tileDownloadService;
  OfflineDataStateController? _offlineDataController;
  OpenAIPService? _openAIPService;
  SpatialAirspaceService? _spatialAirspaceService;
  late final MapController _mapController;
  late final CacheService _cacheService;
  Timer? _performanceReportTimer;

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
  bool _locationNotificationShown = false; // Track if we've shown the location notification
  bool _servicesInitialized = false;
  bool _isInitializing = false; // Guard against concurrent initialization
  bool _showFlightPlanning = false; // Toggle for integrated flight planning
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
      false; // Control visibility of current airspace panel
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
      false; // Track expanded state of flight planning panel (default collapsed)
  Size? _lastFlightPlanningScreenSize; // Track screen size for position adjustment

  // Waypoint selection state
  int? _selectedWaypointIndex;
  bool _isDraggingWaypoint = false;

  // Location and map state
  Position? _currentPosition;
  List<LatLng> _flightPathPoints = [];
  List<flight_seg.FlightSegment> _flightSegments = [];
  List<Airport> _airports = [];
  Map<String, List<Runway>> _airportRunways = {};
  List<Navaid> _navaids = [];
  List<ReportingPoint> _reportingPoints = [];
  List<Obstacle> _obstacles = [];
  List<Hotspot> _hotspots = [];

  // UI state
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Map settings are now in MapConstants

  // Auto-centering control
  bool _autoCenteringEnabled = true;
  Timer? _autoCenteringTimer;
  // Auto-centering delay is now in MapConstants
  bool _wasTracking = false;
  
  // Countdown display for auto-centering
  int _autoCenteringCountdown = 0;
  Timer? _countdownTimer;
  
  // Position tracking control
  bool _positionTrackingEnabled = true;  // Default to enabled
  Timer? _positionUpdateTimer;
  // Position update interval is now in MapConstants

  // Helper to check if any input field has focus
  bool get _hasInputFocus {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    
    // Check if the focused widget is a text input
    final focusedWidget = primaryFocus.context?.widget;
    return focusedWidget is EditableText || 
           primaryFocus.context?.widget.toString().contains('TextField') == true ||
           primaryFocus.context?.widget.toString().contains('TextFormField') == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize controllers
    _mapController = MapController();
    _mapStateController = MapStateController();

    // Load flight planning panel state from SharedPreferences
    _loadFlightPlanningPanelState();

    // Start location loading in background without blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationLoadingNotification();
      _initLocationInBackground();
      
      // Log screen view
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logScreenView(screenName: 'map_screen');
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
        _runwayService = RunwayService();
        // Initialize runway service
        _runwayService.initialize();
        _navaidService = Provider.of<NavaidService>(context, listen: false);
        _weatherService = Provider.of<WeatherService>(context, listen: false);
        _flightPlanService = Provider.of<FlightPlanService>(
          context,
          listen: false,
        );
        
        // Set up callback to fit entire flight plan when loaded
        _flightPlanService.onFlightPlanLoaded = (flightPlan) {
          if (flightPlan.waypoints.isNotEmpty) {
            // Fit the entire flight plan in view
            _fitFlightPlanBounds();
            
            // Load data for the new area
            _loadAirports();
            if (_mapStateController.showNavaids) {
              _loadNavaids();
            }
            if (_mapStateController.showAirspaces) {
              _loadAirspaces();
              _loadReportingPoints();
            }
            if (_mapStateController.showMetar) {
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
        
        
        // Start performance monitoring (only in debug mode)
        if (kDebugMode) {
          _performanceReportTimer = Timer.periodic(const Duration(seconds: 30), (_) {
            PerformanceMonitor().printPerformanceReport();
          });
        }

        // Listen to flight service updates
        _setupFlightServiceListener();

        // Listen to cache updates
        _setupCacheListener();

        // Start loading data in background if location is already available
        if (_currentPosition != null && !_isLocationLoaded) {
          _onLocationLoaded();
        }

        // Start position tracking if enabled (default is true)
        if (_positionTrackingEnabled && _positionUpdateTimer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startPositionTracking();
          });
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
    if (_mapStateController.showAirspaces && mounted) {
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
    if (mounted && !_hasInputFocus) {
      setState(() {
        // Check if tracking just started
        if (_flightService.isTracking && !_wasTracking) {
          // Re-enable auto-centering when tracking starts
          _autoCenteringEnabled = true;
          _autoCenteringTimer?.cancel();
          _countdownTimer?.cancel();
          _autoCenteringCountdown = 0;
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
    if (mounted && !_hasInputFocus) {
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
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Handle screen size changes (orientation changes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleOrientationChange();
      }
    });
  }

  void _handleOrientationChange() {
    final screenSize = MediaQuery.of(context).size;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    
    setState(() {
      // Adjust toggle panel position to stay within bounds
      final togglePanelWidth = 50.0;
      final maxRightPosition = screenSize.width - togglePanelWidth - 16;
      if (_togglePanelRightPosition > maxRightPosition) {
        _togglePanelRightPosition = maxRightPosition;
      }
      
      // Ensure toggle panel stays within vertical bounds
      final maxTopPosition = (screenSize.height - safeAreaTop - 300) / screenSize.height;
      if (_togglePanelTopPosition > maxTopPosition) {
        _togglePanelTopPosition = maxTopPosition;
      }
      
      // Adjust flight data panel position
      final isPhone = screenSize.width < 600;
      final panelWidth = isPhone ? screenSize.width - 16 : 600;
      final panelHeight = _flightDashboardExpanded ? 260 : 60;
      final minMargin = isPhone ? 8.0 : 16.0;
      
      // Check horizontal bounds
      double newX = _flightDataPanelPosition.dx;
      if (newX + panelWidth > screenSize.width) {
        newX = (screenSize.width - panelWidth - minMargin).clamp(minMargin, screenSize.width - panelWidth - minMargin);
      }
      
      // Check vertical bounds (bottom distance)
      double bottomDistance = _flightDataPanelPosition.dy;
      // Ensure panel stays within screen bounds
      // Maximum bottom distance is screen height minus panel height minus top safe area
      final maxBottomDistance = screenSize.height - panelHeight - safeAreaTop - 50; // 50px minimum from top
      bottomDistance = bottomDistance.clamp(16.0, maxBottomDistance);
      
      _flightDataPanelPosition = Offset(
        isPhone ? minMargin : newX, // On phones, keep centered
        bottomDistance
      );
      
      // Adjust airspace panel position
      if (_airspacePanelPosition != null) {
        final panelWidth = screenSize.width < 600 ? screenSize.width - 16 : 600;
        if (_airspacePanelPosition!.dx + panelWidth > screenSize.width) {
          _airspacePanelPosition = Offset(
            (screenSize.width - panelWidth).clamp(0, screenSize.width - panelWidth),
            _airspacePanelPosition!.dy
          );
        }
      }
      
      // Adjust flight planning panel position
      _adjustFlightPlanningPanelPosition(screenSize);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Pause all timers when app is not active
        _pauseAllTimers();
        break;
      case AppLifecycleState.resumed:
        // Resume timers when app is active
        _resumeAllTimers();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }
  
  void _pauseAllTimers() {
    _positionUpdateTimer?.cancel();
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    _airspaceDebounceTimer?.cancel();
    _locationStreamSubscription?.pause();
  }
  
  void _resumeAllTimers() {
    // Resume position updates if tracking was enabled
    if (_positionTrackingEnabled && !_flightService.isTracking) {
      _startPositionTracking();
    }
    
    // Resume location stream
    _locationStreamSubscription?.resume();
  }

  /// Validate flight plan tiles on startup
  Future<void> _validateFlightPlanTiles() async {
    // Wait a bit to ensure UI is ready
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted || _tileDownloadService == null || _offlineDataController == null) return;
    
    // Check if validation is enabled
    if (!_offlineDataController!.validateTilesOnStartup) return;
    
    try {
      // Get all saved flight plans
      final flightPlans = _flightPlanService.savedFlightPlans;
      if (flightPlans.isEmpty) return;
      
      // Show progress indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Checking flight plan map tiles...')),
              ],
            ),
          ),
        );
      }
      
      // Validate all flight plans
      final validationResults = await _tileDownloadService!.validateAllFlightPlans(flightPlans);
      
      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // If there are missing tiles, show dialog
      if (validationResults.isNotEmpty && mounted) {
        await _showMissingTilesDialog(validationResults);
      }
    } catch (e) {
      debugPrint('Error validating flight plan tiles: $e');
      // Close progress dialog if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    }
  }
  
  /// Show dialog for missing tiles with download option
  Future<void> _showMissingTilesDialog(List<FlightPlanValidationResult> validationResults) async {
    final totalMissing = validationResults.fold<int>(0, (sum, result) => sum + result.missingTiles);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Missing Map Tiles'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Some flight plans are missing offline map tiles. '
                'Would you like to download them now?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Total missing tiles: $totalMissing',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...validationResults.map((result) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.flight, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${result.flightPlan.name}: ${result.missingTiles} tiles '
                        '(${result.percentageMissing.toStringAsFixed(1)}% missing)',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download Now'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      // Download missing tiles for all flight plans
      for (final validationResult in validationResults) {
        if (mounted) {
          await _tileDownloadService!.downloadTilesForFlightPlan(
            flightPlan: validationResult.flightPlan,
            context: context,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Cancel all scheduled operations
    FrameAwareScheduler().cancelAll();
    _performanceReportTimer?.cancel();
    _locationRetryTimer?.cancel();
    _locationStreamSubscription?.cancel();
    
    // Cancel any active tile downloads
    _tileDownloadService?.cancelAllDownloads();
    
    _flightService.removeListener(_onFlightPathUpdated);
    _flightPlanService.removeListener(_onFlightPlanUpdated);
    _cacheService.removeListener(_onCacheUpdated);
    _debounceTimer?.cancel();
    _airspaceDebounceTimer?.cancel();
    _notamPrefetchTimer?.cancel();
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    _positionUpdateTimer?.cancel();
    _mapController.dispose();
    _flightService.dispose();
    _spatialAirspaceService?.dispose();
    _offlineDataController?.dispose();
    super.dispose();
  }

  // Initialize location in background without blocking the UI
  Timer? _locationRetryTimer;
  StreamSubscription<Position>? _locationStreamSubscription;
  
  Future<void> _initLocationInBackground() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          // Automatically enable position tracking when location permission is granted
          _positionTrackingEnabled = true;
          _autoCenteringEnabled = true;
        });

        // Location loaded successfully, handle the rest
        _onLocationLoaded();
        // Start listening for location updates
        _startLocationStream();
        // Start position tracking since we have permission
        await _startPositionTracking();
      }
    } catch (e) {
      // Don't show error popup, just use default location silently
      if (mounted) {
        setState(() {
          // Use a default position if location fails
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
        // Don't retry automatically - wait for user to enable position tracking
      }
    }
  }
  
  // Add location stream subscription
  void _startLocationStream() {
    _locationStreamSubscription?.cancel();
    _locationStreamSubscription = _locationService.getPositionStream().listen(
      (Position position) {
        if (mounted && !_hasInputFocus) {
          setState(() {
            _currentPosition = position;
          });
        }
      },
      onError: (error) {
        // Handle stream errors silently
      },
    );
  }

  // Show location loading notification
  void _showLocationLoadingNotification() {
    if (_locationNotificationShown) return;
    _locationNotificationShown = true;
    
    // Show location loading notification at the bottom
    if (mounted) {
      setState(() {
        // Flag to show the notification
      });
    }
    
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismissLocationNotification();
      }
    });
  }
  
  // Dismiss location loading notification
  void _dismissLocationNotification() {
    if (mounted) {
      setState(() {
        _locationNotificationShown = false;
      });
    }
  }

  // Load flight planning panel expanded state from SharedPreferences
  Future<void> _loadFlightPlanningPanelState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isExpanded = prefs.getBool(MapConstants.keyFlightPlanningExpanded) ?? false; // Default collapsed
      if (mounted) {
        setState(() {
          _flightPlanningExpanded = isExpanded;
        });
      }
    } catch (e) {
      // If there's an error loading, keep the default state (collapsed)
    }
  }

  // Save flight planning panel expanded state to SharedPreferences
  Future<void> _saveFlightPlanningPanelState(bool isExpanded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(MapConstants.keyFlightPlanningExpanded, isExpanded);
    } catch (e) {
      // Ignore save errors - not critical functionality
    }
  }

  // Adjust flight planning panel position for screen size changes (orientation)
  void _adjustFlightPlanningPanelPosition(Size newScreenSize) {
    if (_lastFlightPlanningScreenSize != null && 
        (_lastFlightPlanningScreenSize!.width != newScreenSize.width || 
         _lastFlightPlanningScreenSize!.height != newScreenSize.height)) {
      
      // Calculate relative position as percentages
      final relativeX = _flightPlanningPanelPosition.dx / _lastFlightPlanningScreenSize!.width;
      final relativeY = _flightPlanningPanelPosition.dy / _lastFlightPlanningScreenSize!.height;
      
      // Determine panel dimensions based on screen size and orientation
      final isPhone = newScreenSize.width < 600;
      final panelWidth = isPhone ? newScreenSize.width - 16 : 600.0;
      final panelHeight = _flightPlanningExpanded ? 600.0 : 60.0;
      
      // Apply to new screen size and ensure panel stays visible
      // Ensure the clamp bounds are valid (min <= max)
      final maxX = math.max(0.0, newScreenSize.width - panelWidth);
      final maxY = math.max(0.0, newScreenSize.height - panelHeight);
      
      final newX = (relativeX * newScreenSize.width).clamp(0.0, maxX);
      final newY = (relativeY * newScreenSize.height).clamp(0.0, maxY);
      
      final newPosition = Offset(newX, newY);
      
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _flightPlanningPanelPosition = newPosition;
          });
        }
      });
    }
    _lastFlightPlanningScreenSize = newScreenSize;
  }

  // Handle actions after location is loaded
  void _onLocationLoaded() {
    if (_isLocationLoaded) return; // Prevent duplicate calls
    _isLocationLoaded = true;
    
    // Dismiss location loading notification
    _dismissLocationNotification();

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
              MapConstants.initialZoom,
              -_flightService.currentHeading!,
            );
          } else {
            _mapController.move(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              MapConstants.initialZoom,
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
                  MapConstants.initialZoom,
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
        if (_mapStateController.showNavaids) {
          _loadNavaids();
        }

        // Load airspaces if they should be shown
        if (_mapStateController.showAirspaces) {
          _loadAirspaces();
          _loadReportingPoints();
        }
        
        // Load obstacles if they should be shown
        if (_mapStateController.showObstacles) {
          _loadObstacles();
        }
        
        // Load hotspots if they should be shown
        if (_mapStateController.showHotspots) {
          _loadHotspots();
        }
      }
    });
  }

  // Load airports in the current map view with debouncing
  Future<void> _loadAirports() async {
    return MapProfiler.profileMapOperation('loadAirports', () async {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();

    // Set a new debounce timer (500ms delay for better performance)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      try {
        // Check if map controller is ready
        if (!mounted) {
          // debugPrint('📍 _loadAirports: Widget not mounted, returning');
          return;
        }

        final bounds = _mapController.camera.visibleBounds;
        final zoom = _mapController.camera.zoom;

        // First, load runway data for the visible area
        await _runwayService.loadRunwaysForArea(
          minLat: bounds.southWest.latitude,
          maxLat: bounds.northEast.latitude,
          minLon: bounds.southWest.longitude,
          maxLon: bounds.northEast.longitude,
        );

        // Get airports within the current map bounds
        final airports = await _airportService.getAirportsInBounds(
          bounds.southWest,
          bounds.northEast,
        );

        // Get runway data for airports if zoom level is appropriate
        final runwayDataMap = <String, List<Runway>>{};
        if (zoom >= 10) {
          for (final airport in airports) {
            // Pass OpenAIP runway data if available
            final runways = _runwayService.getRunwaysForAirport(
              airport.icao,
              openAIPRunways: airport.openAIPRunways.isNotEmpty ? airport.openAIPRunways : null,
              airportLat: airport.position.latitude,
              airportLon: airport.position.longitude,
            );
            if (runways.isNotEmpty) {
              runwayDataMap[airport.icao] = runways;
            }
          }
        }

        if (mounted) {
          setState(() {
            _airports = airports;
            _airportRunways = runwayDataMap;
          });

          // Refresh weather data for visible airports if METAR overlay is enabled
          if (_mapStateController.showMetar) {
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
        // Don't show error popup for failed airport loading
      }
    });
    });
  }

  /// Refresh weather data for visible airports when map focus changes
  Future<void> _refreshWeatherForVisibleAirports(List<Airport> airports) async {
    if (!_mapStateController.showMetar || airports.isEmpty) return;

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
    return MapProfiler.profileMapOperation('loadNavaids', () async {
      if (!_mapStateController.showNavaids) {
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
    });
  }

  // Load airspaces in the current map view
  Future<void> _loadAirspaces() async {
    return MapProfiler.profileMapOperation('loadAirspaces', () async {
      if (!_mapStateController.showAirspaces) {
        return;
      }

      // Cancel any pending debounce timer
      _airspaceDebounceTimer?.cancel();

      // Set a new debounce timer (500ms delay for airspaces)
      _airspaceDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
        await _loadAirspacesDebounced();
      });
    });
  }

  Future<void> _loadAirspacesDebounced() async {

    try {
      // First, load from cache for immediate display
      final cachedAirspaces = await openAIPService.getCachedAirspaces();

      if (cachedAirspaces.isNotEmpty) {
        // Spatial index will be built automatically by the service
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
      // Silently ignore errors during data loading initialization
    }
  }

  // Refresh airspaces display when new data is available
  Future<void> _refreshAirspacesDisplay() async {
    try {
      await openAIPService.getCachedAirspaces();
      if (mounted) {
        // Rebuild spatial index with new data
        await spatialAirspaceService.rebuildIndex();
      }
    } catch (e) {
      // Silently ignore errors during airspace refresh
      // This is non-critical functionality
    }
  }

  // Load reporting points in the current map view
  Future<void> _loadReportingPoints() async {
    return MapProfiler.profileMapOperation('loadReportingPoints', () async {
      if (!_mapStateController.showAirspaces) {
        return;
      }

      try {
        final bounds = _mapController.camera.visibleBounds;
        
        // Try fast in-memory filtering first (similar to airports)
        final pointsInBounds = openAIPService.getReportingPointsInBounds(
          minLat: bounds.southWest.latitude,
          minLon: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLon: bounds.northEast.longitude,
        );
        
        if (pointsInBounds.isNotEmpty) {
          // Fast path - data already in memory
          if (mounted) {
            setState(() {
              _reportingPoints = pointsInBounds;
            });
          }
          return; // Done - no need for async operations
        }
        
        // Fallback: Load from cache/network if not in memory
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
      } catch (e) {
        // debugPrint('❌ Error loading reporting points: $e');
      }
    });
  }

  // Refresh reporting points display when new data is available
  Future<void> _refreshReportingPointsDisplay() async {
    try {
      final bounds = _mapController.camera.visibleBounds;
      
      // Use optimized in-memory filtering
      final pointsInBounds = openAIPService.getReportingPointsInBounds(
        minLat: bounds.southWest.latitude,
        minLon: bounds.southWest.longitude,
        maxLat: bounds.northEast.latitude,
        maxLon: bounds.northEast.longitude,
      );
      
      if (mounted) {
        setState(() {
          _reportingPoints = pointsInBounds;
        });
      }
    } catch (e) {
      // debugPrint('❌ Error refreshing reporting points display: $e');
    }
  }
  
  // Load obstacles within the current map bounds
  Future<void> _loadObstacles() async {
    return MapProfiler.profileMapOperation('loadObstacles', () async {
      if (!_mapStateController.showObstacles) {
        return;
      }

      try {
        final bounds = _mapController.camera.visibleBounds;
        
        // Load obstacles from tiled data
        final obstacles = await openAIPService.getObstaclesForArea(
          minLat: bounds.southWest.latitude,
          minLon: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLon: bounds.northEast.longitude,
        );
        
        // Loaded ${obstacles.length} obstacles for area
        
        if (mounted) {
          setState(() {
            _obstacles = obstacles;
          });
        }
      } catch (e) {
        debugPrint('❌ Error loading obstacles: $e');
      }
    });
  }
  
  // Load hotspots within the current map bounds
  Future<void> _loadHotspots() async {
    return MapProfiler.profileMapOperation('loadHotspots', () async {
      if (!_mapStateController.showHotspots) {
        return;
      }

      try {
        final bounds = _mapController.camera.visibleBounds;
        
        // Load hotspots from tiled data
        final hotspots = await openAIPService.getHotspotsForArea(
          minLat: bounds.southWest.latitude,
          minLon: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLon: bounds.northEast.longitude,
        );

        if (mounted) {
          setState(() {
            _hotspots = hotspots;
          });
        }
      } catch (e) {
        // debugPrint('❌ Error loading hotspots: $e');
      }
    });
  }

  // Start auto-centering countdown
  void _startAutoCenteringCountdown() {
    setState(() {
      _autoCenteringCountdown = MapConstants.autoCenteringDelay.inSeconds;
    });
    
    // Cancel any existing timers
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    
    // Start countdown timer that updates every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_hasInputFocus) {
        setState(() {
          _autoCenteringCountdown--;
        });
        
        if (_autoCenteringCountdown <= 0) {
          timer.cancel();
          _countdownTimer = null;
        }
      }
    });
    
    // Start the actual auto-centering timer
    _autoCenteringTimer = Timer(MapConstants.autoCenteringDelay, () {
      if (mounted && (_flightService.isTracking || _positionTrackingEnabled)) {
        setState(() {
          _autoCenteringEnabled = true;
          _autoCenteringCountdown = 0;
        });
      }
    });
  }
  
  // Handle zoom button changes to trigger map updates
  void _onZoomButtonPressed() {
    // Use frame-aware scheduler for staggered loading (same as gesture-based zoom)
    final scheduler = FrameAwareScheduler();
    
    // Load airports first (highest priority)
    scheduler.scheduleOperation(
      id: 'load_airports',
      operation: _loadAirports,
      debounce: const Duration(milliseconds: 300),
      highPriority: true,
    );
    
    // Load navaids with delay
    if (_mapStateController.showNavaids) {
      scheduler.scheduleOperation(
        id: 'load_navaids',
        operation: _loadNavaids,
        debounce: const Duration(milliseconds: 600),
      );
    }
    
    // Reporting points with more delay
    if (_mapStateController.showAirspaces) {
      scheduler.scheduleOperation(
        id: 'load_reporting_points',
        operation: _loadReportingPoints,
        debounce: const Duration(milliseconds: 800),
      );
    }
    
    // Obstacles with delay
    if (_mapStateController.showObstacles) {
      scheduler.scheduleOperation(
        id: 'load_obstacles',
        operation: _loadObstacles,
        debounce: const Duration(milliseconds: 900),
      );
    }
    
    // Hotspots with delay  
    if (_mapStateController.showHotspots) {
      scheduler.scheduleOperation(
        id: 'load_hotspots',
        operation: _loadHotspots,
        debounce: const Duration(milliseconds: 950),
      );
    }
  }

  // Toggle position tracking
  Future<void> _togglePositionTracking() async {
    setState(() {
      _positionTrackingEnabled = !_positionTrackingEnabled;
    });

    if (_positionTrackingEnabled) {
      // Start position tracking
      await _startPositionTracking();
    } else {
      // Stop position tracking
      _stopPositionTracking();
    }
  }

  // Start position tracking
  Future<void> _startPositionTracking() async {
    // First, center on current location
    try {
      final position = await _locationService.getLastKnownOrCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _autoCenteringEnabled = true;
          _autoCenteringCountdown = 0;
        });

        // Cancel any existing timers
        _autoCenteringTimer?.cancel();
        _countdownTimer?.cancel();

        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _mapController.camera.zoom,
        );
        _loadAirports();
      }
    } catch (e) {
      // Keep _positionTrackingEnabled as true even on error
      // so it will automatically start working when permission is granted
      
      if (mounted) {
        // Check if it's a permission error
        if (e.toString().contains('denied') || e.toString().contains('permission')) {
          // Permission denied - OS already showed the permission dialog
          // Just fail silently as the user denied permission
        } else {
          // Other location errors
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get current location')),
          );
        }
        return;
      }
    }

    // Start periodic position updates
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(MapConstants.positionUpdateInterval, (_) async {
      if (_positionTrackingEnabled && _autoCenteringEnabled && !_flightService.isTracking) {
        await _updateCurrentPosition();
      }
    });
  }

  // Stop position tracking
  void _stopPositionTracking() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _autoCenteringCountdown = 0;
    });
  }

  // Update current position
  Future<void> _updateCurrentPosition() async {
    try {
      final position = await _locationService.getLastKnownOrCurrentLocation();
      if (mounted && _positionTrackingEnabled && _autoCenteringEnabled && !_hasInputFocus) {
        setState(() {
          _currentPosition = position;
        });

        final settingsService = context.read<SettingsService>();
        
        if (settingsService.rotateMapWithHeading) {
          _mapController.moveAndRotate(
            LatLng(position.latitude, position.longitude),
            _mapController.camera.zoom,
            -position.heading,
          );
        } else {
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            _mapController.camera.zoom,
          );
        }
      }
    } catch (e) {
      // Silently ignore errors during periodic updates
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
      _mapStateController.toggleStats();
    });
  }



  // Toggle heliport visibility
  void _toggleHeliports() {
    setState(() {
      _mapStateController.toggleHeliports();
    });
  }


  // Toggle airspaces visibility
  void _toggleAirspaces() {
    setState(() {
      _mapStateController.toggleAirspaces();
    });
    
    if (_mapStateController.showAirspaces) {
      // Load/refresh data if needed
      _loadAirspaces();
      _loadReportingPoints();
    }
  }
  
  // Toggle obstacles visibility
  void _toggleObstacles() {
    setState(() {
      _mapStateController.toggleObstacles();
    });
    
    if (_mapStateController.showObstacles) {
      // Load obstacles if needed
      _loadObstacles();
    }
  }
  
  // Toggle hotspots visibility
  void _toggleHotspots() {
    setState(() {
      _mapStateController.toggleHotspots();
    });
    
    if (_mapStateController.showHotspots) {
      // Load hotspots if needed
      _loadHotspots();
    }
  }
  
  // Toggle METAR weather display
  void _toggleMetar() {
    setState(() {
      _mapStateController.toggleMetar();
      if (_mapStateController.showMetar) {
        // Load weather data when enabled
        _loadWeatherForVisibleAirports();
      }
    });
  }


  // Handle map tap - updated to support flight planning and airspace selection
  void _onMapTapped(TapPosition tapPosition, LatLng point) async {
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
    if (_mapStateController.showAirspaces) {
      // Use spatial service to find airspaces at the tapped point
      final tappedAirspaces = await spatialAirspaceService.getAirspacesAtPoint(point);

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

  // Handle flight path segment tap for waypoint insertion
  void _onFlightPathSegmentTapped(int segmentIndex, LatLng position) {
    if (!_flightPlanService.isPlanning || !_showFlightPlanning) {
      return;
    }

    // Insert waypoint at the specified position in the flight path
    _flightPlanService.insertWaypointAt(segmentIndex, position);
    
    // Select the newly inserted waypoint
    setState(() {
      _selectedWaypointIndex = segmentIndex;
    });
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
        ? _currentPosition!.altitude * 3.28084 // Convert meters to feet
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final fontSize = isPhone ? 11.0 : 12.0;
    final titleFontSize = isPhone ? 10.0 : 11.0;

    // Show selection dialog for multiple airspaces
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isPhone ? screenWidth * 0.9 : 400,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.87),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: AppColors.warningColor.withValues(alpha: AppColors.mediumOpacity)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      topRight: Radius.circular(8.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AIRSPACES AT LOCATION',
                        style: TextStyle(
                          color: AppColors.warningColor,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.secondaryTextColor, size: 16),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                    ],
                  ),
                ),
                // Current altitude indicator
                if (currentAltitudeFt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    color: Colors.black.withValues(alpha: 0.2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flight,
                          size: 14,
                          color: AppColors.infoColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current altitude: ${currentAltitudeFt.round()} ft',
                          style: TextStyle(
                            fontSize: fontSize,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Airspaces list
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: airspaces.map<Widget>((airspace) {
                        // Check if current altitude is within this airspace
                        final isAtCurrentAltitude = currentAltitudeFt != null &&
                            airspace.isAtAltitude(currentAltitudeFt);

                        return Container(
                          decoration: isAtCurrentAltitude
                              ? BoxDecoration(
                                  color: AppColors.warningColor.withValues(alpha: AppColors.veryLowOpacity),
                                  border: Border.all(
                                    color: AppColors.warningColor,
                                    width: 2,
                                  ),
                                  borderRadius: AppTheme.defaultRadius,
                                )
                              : BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.primaryTextColor.withValues(alpha: AppColors.lowOpacity),
                                    width: 1,
                                  ),
                                  borderRadius: AppTheme.defaultRadius,
                                ),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: AppTheme.defaultRadius,
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
                                      size: isPhone ? 20 : 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            airspace.name,
                                            style: TextStyle(
                                              color: AppColors.primaryTextColor,
                                              fontSize: fontSize,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${AirspaceUtils.getAirspaceTypeName(airspace.type)} ${AirspaceUtils.getIcaoClassName(airspace.icaoClass)}',
                                            style: TextStyle(
                                              color: AppColors.secondaryTextColor,
                                              fontSize: isPhone ? 10 : 11,
                                            ),
                                          ),
                                          Text(
                                            airspace.altitudeRange,
                                            style: TextStyle(
                                              color: isAtCurrentAltitude 
                                                  ? AppColors.warningColor 
                                                  : AppColors.disabledTextColor,
                                              fontSize: isPhone ? 10 : 11,
                                              fontWeight: isAtCurrentAltitude 
                                                  ? FontWeight.bold 
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right, 
                                      color: AppColors.primaryTextColor.withValues(alpha: 0.3),
                                      size: isPhone ? 18 : 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    if (type == null) return AppColors.airspaceDefault;

    switch (type.toUpperCase()) {
      case 'CTR':
      case 'D':
      case 'DANGER':
      case 'P':
      case 'PROHIBITED':
        return AppColors.airspaceProhibited;
      case 'TMA':
      case 'R':
      case 'RESTRICTED':
        return AppColors.airspaceRestricted;
      case 'ATZ':
        return AppColors.airspaceDanger;
      case 'TSA':
        return AppColors.airspaceMoa;
      case 'TRA':
        return AppColors.airspaceTraining;
      case 'GLIDING':
        return AppColors.airspaceGliderProhibited;
      case 'TMZ':
        return AppColors.airspaceWaveWindow;
      case 'RMZ':
        return AppColors.airspaceTransponderMandatory;
      default:
        // Check ICAO class if type doesn't match
        if (icaoClass != null) {
          switch (icaoClass.toUpperCase()) {
            case 'A':
              return AppColors.airspaceClassA;
            case 'B':
              return AppColors.airspaceClassB;
            case 'C':
              return AppColors.airspaceClassC;
            case 'D':
              return AppColors.airspaceClassD;
            case 'E':
              return AppColors.airspaceClassE;
            case 'F':
              return AppColors.airspaceClassG;
            case 'G':
              return AppColors.airspaceDefault;
            default:
              return AppColors.airspaceDefault;
          }
        }
        return AppColors.airspaceDefault;
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
  void _onWaypointMoved(int index, LatLng newPosition, {bool isDragging = false}) {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan != null &&
        index >= 0 &&
        index < flightPlan.waypoints.length) {
      // Update waypoint position with drag state
      _flightPlanService.updateWaypointPosition(index, newPosition, isDragging: isDragging);
      
      // When dropping (not dragging), check if dropped on a marker
      if (!isDragging) {
        _checkAndUpdateWaypointForMarker(index, newPosition);
      }
    }
  }
  
  /// Find the closest item within search radius from a list of items with positions
  T? _findClosestItemWithinRadius<T>({
    required List<T> items,
    required LatLng dropPosition,
    required double searchRadiusMeters,
    required LatLng Function(T) getPosition,
  }) {
    T? closestItem;
    double minDistance = double.infinity;
    
    for (final item in items) {
      final distance = Distance().as(LengthUnit.Meter, dropPosition, getPosition(item));
      if (distance <= searchRadiusMeters && distance < minDistance) {
        minDistance = distance;
        closestItem = item;
      }
    }
    
    return closestItem;
  }

  /// Check if waypoint was dropped on an airport or navaid and update its name/type accordingly
  void _checkAndUpdateWaypointForMarker(int waypointIndex, LatLng dropPosition) {
    try {
      // Calculate search radius based on zoom level
      // At zoom 10: ~1000m radius, at zoom 15: ~31m radius
      final zoom = _mapController.camera.zoom;
      final zoomInt = zoom.round();
      
      // Use lookup table for common zoom levels, fallback to calculation for others
      final searchRadiusMeters = MapConstants.searchRadiusLookup[zoomInt] ?? 
          MapConstants.baseSearchRadius * math.pow(MapConstants.searchRadiusZoomFactor, zoom - MapConstants.searchRadiusZoomBase);
      
      // Get all airports in the current view
      final bounds = _mapController.camera.visibleBounds;
    final airports = _airports.where((airport) {
      final lat = airport.position.latitude;
      final lng = airport.position.longitude;
      return lat >= bounds.south && 
             lat <= bounds.north && 
             lng >= bounds.west && 
             lng <= bounds.east;
    }).toList();
    
    // Find the closest airport within search radius
    final closestAirport = _findClosestItemWithinRadius<Airport>(
      items: airports,
      dropPosition: dropPosition,
      searchRadiusMeters: searchRadiusMeters,
      getPosition: (airport) => airport.position,
    );
    
    if (closestAirport != null) {
      // Update waypoint with airport information
      _flightPlanService.updateWaypointName(waypointIndex, closestAirport.name);
      _flightPlanService.updateWaypointNotes(waypointIndex, 
        closestAirport.icaoCode?.isNotEmpty == true 
          ? closestAirport.icaoCode! 
          : (closestAirport.iataCode ?? closestAirport.icao));
      // Update waypoint type to airport
      _flightPlanService.updateWaypointType(waypointIndex, WaypointType.airport);
      return;
    }
    
    // If no airport found, check navaids
    final navaids = _navaids.where((navaid) {
      final lat = navaid.position.latitude;
      final lng = navaid.position.longitude;
      return lat >= bounds.south && 
             lat <= bounds.north && 
             lng >= bounds.west && 
             lng <= bounds.east;
    }).toList();
    
    // Find the closest navaid within search radius
    final closestNavaid = _findClosestItemWithinRadius<Navaid>(
      items: navaids,
      dropPosition: dropPosition,
      searchRadiusMeters: searchRadiusMeters,
      getPosition: (navaid) => navaid.position,
    );
    
    if (closestNavaid != null) {
      // Update waypoint with navaid information
      _flightPlanService.updateWaypointName(waypointIndex, closestNavaid.name);
      _flightPlanService.updateWaypointNotes(waypointIndex, closestNavaid.ident);
      // Update waypoint type to navaid
      _flightPlanService.updateWaypointType(waypointIndex, WaypointType.navaid);
      return;
    }
    
    // If no navaid found, check reporting points
    if (_reportingPoints.isNotEmpty) {
      // Find the closest reporting point within search radius
      final closestPoint = _findClosestItemWithinRadius<ReportingPoint>(
        items: _reportingPoints,
        dropPosition: dropPosition,
        searchRadiusMeters: searchRadiusMeters,
        getPosition: (point) => point.position,
      );
      
      if (closestPoint != null) {
        // Update waypoint with reporting point information
        _flightPlanService.updateWaypointName(waypointIndex, closestPoint.displayName);
        _flightPlanService.updateWaypointNotes(waypointIndex, closestPoint.type ?? 'Reporting Point');
        // Update waypoint type to reporting point
        _flightPlanService.updateWaypointType(waypointIndex, WaypointType.reportingPoint);
        return;
      }
    }
    
    // If no marker found at drop position, keep it as a user waypoint
    // The position has already been updated by updateWaypointPosition
    } catch (e) {
      // Handle cases where map controller is not ready
      // Position update already happened, just skip marker detection
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
    // Close the search dialog first
    Navigator.of(context).pop();
    
    // Focus map on the selected airport
    _mapController.move(
      airport.position,
      14.0, // Zoom level for airport focus
    );

    // Handle auto-centering state the same way as manual map movement
    if (_autoCenteringEnabled && _positionTrackingEnabled) {
      setState(() {
        _autoCenteringEnabled = false;
      });
      // Cancel any existing timer
      _autoCenteringTimer?.cancel();
      _countdownTimer?.cancel();
      
      // Handle differently based on tracking mode
      if (_flightService.isTracking) {
        // During flight tracking, re-enable after 3 minutes
        _startAutoCenteringCountdown();
      } else if (_positionTrackingEnabled) {
        // During position tracking (without flight tracking), re-enable after delay
        _startAutoCenteringCountdown();
      }
      // For non-tracking mode, auto-centering stays disabled until manually re-enabled
    }

    // Load airports in the new area
    _loadAirports();

    // Load navaids if they're enabled
    if (_mapStateController.showNavaids) {
      _loadNavaids();
    }

    // Load airspaces and reporting points if they're enabled
    if (_mapStateController.showAirspaces) {
      _loadAirspaces();
      _loadReportingPoints();
    }

    // Load weather data for new airports if METAR overlay is enabled
    if (_mapStateController.showMetar) {
      _loadWeatherForVisibleAirports();
    }

    // Show airport info sheet
    _onAirportSelected(airport);
  }

  // Show airport search
  void _showAirportSearch() {
    showDialog(
      context: context,
      builder: (context) => AirportSearchDialog(
        airportService: _airportService,
        onAirportSelected: _onAirportSelectedFromSearch,
      ),
    );
  }

  /// Focuses the map on a specific waypoint by index.
  /// Maintains current zoom level and disables auto-centering.
  void _focusOnWaypoint(int waypointIndex) {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan == null || 
        waypointIndex < 0 || 
        waypointIndex >= flightPlan.waypoints.length) {
      return;
    }
    
    try {

    final waypoint = flightPlan.waypoints[waypointIndex];
    _mapController.move(
      waypoint.latLng,
      _mapController.camera.zoom, // Keep current zoom level
    );

    // Disable auto-centering when focusing on waypoint
    _disableAutoCentering();
    } catch (e) {
      // Handle cases where map controller is not ready
    }
  }

  /// Disables auto-centering mode and cancels related timers.
  /// Used when user manually interacts with the map.
  void _disableAutoCentering() {
    if (_autoCenteringEnabled) {
      setState(() {
        _autoCenteringEnabled = false;
      });
      _autoCenteringTimer?.cancel();
      _countdownTimer?.cancel();
    }
  }

  /// Fits the entire flight plan in view with appropriate padding.
  /// Calculates bounds of all waypoints and adds 10% padding.
  /// Handles edge cases like single waypoint or same-location waypoints.
  void _fitFlightPlanBounds() {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan == null || flightPlan.waypoints.isEmpty) {
      return;
    }
    
    try {

    // Use built-in method for better performance
    final bounds = LatLngBounds.fromPoints(
      flightPlan.waypoints.map((w) => w.latLng).toList(),
    );
    
    // Handle edge case: all waypoints at same location
    if (bounds.north == bounds.south && bounds.east == bounds.west) {
      // Single point or all waypoints at same location
      _mapController.move(
        LatLng(bounds.north, bounds.east),
        MapConstants.singlePointZoom,
      );
      _disableAutoCentering();
      return;
    }
    
    // Calculate padding based on bounds size
    final latPadding = (bounds.north - bounds.south) * MapConstants.boundsPaddingFactor;
    final lngPadding = (bounds.east - bounds.west) * MapConstants.boundsPaddingFactor;
    
    // Create padded bounds
    final paddedBounds = LatLngBounds(
      LatLng(bounds.south - latPadding, bounds.west - lngPadding),
      LatLng(bounds.north + latPadding, bounds.east + lngPadding),
    );

    // Fit bounds with animation
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: paddedBounds,
        maxZoom: MapConstants.maxFitZoom,
        padding: EdgeInsets.all(MapConstants.fitPadding),
      ),
    );

    // Disable auto-centering when fitting flight plan
    _disableAutoCentering();
    } catch (e) {
      // Handle cases where map controller is not ready
    }
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
                    color: AppColors.warningColor,
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
                    color: AppColors.warningColor,
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
                    color: AppColors.warningColor,
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
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      airspace.remarks!,
                      style: TextStyle(color: AppColors.secondaryTextColor),
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
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.description!,
                      style: TextStyle(color: AppColors.secondaryTextColor),
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
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.remarks!,
                      style: TextStyle(color: AppColors.secondaryTextColor),
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
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.tags!.join(', '),
                      style: TextStyle(color: AppColors.secondaryTextColor),
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
  
  // Handle obstacle selection
  Future<void> _onObstacleSelected(Obstacle obstacle) async {
    if (!mounted) {
      return;
    }
    try {
      // Create a themed dialog to show obstacle information
      await ThemedDialog.show(
        context: context,
        title: obstacle.displayName,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemedInfoRow('Name', obstacle.name),
            if (obstacle.type != null)
              _buildThemedInfoRow('Type', obstacle.type!),
            if (obstacle.heightFt != null)
              _buildThemedInfoRow('Height', '${obstacle.heightFt} ft'),
            if (obstacle.elevationFt != null)
              _buildThemedInfoRow('Elevation', '${obstacle.elevationFt} ft'),
            _buildThemedInfoRow('Total Height', '${obstacle.totalHeightFt} ft MSL'),
            _buildThemedInfoRow('Lighted', obstacle.lighted ? 'Yes' : 'No'),
            if (obstacle.marking != null && obstacle.marking!.isNotEmpty)
              _buildThemedInfoRow('Marking', obstacle.marking!),
            if (obstacle.country != null)
              _buildThemedInfoRow('Country', obstacle.country!),
            const SizedBox(height: 8),
            Text(
              'Position: ${obstacle.latitude.toStringAsFixed(5)}, ${obstacle.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error showing obstacle details'),
          ),
        );
      }
    }
  }
  
  // Handle hotspot selection
  Future<void> _onHotspotSelected(Hotspot hotspot) async {
    if (!mounted) {
      return;
    }
    try {
      // Create a themed dialog to show hotspot information
      await ThemedDialog.show(
        context: context,
        title: hotspot.displayName,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemedInfoRow('Name', hotspot.name),
            if (hotspot.type != null)
              _buildThemedInfoRow('Type', hotspot.type!),
            if (hotspot.elevationFt != null)
              _buildThemedInfoRow('Elevation', hotspot.elevationString),
            if (hotspot.reliability != null)
              _buildThemedInfoRow('Reliability', hotspot.reliabilityString),
            if (hotspot.occurrence != null && hotspot.occurrence!.isNotEmpty)
              _buildThemedInfoRow('Occurrence', hotspot.occurrence!),
            if (hotspot.conditions != null && hotspot.conditions!.isNotEmpty)
              _buildThemedInfoRow('Conditions', hotspot.conditions!),
            if (hotspot.description != null && hotspot.description!.isNotEmpty)
              _buildThemedInfoRow('Description', hotspot.description!),
            if (hotspot.country != null)
              _buildThemedInfoRow('Country', hotspot.country!),
            const SizedBox(height: 8),
            Text(
              'Position: ${hotspot.latitude.toStringAsFixed(5)}, ${hotspot.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error showing hotspot details'),
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
              color: AppColors.primaryAccent,
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: AppColors.secondaryTextColor)),
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
      
      // Initialize runway service
      await _runwayService.initialize();

      // Initialize offline map service only on supported platforms
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        try {
          _offlineMapService = OfflineMapService();
          await _offlineMapService!.initialize();
          
          // Initialize tile download service for flight plans
          _offlineDataController = OfflineDataStateController();
          _tileDownloadService = FlightPlanTileDownloadService(
            offlineMapService: _offlineMapService!,
            offlineDataController: _offlineDataController!,
          );
          
          // Connect tile download service to flight plan service
          _flightPlanService.setTileDownloadService(_tileDownloadService!);
          if (mounted) {
            _flightPlanService.setContext(context);
          }
          
          // Validate flight plan tiles on startup
          _validateFlightPlanTiles();
        } catch (e) {
          // Handle initialization errors gracefully
          _logger.w('Offline maps not available: ${e.toString().split('(')[0]}');
          // Continue without offline maps - they're optional
        }
      }

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

    await MapProfiler.profileMapOperation('loadWeatherForVisibleAirports', () async {
    try {
      // Get the current map bounds
      final bounds = _mapController.camera.visibleBounds;
      
      // Get only the airports that are actually visible on the map (same filtering as markers)
      final visibleAirports = _airports.where((airport) {
        // Small airports are always shown (filtered by zoom level automatically)
        // Filter closed airports (use correct lowercase "closed" check)
        if (airport.type.toLowerCase() == 'closed') {
          return false;
        }

        // First check if airport is within visible bounds
        if (!bounds.contains(airport.position)) {
          return false;
        }
        
        // Filter heliports and balloonports based on toggle
        if ((airport.type == 'heliport' || airport.type == 'balloonport') && !_mapStateController.showHeliports) {
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
    });
  }

  
  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }
  
  Widget _buildContent(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
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
              initialZoom: MapConstants.initialZoom,
              minZoom: MapConstants.minZoom,
              maxZoom: MapConstants.maxZoom,
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
                  if (_autoCenteringEnabled) {
                    setState(() {
                      _autoCenteringEnabled = false;
                    });

                    // Cancel any existing timer
                    _autoCenteringTimer?.cancel();
                    _countdownTimer?.cancel();

                    // Handle differently based on tracking mode
                    if (_flightService.isTracking) {
                      // During flight tracking, re-enable after 3 minutes
                      _startAutoCenteringCountdown();
                    } else if (_positionTrackingEnabled) {
                      // During position tracking, re-enable after delay
                      _startAutoCenteringCountdown();
                    }
                  }

                  // Use frame-aware scheduler for staggered loading
                  final scheduler = FrameAwareScheduler();
                  
                  // Load airports first (highest priority)
                  scheduler.scheduleOperation(
                    id: 'load_airports',
                    operation: _loadAirports,
                    debounce: const Duration(milliseconds: 300),
                    highPriority: true,
                  );
                  
                  // Load navaids with delay
                  if (_mapStateController.showNavaids) {
                    scheduler.scheduleOperation(
                      id: 'load_navaids',
                      operation: _loadNavaids,
                      debounce: const Duration(milliseconds: 600),
                    );
                  }
                  
                  // Reporting points with more delay
                  if (_mapStateController.showAirspaces) {
                    scheduler.scheduleOperation(
                      id: 'load_reporting_points',
                      operation: _loadReportingPoints,
                      debounce: const Duration(milliseconds: 800),
                    );
                  }
                  
                  // Obstacles with delay
                  if (_mapStateController.showObstacles) {
                    scheduler.scheduleOperation(
                      id: 'load_obstacles',
                      operation: _loadObstacles,
                      debounce: const Duration(milliseconds: 900),
                    );
                  }
                  
                  // Hotspots with delay  
                  if (_mapStateController.showHotspots) {
                    scheduler.scheduleOperation(
                      id: 'load_hotspots',
                      operation: _loadHotspots,
                      debounce: const Duration(milliseconds: 950),
                    );
                  }
                  
                  // Weather data with even more delay
                  if (_mapStateController.showMetar) {
                    scheduler.scheduleOperation(
                      id: 'load_weather',
                      operation: _loadWeatherForVisibleAirports,
                      debounce: const Duration(milliseconds: 1000),
                    );
                  }
                  
                  // NOTAMs with lowest priority
                  scheduler.scheduleOperation(
                    id: 'prefetch_notams',
                    operation: _schedulePrefetchVisibleAirportNotams,
                    debounce: const Duration(milliseconds: 1500),
                  );
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
              // Airspaces overlay (optimized with debouncing)
              if (_mapStateController.showAirspaces)
                OptimizedSpatialAirspacesOverlay(
                  spatialService: spatialAirspaceService,
                  showAirspacesLayer: _mapStateController.showAirspaces,
                  onAirspaceTap: _onAirspaceSelected,
                  currentAltitude: _currentPosition?.altitude ?? 0,
                ),
              // Reporting points overlay (optimized)
              if (_mapStateController.showAirspaces && _reportingPoints.isNotEmpty)
                OptimizedReportingPointsLayer(
                  reportingPoints: _reportingPoints,
                  onReportingPointTap: _onReportingPointSelected,
                ),
              // Obstacles overlay (optimized)
              if (_mapStateController.showObstacles && _obstacles.isNotEmpty)
                OptimizedObstaclesLayer(
                  obstacles: _obstacles,
                  onObstacleTap: _onObstacleSelected,
                ),
              // Hotspots overlay (optimized)  
              if (_mapStateController.showHotspots && _hotspots.isNotEmpty)
                OptimizedHotspotsLayer(
                  hotspots: _hotspots,
                  onHotspotTap: _onHotspotSelected,
                ),
              // Airport markers with tap handling (optimized)
              Consumer<SettingsService>(
                builder: (context, settings, child) {
                  return OptimizedAirportMarkersLayer(
                    airports: _airports.where((airport) {
                      // Filter heliports and balloonports based on toggle
                      if ((airport.type == 'heliport' || airport.type == 'balloonport') && !_mapStateController.showHeliports) {
                        return false;
                      }
                      // Small airports are always shown (filtered by zoom level automatically)
                      // Show medium and large airports always, and show small airports/heliports based on toggles
                      return true;
                    }).toList(),
                    airportRunways: _airportRunways,
                    onAirportTap: _onAirportSelected,
                    showHeliports: _mapStateController.showHeliports,
                    distanceUnit: settings.distanceUnit,
                  );
                },
              ),
              // Navaid markers (optimized)
              if (_mapStateController.showNavaids && _navaids.isNotEmpty)
                OptimizedNavaidMarkersLayer(
                  navaids: _navaids,
                  onNavaidTap: _onNavaidSelected,
                ),
              // METAR overlay
              if (_mapStateController.showMetar)
                MetarOverlay(
                  airports: _airports,
                  showMetarLayer: _mapStateController.showMetar,
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
                        polylines: FlightPlanOverlay.buildClickableFlightPath(
                          flightPlan,
                          _onFlightPathSegmentTapped,
                          flightPlanService.isPlanning,
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
                      // Flight path segment click markers (for waypoint insertion)
                      MarkerLayer(
                        markers: FlightPlanOverlay.buildSegmentClickMarkers(
                          flightPlan,
                          _onFlightPathSegmentTapped,
                          flightPlanService.isPlanning,
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
                      color: AppColors.errorColor,
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
                    final markerRotation = shouldRotateMarker ? (_currentPosition?.heading ?? 0) * math.pi / 180 : 0.0;
                    
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
                      borderRadius: AppTheme.largeRadius,
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
                    borderRadius: AppTheme.largeRadius,
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
                        width: 50, // Fixed width instead of double.infinity
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: AppTheme.smallRadius,
                            ),
                          ),
                        ),
                      ),
                      _buildLayerToggle(
                        icon: FontAwesomeIcons.helicopter,
                        tooltip: 'Toggle Heliports',
                        isActive: _mapStateController.showHeliports,
                        onPressed: _toggleHeliports,
                      ),
                      _buildLayerToggle(
                        icon: _mapStateController.showMetar
                            ? Icons.cloud
                            : Icons.cloud_outlined,
                        tooltip: 'Toggle METAR',
                        isActive: _mapStateController.showMetar,
                        onPressed: _toggleMetar,
                      ),
                      _buildLayerToggle(
                        icon: _mapStateController.showAirspaces
                            ? Icons.layers
                            : Icons.layers_outlined,
                        tooltip: 'Toggle Airspaces',
                        isActive: _mapStateController.showAirspaces,
                        onPressed: _toggleAirspaces,
                      ),
                      _buildLayerToggle(
                        icon: Icons.warning_amber_rounded,
                        tooltip: 'Toggle Obstacles',
                        isActive: _mapStateController.showObstacles,
                        onPressed: _toggleObstacles,
                      ),
                      _buildLayerToggle(
                        icon: Icons.location_on,
                        tooltip: 'Toggle Hotspots',
                        isActive: _mapStateController.showHotspots,
                        onPressed: _toggleHotspots,
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
                            // Always show flight plan on map when it exists
                            if (_flightPlanService.currentFlightPlan != null) {
                              _flightPlanService.setFlightPlanVisibility(true);
                            }
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
          if (_mapStateController.showStats)
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
                  borderRadius: AppTheme.largeRadius,
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
                    color: AppColors.dialogBackgroundColor, // Dark background
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.defaultRadius,
                      side: BorderSide(color: AppColors.sectionBorderColor),
                    ),
                    onSelected: (value) {
                      if (value == 'flight_log') {
                        _pauseAllTimers();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FlightLogScreen(),
                          ),
                        ).then((_) => _resumeAllTimers());
                      } else if (value == 'logbook') {
                        _pauseAllTimers();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LogBookScreen(),
                          ),
                        ).then((_) => _resumeAllTimers());
                      } else if (value == 'flight_plans') {
                        _pauseAllTimers();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FlightPlansScreen(),
                          ),
                        ).then((_) => _resumeAllTimers());
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
                          // Always show flight plan on map when it exists
                          if (_flightPlanService.currentFlightPlan != null) {
                            _flightPlanService.setFlightPlanVisibility(true);
                          }
                        });
                        // Note: Planning mode is NOT automatically enabled when showing the panel
                        // Users must explicitly enable it from within the panel
                        // debugPrint('Flight planning panel toggled: $_showFlightPlanning');
                      } else if (value == 'checklists') {
                        _pauseAllTimers();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ChecklistSettingsScreen(),
                          ),
                        ).then((_) => _resumeAllTimers());
                      } else if (value == 'airplane_settings') {
                        _pauseAllTimers();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AircraftSettingsScreen(),
                          ),
                        ).then((_) => _resumeAllTimers());
                      } else if (value == 'calculators') {
                        _pauseAllTimers();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CalculatorsScreen(),
                          ),
                        ).then((_) => _resumeAllTimers());
                      } else if (value == 'settings') {
                        _pauseAllTimers();
                        SettingsDialog.show(
                          context,
                          currentMapBounds: _mapController.camera.visibleBounds,
                        ).then((_) => _resumeAllTimers());
                      } else if (value == 'website') {
                        launchUrl(Uri.parse('https://www.captainvfr.com'));
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        value: 'flight_plans',
                        child: Row(
                          children: [
                            Icon(Icons.flight_takeoff, size: 20, color: AppColors.primaryTextColor),
                            SizedBox(width: 8),
                            Text('Flight Plans', style: TextStyle(color: AppColors.primaryTextColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'flight_log',
                        child: Row(
                          children: [
                            Icon(Icons.flight, size: 20, color: AppColors.primaryTextColor),
                            SizedBox(width: 8),
                            Text('Flight Log', style: TextStyle(color: AppColors.primaryTextColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logbook',
                        child: Row(
                          children: [
                            Icon(Icons.menu_book, size: 20, color: AppColors.primaryTextColor),
                            SizedBox(width: 8),
                            Text('LogBook', style: TextStyle(color: AppColors.primaryTextColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'checklists',
                        child: Row(
                          children: [
                            Icon(Icons.list, size: 20, color: AppColors.primaryTextColor),
                            SizedBox(width: 8),
                            Text('Checklists', style: TextStyle(color: AppColors.primaryTextColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'airplane_settings',
                        child: Row(
                          children: [
                            Icon(Icons.flight, size: 20, color: AppColors.primaryTextColor),
                            SizedBox(width: 8),
                            Text('Aircrafts', style: TextStyle(color: AppColors.primaryTextColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'calculators',
                        child: Row(
                          children: [
                            Icon(Icons.calculate, size: 20, color: AppColors.primaryTextColor),
                            SizedBox(width: 8),
                            Text('Calculators', style: TextStyle(color: AppColors.primaryTextColor)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings, size: 20, color: AppColors.primaryTextColor),
                            SizedBox(width: 8),
                            Text('Settings', style: TextStyle(color: AppColors.primaryTextColor)),
                          ],
                        ),
                      ),
                      PopupMenuDivider(height: 1),
                      PopupMenuItem(
                        value: 'website',
                        child: Row(
                          children: [
                            Icon(Icons.language, size: 20, color: AppColors.primaryTextColor),
                            SizedBox(width: 8),
                            Text('Visit www.captainvfr.com', style: TextStyle(color: AppColors.primaryTextColor)),
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
                  _buildPositionTrackingButton(),
                  IconButton(
                    icon: Icon(
                      _mapStateController.showStats ? Icons.dashboard : Icons.dashboard_outlined,
                      color: _mapStateController.showStats ? Colors.blue : Colors.black,
                    ),
                    onPressed: _toggleStats,
                    tooltip: 'Toggle flight dashboard',
                  ),
                ],
              ),
            ),
            ),
          ),
          // Location loading indicator is now handled by the notification system


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
              // Adjust flight planning panel position for screen size changes (orientation)
              final screenSize = MediaQuery.of(context).size;
              _adjustFlightPlanningPanelPosition(screenSize);
              
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
                              onWaypointFocus: _focusOnWaypoint,
                              onClose: () {
                                setState(() {
                                  _showFlightPlanning = false;
                                });
                                // Stop planning mode - check if we need to toggle
                                if (_flightPlanService.isPlanning) {
                                  _flightPlanService.togglePlanningMode();
                                }
                                // Keep flight plan visible on map even when panel is closed
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
                            // Use actual panel heights that match FlightPlanningPanel constraints
                            final panelHeight = _flightPlanningExpanded
                                ? 400  // Reduced from 600 - more realistic for most cases
                                : 60;  // Match the actual collapsed height from FlightPlanningPanel

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
                            onWaypointFocus: _focusOnWaypoint,
                            onExpandedChanged: (expanded) {
                              setState(() {
                                _flightPlanningExpanded = expanded;
                              });
                              // Save the state to SharedPreferences
                              _saveFlightPlanningPanelState(expanded);
                            },
                            onClose: () {
                              setState(() {
                                _showFlightPlanning = false;
                              });
                              // Stop planning mode - check if we need to toggle
                              if (_flightPlanService.isPlanning) {
                                _flightPlanService.togglePlanningMode();
                              }
                              // Keep flight plan visible on map even when panel is closed
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
                      isEditMode: flightPlanService.isPlanning,
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

          // Location loading notification
          if (_locationNotificationShown)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SensorNotification(
                    sensorName: 'Getting location...',
                    message: 'Acquiring GPS position',
                    icon: Icons.location_searching,
                    backgroundColor: const Color(0xFFE3F2FD), // Light blue
                    iconColor: const Color(0xFF1976D2), // Blue
                    autoDismissAfter: const Duration(seconds: 3),
                    onDismiss: _dismissLocationNotification,
                  ),
                ),
              ),
            ),
          // Loading progress bar at the bottom center
          const Positioned(
            bottom: 60, // Above map controls
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: false, // Allow interaction with the close button
              child: LoadingProgressBar(),
            ),
          ),
          
          // Performance overlay when development mode is enabled
          Consumer<SettingsService>(
            builder: (context, settings, child) {
              if (settings.developmentMode) {
                return const PerformanceOverlayWidget(
                  showFPS: true,
                  showOperations: true,
                  alignRight: true,
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Zoom control buttons in bottom left corner
          Positioned(
            bottom: 16,
            left: 16,
            child: MapZoomControls(
              mapController: _mapController,
              minZoom: MapConstants.minZoom,
              maxZoom: MapConstants.maxZoom,
              onZoomChanged: _onZoomButtonPressed,
            ),
          ),
          
          // OpenStreetMap attribution in bottom right corner - always on top
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: AppTheme.smallRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () async {
                  const url = 'https://openstreetmap.org/copyright';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url));
                  }
                },
                child: Text(
                  'Map data © OpenStreetMap',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color.fromRGBO(0, 0, 0, 0.87),
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
            ],
          );
        },
      ),
    ); // Closing Scaffold
  }

  
  // Show dialog to open app settings

  Widget _buildPositionTrackingButton() {
    return PositionTrackingButton(
      positionTrackingEnabled: _positionTrackingEnabled,
      autoCenteringEnabled: _autoCenteringEnabled,
      autoCenteringCountdown: _autoCenteringCountdown,
      onToggle: _togglePositionTracking,
    );
  }

  Widget _buildLayerToggle({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return LayerToggleButton(
      icon: icon,
      tooltip: tooltip,
      isActive: isActive,
      onPressed: onPressed,
    );
  }


  Color _getSegmentColor(String segmentType) {
    return SegmentUtils.getSegmentColor(segmentType);
  }

  IconData _getSegmentIcon(String segmentType) {
    return SegmentUtils.getSegmentIcon(segmentType);
  }
}
