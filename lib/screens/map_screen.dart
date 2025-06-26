import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:geolocator/geolocator.dart';
import 'dart:async' show Timer;
import 'package:provider/provider.dart';
import 'flight_log_screen.dart';
import '../models/airport.dart';
import '../services/airport_service.dart';
import '../services/flight_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/airport_marker.dart';
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
  late final LocationService _locationService;
  late final WeatherService _weatherService;
  late final MapController _mapController;
  
  // State variables
  bool _isLoading = true;
  bool _isTracking = false;
  bool _showStats = false;
  bool _servicesInitialized = false;
  String _errorMessage = '';
  Timer? _debounceTimer;
  
  // Weather service for airport details
  
  // Location and map state
  Position? _currentPosition;
  List<LatLng> _flightPathPoints = [];
  List<Airport> _airports = [];
  
  // UI state
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Map settings
  static const double _initialZoom = 12.0;
  static const double _maxZoom = 18.0;
  static const double _minZoom = 3.0;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize services
    _weatherService = WeatherService();
    
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
    
    // Get services from provider if not already initialized
    if (!_servicesInitialized) {
      _flightService = Provider.of<FlightService>(context, listen: false);
      _locationService = Provider.of<LocationService>(context, listen: false);
      _airportService = Provider.of<AirportService>(context, listen: false);
      _servicesInitialized = true;
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
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _initialZoom,
        );
        await _loadAirports();
      }
    } catch (e) {
      debugPrint('Error initializing location: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to get location: ${e.toString()}';
          _isLoading = false; // Also set loading to false on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: ${e.toString()}')),
        );
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
                }
              },
            ),
            children: [
              // Tile layer
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
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
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'flight_log',
                    child: Text('Flight Log'),
                  ),
                  // Add more menu items here as needed
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
