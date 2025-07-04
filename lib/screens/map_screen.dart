import 'dart:async';
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
import '../models/airport.dart';
import '../models/navaid.dart';
import '../models/flight_segment.dart';
import '../services/airport_service.dart';
import '../services/navaid_service.dart';
import '../services/flight_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/offline_map_service.dart';
import '../services/offline_tile_provider.dart';
import '../services/flight_plan_service.dart';
import '../widgets/airport_marker.dart';
import '../widgets/navaid_marker.dart';
import '../widgets/airport_info_sheet.dart';
import '../widgets/flight_dashboard.dart';
import '../widgets/airport_search_delegate.dart';
import '../widgets/metar_overlay.dart';
import '../widgets/flight_plan_overlay.dart';
import '../widgets/compact_flight_plan_widget.dart';
import '../widgets/license_warning_widget.dart';
import '../widgets/floating_waypoint_panel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  // Services
  late final FlightService _flightService;
  late final AirportService _airportService;
  late final NavaidService _navaidService;
  late final LocationService _locationService;
  late final WeatherService _weatherService;
  OfflineMapService? _offlineMapService; // Make nullable to prevent LateInitializationError
  late final FlightPlanService _flightPlanService;
  late final MapController _mapController;
  
  // State variables
  bool _isLoading = true;
  bool _showStats = false;
  bool _showNavaids = true; // Toggle for navaid display
  bool _showMetar = false; // Toggle for METAR overlay
  bool _showHeliports = false; // Toggle for heliport display (default hidden)
  bool _showSmallAirports = true; // Toggle for small airport display (default visible)
  bool _servicesInitialized = false;
  bool _isInitializing = false; // Guard against concurrent initialization
  bool _showFlightPlanning = false; // Toggle for integrated flight planning
  String _errorMessage = '';
  Timer? _debounceTimer;
  
  // Flight data panel position state
  Offset _flightDataPanelPosition = const Offset(16, 220); // Default to bottom with positive margin

  // Waypoint selection state
  int? _selectedWaypointIndex;

  // Location and map state
  Position? _currentPosition;
  List<LatLng> _flightPathPoints = [];
  List<FlightSegment> _flightSegments = [];
  List<Airport> _airports = [];
  List<Navaid> _navaids = [];

  // UI state
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Map settings
  static const double _initialZoom = 12.0;
  static const double _maxZoom = 18.0;
  static const double _minZoom = 3.0;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize map controller
    _mapController = MapController();
    
    // Initial setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize services from Provider to ensure they're properly initialized
    if (!_servicesInitialized) {
      _flightService = Provider.of<FlightService>(context, listen: false);
      _locationService = Provider.of<LocationService>(context, listen: false);
      _airportService = Provider.of<AirportService>(context, listen: false);
      _navaidService = Provider.of<NavaidService>(context, listen: false);
      _weatherService = Provider.of<WeatherService>(context, listen: false);
      _flightPlanService = Provider.of<FlightPlanService>(context, listen: false);

      // Initialize services with caching
      _initializeServices();

      // Listen to flight service updates
      _setupFlightServiceListener();
    }
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
        // Convert flight points to LatLng for map visualization
        _flightPathPoints = _flightService.flightPath
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        // Update flight segments for visualization
        _flightSegments = _flightService.flightSegments;
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
    }
  }
  
  @override
  void dispose() {
    _flightService.removeListener(_onFlightPathUpdated);
    _flightPlanService.removeListener(_onFlightPlanUpdated);
    _debounceTimer?.cancel();
    _mapController.dispose();
    _flightService.dispose();
    super.dispose();
  }
  
  // Initialize location services and get current position
  Future<void> _initLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _errorMessage = '';
          _isLoading = false; // Set loading to false when location is loaded
        });

        // Wait for the next frame to ensure FlutterMap is rendered before using MapController
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _mapController.move(
                LatLng(position.latitude, position.longitude),
                _initialZoom,
              );
            } catch (e) {
              debugPrint('Error moving map: $e');
              // Fallback: try again after a short delay
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  try {
                    _mapController.move(
                      LatLng(position.latitude, position.longitude),
                      _initialZoom,
                    );
                  } catch (e) {
                    debugPrint('Error moving map (retry): $e');
                  }
                }
              });
            }
          }
        });

        await _loadAirports();

        // Load navaids if they should be shown
        if (_showNavaids) {
          await _loadNavaids();
        }
      }
    } catch (e) {
      debugPrint('Error initializing location: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to get location: ${e.toString()}';
          _isLoading = false; // Also set loading to false on error
        });

        // Only show SnackBar if we have a valid Scaffold context
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error getting location: ${e.toString()}')),
              );
            } catch (scaffoldError) {
              debugPrint('Could not show SnackBar: $scaffoldError');
            }
          }
        });
      }
    }
  }
  
  // Load airports in the current map view with debouncing
  Future<void> _loadAirports() async {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();
    
    // Set a new debounce timer (300ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      
      try {
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
        debugPrint('Error loading airports: $e');
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

      debugPrint('🌤️ Refreshing weather for ${icaoCodes.length} visible airports');

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

      debugPrint('✅ Weather refresh completed for visible airports');
    } catch (e) {
      debugPrint('❌ Error refreshing weather for visible airports: $e');
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
        return airport.icao.length == 4 && RegExp(r'^[A-Z]{4}$').hasMatch(airport.icao);
    }
  }

  // Calculate radius in kilometers based on zoom level
  double _calculateRadiusForZoom(double zoom) {
    // These values can be adjusted based on testing
    if (zoom > 14) return 20.0;  // Very close zoom
    if (zoom > 12) return 50.0;  // Close zoom
    if (zoom > 9) return 100.0;  // Medium zoom
    return 200.0;                // Far zoom
  }
  
  // Load additional nearby airports that might be just outside the current view
  Future<void> _loadNearbyAirports(LatLng center, double radiusKm) async {
    try {
      final nearbyAirports = _airportService.findAirportsNearby(center, radiusKm: radiusKm);
      
      // Filter out airports we already have
      final newAirports = nearbyAirports.where((a) => 
        !_airports.any((existing) => existing.icao == a.icao)
      ).toList();
      
      if (newAirports.isNotEmpty && mounted) {
        setState(() {
          _airports = [..._airports, ...newAirports];
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby airports: $e');
    }
  }
  
  // Load navaids in the current map view
  Future<void> _loadNavaids() async {
    if (!_showNavaids) {
      debugPrint('🧭 _loadNavaids: _showNavaids is false, returning early');
      return;
    }

    debugPrint('🧭 _loadNavaids: Starting to load navaids...');

    try {
      // Ensure navaids are fetched
      debugPrint('🧭 _loadNavaids: Calling fetchNavaids...');
      await _navaidService.fetchNavaids();

      final totalNavaids = _navaidService.navaids.length;
      debugPrint('🧭 _loadNavaids: Total navaids available: $totalNavaids');

      if (totalNavaids == 0) {
        debugPrint('❌ _loadNavaids: No navaids available in service');
        return;
      }

      final bounds = _mapController.camera.visibleBounds;
      debugPrint('🧭 _loadNavaids: Map bounds - SW: ${bounds.southWest}, NE: ${bounds.northEast}');

      final navaids = _navaidService.getNavaidsInBounds(
        bounds.southWest,
        bounds.northEast,
      );

      debugPrint('🧭 _loadNavaids: Found ${navaids.length} navaids in current bounds');

      if (mounted) {
        setState(() {
          _navaids = navaids;
        });
        debugPrint('✅ _loadNavaids: Updated state with ${navaids.length} navaids');
      }
    } catch (e) {
      debugPrint('❌ Error loading navaids: $e');
    }
  }

  // Center map on current location
  Future<void> _centerOnLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
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
  

  // Toggle flight dashboard visibility
  void _toggleStats() {
    setState(() {
      _showStats = !_showStats;
    });
  }
  
  // Toggle navaid visibility
  void _toggleNavaids() {
    debugPrint('🔴 _toggleNavaids: Button pressed! Starting toggle...');
    debugPrint('🧭 _toggleNavaids: Current state: $_showNavaids');
    setState(() {
      _showNavaids = !_showNavaids;
    });
    debugPrint('🧭 _toggleNavaids: New state: $_showNavaids');

    // Load navaids immediately when toggled on
    if (_showNavaids) {
      debugPrint('🧭 _toggleNavaids: Calling _loadNavaids()...');
      _loadNavaids();
    } else {
      debugPrint('🧭 _toggleNavaids: Clearing navaids list');
      setState(() {
        _navaids = [];
      });
    }
    debugPrint('🔴 _toggleNavaids: Toggle completed!');
  }

  // Toggle METAR overlay visibility
  void _toggleMetar() {
    setState(() {
      _showMetar = !_showMetar;
    });

    // When METAR overlay is turned on, refresh weather for currently visible airports
    if (_showMetar && _airports.isNotEmpty) {
      _refreshWeatherForVisibleAirports(_airports);
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

  // Handle map tap - updated to support flight planning
  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    debugPrint('Map tapped at: ${point.latitude}, ${point.longitude}');

    // If in flight planning mode, add waypoint
    if (_flightPlanService.isPlanning) {
      _flightPlanService.addWaypoint(point);
      debugPrint('Added waypoint at: ${point.latitude}, ${point.longitude}');
      return;
    }

    // Otherwise, close any open dialogs or menus
    if (mounted) {
      debugPrint('Popping all routes until first');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      debugPrint('Context not mounted, cannot pop routes');
    }
  }

  // Handle waypoint tap for selection
  void _onWaypointTapped(int index) {
    debugPrint('Waypoint $index tapped');

    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan != null && index >= 0 && index < flightPlan.waypoints.length) {
      setState(() {
        _selectedWaypointIndex = _selectedWaypointIndex == index ? null : index;
      });
    }
  }

  // Handle waypoint move via drag and drop
  void _onWaypointMoved(int index, LatLng newPosition) {
    debugPrint('Waypoint $index moved to ${newPosition.latitude}, ${newPosition.longitude}');
    
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan != null && index >= 0 && index < flightPlan.waypoints.length) {
      // Update waypoint position
      _flightPlanService.updateWaypointPosition(index, newPosition);
    }
  }

  // Handle airport selection
  Future<void> _onAirportSelected(Airport airport) async {
    debugPrint('_onAirportSelected called for ${airport.icao} - ${airport.name}');

    // If in flight planning mode, add airport as waypoint instead of showing details
    if (_flightPlanService.isPlanning) {
      debugPrint('Flight planning mode active - adding airport as waypoint');
      _flightPlanService.addAirportWaypoint(airport);
      debugPrint('Added airport waypoint: ${airport.icao} - ${airport.name}');
      return;
    }

    if (!mounted) {
      debugPrint('Context not mounted, returning early');
      return;
    }
    
    try {
      debugPrint('Showing bottom sheet for ${airport.icao}');
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => AirportInfoSheet(
          airport: airport,
          weatherService: _weatherService,
          onClose: () {
            debugPrint('Closing bottom sheet for ${airport.icao}');
            Navigator.of(context).pop();
          },
        ),
      );
      debugPrint('Bottom sheet closed for ${airport.icao}');
    } catch (e, stackTrace) {
      debugPrint('Error showing bottom sheet for ${airport.icao}: $e');
      debugPrint('Stack trace: $stackTrace');
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
    debugPrint('_onNavaidSelected called for ${navaid.ident} - ${navaid.name}');

    // If in flight planning mode, add navaid as waypoint instead of showing details
    if (_flightPlanService.isPlanning) {
      debugPrint('Flight planning mode active - adding navaid as waypoint');
      _flightPlanService.addNavaidWaypoint(navaid);
      debugPrint('Added navaid waypoint: ${navaid.ident} - ${navaid.name}');
      return;
    }

    if (!mounted) {
      debugPrint('Context not mounted, returning early');
      return;
    }

    try {
      debugPrint('Showing bottom sheet for ${navaid.ident}');
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => NavaidInfoSheet(
          navaid: navaid,
          onClose: () {
            debugPrint('Closing bottom sheet for ${navaid.ident}');
            Navigator.of(context).pop();
          },
        ),
      );
      debugPrint('Bottom sheet closed for ${navaid.ident}');
    } catch (e, stackTrace) {
      debugPrint('Error showing bottom sheet for ${navaid.ident}: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error showing navaid details')),
        );
      }
    }
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

      debugPrint('✅ Services initialized with cached data');
    } catch (e) {
      debugPrint('⚠️ Error initializing services: $e');
      // Don't set _servicesInitialized = true if initialization failed
    } finally {
      _isInitializing = false; // Reset the guard flag
    }
  }


  // Load weather data for airports currently visible on the map
  Future<void> _loadWeatherForVisibleAirports() async {
    if (_airports.isEmpty) return;

    try {
      // Get only the airports that are actually visible on the map (same filtering as markers)
      final visibleAirports = _airports.where((airport) {
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
      final visibleAirportIcaos = visibleAirports.map((airport) => airport.icao).toList();

      debugPrint('🌤️ Loading weather for ${visibleAirportIcaos.length}/${_airports.length} visible airports...');

      // Fetch weather data for visible airports
      await _weatherService.initialize();
      final metarData = await _weatherService.getMetarsForAirports(visibleAirportIcaos);

      // Update only the visible airports with weather data
      bool hasUpdates = false;
      for (final airport in visibleAirports) {
        final metar = metarData[airport.icao];
        if (metar != null && airport.rawMetar != metar) {
          airport.updateWeather(metar);
          hasUpdates = true;
        }
      }

      // Trigger UI update if we got new weather data
      if (hasUpdates && mounted) {
        setState(() {
          // Force rebuild to show updated weather data
        });
        debugPrint('✅ Updated weather data for ${metarData.length} visible airports');
      }
    } catch (e) {
      debugPrint('❌ Error loading weather for visible airports: $e');
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
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(0, 0), // Default center
              initialZoom: _initialZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPosition, point) => _onMapTapped(tapPosition, point),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _loadAirports();
                  // Also load navaids if they're enabled
                  if (_showNavaids) {
                    _loadNavaids();
                  }
                  // Load weather data for new airports if METAR overlay is enabled
                  if (_showMetar) {
                    _loadWeatherForVisibleAirports();
                  }
                }
              },
            ),
            children: [
              // Tile layer with offline support
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.captainvfr',
                tileProvider: _servicesInitialized
                    ? OfflineTileProvider(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        offlineMapService: _offlineMapService!,
                        userAgentPackageName: 'com.example.captainvfr',
                      )
                    : null,
              ),
              // Flight path layer
              if (_flightPathPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _flightPathPoints,
                      color: Colors.blue.withValues(alpha: 0.7),
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              // Flight segment markers
              if (_flightSegments.isNotEmpty)
                MarkerLayer(
                  markers: _flightSegments.map((segment) => [
                    // Start marker
                    Marker(
                      point: segment.startLatLng,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getSegmentColor(segment.type),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
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
                          color: _getSegmentColor(segment.type).withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.flag,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ]).expand((markers) => markers).toList(),
                ),
              // Airport markers with tap handling
              AirportMarkersLayer(
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
              // Navaid markers
              if (_showNavaids && _navaids.isNotEmpty)
                NavaidMarkersLayer(
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
                  if (flightPlan == null || flightPlan.waypoints.isEmpty || !flightPlanService.isFlightPlanVisible) {
                    return const SizedBox.shrink();
                  }

                  return Stack(
                    children: [
                      // Flight plan route lines
                      PolylineLayer(
                        polylines: FlightPlanOverlay.buildFlightPath(flightPlan),
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
                        ),
                      ),
                      // Waypoint name labels
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
                            markers: FlightPlanOverlay.buildSegmentLabels(flightPlan, context),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              // Current position marker
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Vertical layer controls on the right side - centered vertically
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4, // Center vertically (40% from top)
            right: 16,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLayerToggle(
                    icon: _showNavaids ? Icons.explore : Icons.explore_outlined,
                    tooltip: 'Toggle Navaids',
                    isActive: _showNavaids,
                    onPressed: () {
                      debugPrint('🔴 NAVAID BUTTON PRESSED DIRECTLY!');
                      _toggleNavaids();
                    },
                  ),
                  _buildLayerToggle(
                    icon: _showMetar ? Icons.cloud : Icons.cloud_outlined,
                    tooltip: 'Toggle METAR Overlay',
                    isActive: _showMetar,
                    onPressed: _toggleMetar,
                  ),
                  _buildLayerToggle(
                    icon: _showHeliports ? Icons.adjust : Icons.radio_button_unchecked,
                    tooltip: 'Toggle Heliports',
                    isActive: _showHeliports,
                    onPressed: _toggleHeliports,
                  ),
                  _buildLayerToggle(
                    icon: _showSmallAirports ? Icons.airplanemode_active : Icons.airplanemode_inactive,
                    tooltip: 'Toggle Small Airports',
                    isActive: _showSmallAirports,
                    onPressed: _toggleSmallAirports,
                  ),
                ],
              ),
            ),
          ),

          // Flight dashboard overlay - show when toggle is active
          if (_showStats)
            Positioned(
              left: _flightDataPanelPosition.dx,
              bottom: _flightDataPanelPosition.dy, // Use positive value for bottom positioning
              child: Draggable<String>(
                data: 'flight_panel',
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 32,
                    child: const FlightDashboard(),
                  ),
                ),
                childWhenDragging: Container(), // Empty container when dragging
                onDragEnd: (details) {
                  setState(() {
                    // Calculate new position based on drag end position
                    final screenSize = MediaQuery.of(context).size;
                    double newX = details.offset.dx;
                    double newY = details.offset.dy;

                    // Convert screen coordinates to bottom-relative positioning
                    double bottomDistance = screenSize.height - newY - 200; // 200 is panel height

                    // Constrain to screen bounds with margins
                    newX = newX.clamp(16.0, screenSize.width - (screenSize.width - 32)); // Keep within screen width
                    bottomDistance = bottomDistance.clamp(16.0, screenSize.height - 250); // Keep within screen height

                    _flightDataPanelPosition = Offset(newX, bottomDistance);
                  });
                },
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 32,
                  child: Stack(
                    children: [
                      const FlightDashboard(),
                      // Drag handle at the top of the panel
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.drag_handle,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Flight dashboard overlay
          if (_flightService.isTracking)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _flightService.isTracking ? 200 : 0,
                child: const FlightDashboard(),
              ),
            ),
          // App bar - simplified without leading or actions
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false, // Remove default leading button
            ),
          ),

          // Navigation and action controls positioned on the left side
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16, // Align with standard padding
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
                        });

                        // Toggle flight planning mode in the service
                        if (_showFlightPlanning) {
                          // Start planning mode - check if we need to toggle
                          if (!_flightPlanService.isPlanning) {
                            _flightPlanService.togglePlanningMode();
                          }
                          debugPrint('Started flight planning mode');
                        } else {
                          // Stop planning mode - check if we need to toggle
                          if (_flightPlanService.isPlanning) {
                            _flightPlanService.togglePlanningMode();
                          }
                          debugPrint('Stopped flight planning mode');
                        }
                        debugPrint('Flight planning toggled: $_showFlightPlanning');
                      } else if (value == 'checklists') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChecklistSettingsScreen(),
                          ),
                        );
                      } else if (value == 'airplane_settings') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AircraftSettingsScreen(),
                          ),
                        );
                      } else if (value == 'licenses') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LicensesScreen(),
                          ),
                        );
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
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.black),
                    onPressed: _showAirportSearch,
                    tooltip: 'Search airports',
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.black),
                    onPressed: _centerOnLocation,
                    tooltip: 'Center on location',
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
          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
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
                  // Compact Flight Planning Widget - replaces the large floating panel
                  CompactFlightPlanWidget(
                    isVisible: _showFlightPlanning,
                    onClose: () {
                      setState(() {
                        _showFlightPlanning = false;
                      });
                      // Stop planning mode - check if we need to toggle
                      if (_flightPlanService.isPlanning) {
                        _flightPlanService.togglePlanningMode();
                      }
                      debugPrint('Flight planning closed from compact widget');
                    },
                  ),
                  // Floating waypoint panel for selected waypoint
                  if (_selectedWaypointIndex != null && 
                      flightPlanService.currentFlightPlan != null &&
                      _selectedWaypointIndex! < flightPlanService.currentFlightPlan!.waypoints.length)
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
