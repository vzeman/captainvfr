import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:geolocator/geolocator.dart';
import 'dart:async' show Timer;
import 'package:provider/provider.dart';
import 'flight_log_screen.dart';
import '../models/airport.dart';
import '../models/navaid.dart';
import '../services/airport_service.dart';
import '../services/navaid_service.dart';
import '../services/runway_service.dart';
import '../services/frequency_service.dart';
import '../services/flight_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/airport_marker.dart';
import '../widgets/navaid_marker.dart';
import '../widgets/airport_info_sheet.dart';
import '../widgets/flight_dashboard.dart';
import '../widgets/airport_search_delegate.dart';

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
  late final RunwayService _runwayService;
  late final FrequencyService _frequencyService;
  late final LocationService _locationService;
  late final WeatherService _weatherService;
  late final MapController _mapController;
  
  // State variables
  bool _isLoading = true;
  bool _isTracking = false;
  bool _showStats = false;
  bool _showNavaids = false; // Toggle for navaid display
  bool _servicesInitialized = false;
  String _errorMessage = '';
  Timer? _debounceTimer;
  
  // Location and map state
  Position? _currentPosition;
  List<LatLng> _flightPathPoints = [];
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
      _runwayService = Provider.of<RunwayService>(context, listen: false);
      _frequencyService = Provider.of<FrequencyService>(context, listen: false);
      _weatherService = Provider.of<WeatherService>(context, listen: false);
      _servicesInitialized = true;

      // Initialize services with caching
      _initializeServices();
    }
  }
  
  @override
  void dispose() {
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
          if (mounted && _mapController.camera != null) {
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
    if (!_showNavaids) return;

    try {
      // Ensure navaids are fetched
      await _navaidService.fetchNavaids();

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
      debugPrint('Error loading navaids: $e');
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
  
  // Toggle flight tracking
  void _toggleTracking() {
    setState(() => _isTracking = !_isTracking);
    if (_isTracking) {
      _flightService.startTracking();
      _centerOnLocation();
    } else {
      _flightService.stopTracking();
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
    setState(() {
      _showNavaids = !_showNavaids;
    });

    // Load navaids immediately when toggled on
    if (_showNavaids) {
      _loadNavaids();
    }
  }

  // Handle map tap
  void _onMapTapped() {
    debugPrint('Map tapped');
    // Close any open dialogs or menus when tapping the map
    if (mounted) {
      debugPrint('Popping all routes until first');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      debugPrint('Context not mounted, cannot pop routes');
    }
  }
  
  // Handle airport selection
  Future<void> _onAirportSelected(Airport airport) async {
    debugPrint('_onAirportSelected called for ${airport.icao} - ${airport.name}');
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
    try {
      await _airportService.initialize();
      await _navaidService.initialize();
      debugPrint('✅ Services initialized with cached data');
    } catch (e) {
      debugPrint('❌ Error initializing services: $e');
    }
  }

  /// Refresh all data from network
  Future<void> _refreshAllData() async {
    try {
      debugPrint('🔄 Refreshing all data...');

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Refreshing all aviation data...'),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      // Refresh all data services
      await Future.wait([
        _airportService.refreshData(),
        _navaidService.refreshData(),
        _runwayService.fetchRunways(forceRefresh: true),
        _frequencyService.fetchFrequencies(forceRefresh: true),
      ]);

      // Reload current view
      await _loadAirports();
      if (_showNavaids) {
        await _loadNavaids();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All data refreshed successfully'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      debugPrint('✅ All data refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error refreshing data: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
              onTap: (_, __) => _onMapTapped(),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  _loadAirports();
                  // Also load navaids if they're enabled
                  if (_showNavaids) {
                    _loadNavaids();
                  }
                }
              },
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.captainvfr',
              ),
              // Flight path layer
              if (_flightPathPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _flightPathPoints,
                      color: Colors.blue.withOpacity(0.7),
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              // Airport markers with tap handling
              AirportMarkersLayer(
                airports: _airports,
                onAirportTap: _onAirportSelected,
              ),
              // Navaid markers
              if (_showNavaids && _navaids.isNotEmpty)
                NavaidMarkersLayer(
                  navaids: _navaids,
                  onNavaidTap: _onNavaidSelected,
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
          // Zoom controls
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoomIn',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOut',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          
          // Flight dashboard overlay
          if (_showStats)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _showStats ? 200 : 0,
                child: const FlightDashboard(),
              ),
            ),
          // App bar
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: PopupMenuButton<String>(
                icon: const Icon(Icons.menu, color: Colors.black),
                onSelected: (value) {
                  if (value == 'flight_log') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FlightLogScreen(),
                      ),
                    );
                  } else if (value == 'refresh_data') {
                    _refreshAllData();
                  }
                },
                itemBuilder: (BuildContext context) => [
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
                    value: 'refresh_data',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text('Refresh Data'),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.black),
                  onPressed: _showAirportSearch,
                  tooltip: 'Search airports',
                ),
                IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.black),
                  onPressed: _centerOnLocation,
                ),
                IconButton(
                  icon: Icon(
                    _isTracking ? Icons.stop : Icons.flight,
                    color: _isTracking ? Colors.red : Colors.black,
                  ),
                  onPressed: _toggleTracking,
                ),
                IconButton(
                  icon: const Icon(Icons.analytics, color: Colors.black),
                  onPressed: _toggleStats,
                ),
                IconButton(
                  icon: Icon(
                    _showNavaids ? Icons.visibility : Icons.visibility_off,
                    color: Colors.black,
                  ),
                  onPressed: _toggleNavaids,
                  tooltip: 'Toggle Navaids',
                ),
              ],
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
        ],
      ),
    );
  }
}
