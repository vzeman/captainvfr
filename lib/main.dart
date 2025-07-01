import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_screen.dart';
import 'services/location_service.dart';
import 'services/barometer_service.dart';
import 'services/flight_service.dart';
import 'services/airport_service.dart';
import 'services/cache_service.dart';
import 'services/runway_service.dart';
import 'services/navaid_service.dart';
import 'services/weather_service.dart';
import 'services/frequency_service.dart';
import 'services/flight_plan_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize cache service first
    final cacheService = CacheService();
    await cacheService.initialize();
    debugPrint('✅ Cache service initialized');

    // Initialize services
    final locationService = LocationService();
    final barometerService = BarometerService();
    final airportService = AirportService();
    final runwayService = RunwayService();
    final navaidService = NavaidService();
    final weatherService = WeatherService();
    final frequencyService = FrequencyService();
    final flightPlanService = FlightPlanService();
    final flightService = FlightService(
      barometerService: barometerService,
    );

    // Initialize data services and check for cached data
    await _initializeDataServices(airportService, runwayService, navaidService, weatherService, frequencyService);

    // Initialize the app with providers
    runApp(
      MultiProvider(
        providers: [
          Provider<LocationService>.value(value: locationService),
          Provider<BarometerService>.value(value: barometerService),
          ChangeNotifierProvider<FlightService>.value(
            value: flightService,
          ),
          ChangeNotifierProvider<FlightPlanService>.value(
            value: flightPlanService,
          ),
          Provider<AirportService>.value(value: airportService),
          Provider<CacheService>.value(value: cacheService),
          Provider<RunwayService>.value(value: runwayService),
          Provider<NavaidService>.value(value: navaidService),
          Provider<WeatherService>.value(value: weatherService),
          Provider<FrequencyService>.value(value: frequencyService),
        ],
        child: const CaptainVFRApp(),
      ),
    );

    // Initialize flight service after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await flightService.initialize();
        debugPrint('Flight service initialized successfully');
      } catch (e, stackTrace) {
        debugPrint('Error initializing flight service: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    });
  } catch (e, stackTrace) {
    debugPrint('Error during app initialization: $e');
    debugPrint('Stack trace: $stackTrace');
    // Fallback to show error UI
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Failed to initialize app: $e'),
          ),
        ),
      ),
    );
  }
}

/// Initialize data services and ensure cached data is available
Future<void> _initializeDataServices(
  AirportService airportService,
  RunwayService runwayService,
  NavaidService navaidService,
  WeatherService weatherService,
  FrequencyService frequencyService,
) async {
  debugPrint('🚀 Initializing data services and checking cache...');

  try {
    // Initialize all services
    await Future.wait([
      airportService.initialize(),
      runwayService.initialize(),
      navaidService.initialize(),
      weatherService.initialize(),
      frequencyService.initialize(),
    ]);

    // Check if we have cached data, if not, fetch from network
    final futures = <Future>[];

    // Check airports
    if (airportService.airports.isEmpty) {
      debugPrint('📡 No cached airports found, fetching from network...');
      futures.add(airportService.fetchNearbyAirports());
    } else {
      debugPrint('✅ Found ${airportService.airports.length} cached airports');
    }

    // Check runways
    if (runwayService.runways.isEmpty) {
      debugPrint('📡 No cached runways found, fetching from network...');
      futures.add(runwayService.fetchRunways());
    } else {
      debugPrint('✅ Found ${runwayService.runways.length} cached runways');
    }

    // Check navaids
    if (navaidService.navaids.isEmpty) {
      debugPrint('📡 No cached navaids found, fetching from network...');
      futures.add(navaidService.fetchNavaids());
    } else {
      debugPrint('✅ Found ${navaidService.navaids.length} cached navaids');
    }

    // Check frequencies
    if (frequencyService.frequencies.isEmpty) {
      debugPrint('📡 No cached frequencies found, fetching from network...');
      futures.add(frequencyService.fetchFrequencies());
    } else {
      debugPrint('✅ Found ${frequencyService.frequencies.length} cached frequencies');
    }

    // Wait for all network requests to complete
    if (futures.isNotEmpty) {
      await Future.wait(futures);
      debugPrint('✅ All missing data has been fetched and cached');
    } else {
      debugPrint('✅ All data was available from cache');
    }

  } catch (e, stackTrace) {
    debugPrint('❌ Error initializing data services: $e');
    debugPrint('Stack trace: $stackTrace');
    // Continue with app initialization even if data loading fails
  }
}

class CaptainVFRApp extends StatelessWidget {
  const CaptainVFRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaptainVFR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5), // Blue shade
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(8),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF90CAF9),
          secondary: const Color(0xFF64B5F6),
          surface: const Color(0xFF121212),
          onSurface: Colors.white,
          surfaceContainerHighest: const Color(0xFF121212),
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[900],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(8),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MapScreen(),
    );
  }
}

// Add any additional theme extensions or custom widgets here
