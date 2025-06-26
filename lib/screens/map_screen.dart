import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
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
  
  // Weather data
  final Map<String, DateTime> _weatherFetchTimes = {};
  static const Duration _weatherRefreshInterval = Duration(minutes: 15);
  
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
        final bounds = _mapController.bounds;
        if (bounds == null) return;
        
        final zoom = _mapController.zoom;
        
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
        
        // Fetch weather for the new airports
        _fetchWeatherForAirports(newAirports);
      }
    } catch (e) {
      debugPrint('Error loading nearby airports: $e');
    }
  }
  
  // Fetch weather data for a list of airports
  Future<void> _fetchWeatherForAirports(List<Airport> airports) async {
    if (airports.isEmpty) return;
    
    final now = DateTime.now();
    
    for (final airport in airports) {
      // Skip if we've checked this airport recently
      final lastFetch = _weatherFetchTimes[airport.icao];
      if (lastFetch != null && now.difference(lastFetch) < _weatherRefreshInterval) {
        continue;
      }
      
      // Mark this airport as being fetched
      _weatherFetchTimes[airport.icao] = now;
      
      try {
        // Fetch METAR data
        final metar = await _weatherService.fetchMetar(airport.icao);
        if (metar != null && mounted) {
          setState(() {
            airport.updateWeather(metar);
          });
        }
        
        // Fetch TAF data
        final taf = await _weatherService.fetchTaf(airport.icao);
        if (taf != null && mounted) {
          setState(() {
            airport.taf = taf;
            airport.lastWeatherUpdate = DateTime.now().toUtc();
          });
        }
      } catch (e) {
        debugPrint('Error fetching weather for ${airport.icao}: $e');
      }
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
          _mapController.zoom,
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
    if (!mounted) return;
    
    // Show loading indicator
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
            SizedBox(width: 16),
            Text('Loading weather data...'),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );
    
    try {
      // Fetch weather data for this airport
      final now = DateTime.now();
      final lastFetch = _weatherFetchTimes[airport.icao];
      
      if (lastFetch == null || now.difference(lastFetch) > _weatherRefreshInterval) {
        _weatherFetchTimes[airport.icao] = now;
        
        // Fetch METAR data
        final metar = await _weatherService.fetchMetar(airport.icao);
        if (metar != null && mounted) {
          setState(() {
            airport.updateWeather(metar);
          });
        }
        
        // Fetch TAF data
        final taf = await _weatherService.fetchTaf(airport.icao);
        if (taf != null && mounted) {
          setState(() {
            airport.taf = taf;
            airport.lastWeatherUpdate = DateTime.now().toUtc();
          });
        }
      }
      
      // Dismiss loading overlay
      if (mounted) {
        scaffold.hideCurrentSnackBar();
      }
      
      // Show airport info sheet
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => AirportInfoSheet(
            airport: airport,
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching weather for ${airport.icao}: $e');
      if (mounted) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Failed to load weather data: ${e.toString()}'),
            duration: const Duration(seconds: 3),
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
              center: _currentPosition != null
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(0, 0), // Default center
              zoom: _initialZoom,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              onTap: (_, __) => _onMapTapped(),
              onPositionChanged: (MapPosition position, bool hasGesture) {
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
                      _mapController.center,
                      _mapController.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOut',
                  onPressed: () {
                    _mapController.move(
                      _mapController.center,
                      _mapController.zoom - 1,
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
