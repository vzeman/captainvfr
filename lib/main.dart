import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
import 'services/aircraft_settings_service.dart';
import 'services/checklist_service.dart';
import 'services/license_service.dart';
import 'adapters/flight_plan_adapters.dart';
import 'adapters/latlng_adapter.dart';
import 'models/manufacturer.dart';
import 'models/model.dart';
import 'models/aircraft.dart';
import 'models/checklist_item.dart';
import 'models/checklist.dart';
import 'models/flight.dart';
import 'models/duration_adapter.dart';
import 'models/flight_point.dart';
import 'models/flight_segment.dart';
import 'models/moving_segment.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Hive and register adapters
    await Hive.initFlutter();

    // Register flight-related adapters
    Hive.registerAdapter(FlightAdapter());
    Hive.registerAdapter(FlightPointAdapter());
    Hive.registerAdapter(MovingSegmentAdapter());
    Hive.registerAdapter(FlightSegmentAdapter());

    // Register flight plan adapters
    Hive.registerAdapter(FlightPlanAdapter());
    Hive.registerAdapter(WaypointAdapter());
    Hive.registerAdapter(WaypointTypeAdapter());
    Hive.registerAdapter(LatLngAdapter());

    // Register aircraft-related adapters
    Hive.registerAdapter(ManufacturerAdapter());
    Hive.registerAdapter(ModelAdapter());
    Hive.registerAdapter(AircraftCategoryAdapter());
    Hive.registerAdapter(AircraftAdapter());
    // Adapter for Duration fields in Flight model
    Hive.registerAdapter(DurationAdapter());
    // Register checklist adapters
    Hive.registerAdapter(ChecklistItemAdapter());
    Hive.registerAdapter(ChecklistAdapter());

    // Initialize cache service first
    final cacheService = CacheService();
    await cacheService.initialize();
    debugPrint('✅ Cache service initialized');

    // Initialize services with error handling
    final locationService = LocationService();
    final barometerService = BarometerService();
    final airportService = AirportService();
    final runwayService = RunwayService();
    final navaidService = NavaidService();
    final weatherService = WeatherService();
    final frequencyService = FrequencyService();
    final flightPlanService = FlightPlanService();

    // Initialize flight plan service with error handling
    try {
      await flightPlanService.initialize();
      debugPrint('✅ Flight plan service initialized');
    } catch (e) {
      debugPrint('⚠️ Flight plan service initialization failed: $e');
    }

    final flightService = FlightService(
      barometerService: barometerService,
    );

    // Initialize aircraft settings service with comprehensive error handling
    final aircraftSettingsService = AircraftSettingsService();

    // Initialize checklist service
    final checklistService = ChecklistService();
    
    // Initialize license service
    final licenseService = LicenseService();

    try {
      await aircraftSettingsService.initialize();
      debugPrint('✅ Aircraft settings service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing aircraft settings service: $e');
      debugPrint('Error type: ${e.runtimeType}');

      // Check for various Hive data corruption issues
      final errorString = e.toString();
      final isDataCorruption = errorString.contains('unknown typeId') ||
          errorString.contains('is not a subtype of type') ||
          errorString.contains('type cast') ||
          errorString.contains('Null') ||
          errorString.contains('type \'Null\' is not a subtype') ||
          errorString.contains('in type cast') ||
          e is TypeError;

      if (isDataCorruption) {
        debugPrint('⚠️ Clearing Hive boxes due to data corruption: $e');
        try {
          await _clearHiveBoxes();
          debugPrint('✅ Hive boxes cleared, retrying initialization...');
          // Try initializing again after clearing boxes
          await aircraftSettingsService.initialize();
          debugPrint('✅ Aircraft settings service initialized after clearing boxes');
        } catch (retryError) {
          debugPrint('❌ Failed to initialize after clearing boxes: $retryError');
          // Don't rethrow - continue with app initialization
        }
      } else {
        debugPrint('❌ Unexpected error type: $e');
        // Don't rethrow - continue with app initialization
      }
    }

    // Initialize data services with error handling - don't block app startup
    try {
      await _initializeDataServices(airportService, runwayService, navaidService, weatherService, frequencyService);
    } catch (e) {
      debugPrint('⚠️ Data services initialization failed: $e');
      // Continue with app initialization
    }

    // Initialize checklist service then run the app
    await checklistService.initialize();
    
    // Initialize license service
    await licenseService.initialize();
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
          ChangeNotifierProvider<AircraftSettingsService>.value(
            value: aircraftSettingsService,
          ),
          ChangeNotifierProvider<ChecklistService>.value(
            value: checklistService,
          ),
          ChangeNotifierProvider<LicenseService>.value(
            value: licenseService,
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
        debugPrint('✅ Flight service initialized successfully');
      } catch (e, stackTrace) {
        debugPrint('⚠️ Flight service initialization failed: $e');
        debugPrint('Stack trace: $stackTrace');
        // Don't crash the app if flight service fails
      }
    });

  } catch (e, stackTrace) {
    debugPrint('❌ Critical error during app initialization: $e');
    debugPrint('Stack trace: $stackTrace');

    // Try to clear corrupted data and start with minimal functionality
    final errorString = e.toString();
    final isDataCorruption = errorString.contains('unknown typeId') ||
        errorString.contains('is not a subtype of type') ||
        errorString.contains('type cast') ||
        errorString.contains('Null') ||
        errorString.contains('type \'Null\' is not a subtype') ||
        errorString.contains('in type cast') ||
        e is TypeError;

    if (isDataCorruption) {
      debugPrint('⚠️ Attempting emergency Hive cleanup...');
      try {
        await _clearHiveBoxes();
        debugPrint('✅ Emergency Hive cleanup completed');

        // Restart the app initialization with minimal services
        _runMinimalApp();
      } catch (cleanupError) {
        debugPrint('❌ Emergency cleanup failed: $cleanupError');
        _runMinimalApp();
      }
    } else {
      debugPrint('❌ Non-corruption error, starting with minimal app');
      _runMinimalApp();
    }
  }
}

/// Run the app with minimal functionality when full initialization fails
void _runMinimalApp() {
  debugPrint('🚀 Starting app with minimal functionality...');

  // Create minimal services
  final locationService = LocationService();
  final barometerService = BarometerService();
  final airportService = AirportService();
  final runwayService = RunwayService();
  final navaidService = NavaidService();
  final weatherService = WeatherService();
  final frequencyService = FrequencyService();
  final flightPlanService = FlightPlanService();
  final aircraftSettingsService = AircraftSettingsService();
  final checklistService = ChecklistService();
  final licenseService = LicenseService();
  final cacheService = CacheService();
  final flightService = FlightService(barometerService: barometerService);

  runApp(
    MultiProvider(
      providers: [
        Provider<LocationService>.value(value: locationService),
        Provider<BarometerService>.value(value: barometerService),
        ChangeNotifierProvider<FlightService>.value(value: flightService),
        ChangeNotifierProvider<FlightPlanService>.value(value: flightPlanService),
        ChangeNotifierProvider<AircraftSettingsService>.value(value: aircraftSettingsService),
        ChangeNotifierProvider<ChecklistService>.value(value: checklistService),
        ChangeNotifierProvider<LicenseService>.value(value: licenseService),
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
      debugPrint('�� Found ${airportService.airports.length} cached airports');
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
      debugPrint('���� No cached frequencies found, fetching from network...');
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

/// Clear Hive boxes to resolve typeId mismatch issues
Future<void> _clearHiveBoxes() async {
  debugPrint('🧹 Clearing Hive boxes...');
  try {
    // List of all known box names that might contain problematic data
    final boxNames = [
      'airports',
      'runways',
      'navaids',
      'frequencies',
      'flights',
      'flightPlans',
      'manufacturers',
      'airplaneTypes',
      'airplanes',
      'cache',
    ];

    // Close all open boxes first - handle each individually to avoid cascade failures
    for (final boxName in boxNames) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          await box.close();
          debugPrint('✅ Closed box: $boxName');
        }
      } catch (e) {
        debugPrint('⚠️ Error closing box $boxName: $e');
        // Continue with other boxes even if one fails to close
      }
    }

    // Wait a bit to ensure all boxes are properly closed
    await Future.delayed(const Duration(milliseconds: 100));

    // Delete all boxes from disk - handle each individually
    for (final boxName in boxNames) {
      try {
        await Hive.deleteBoxFromDisk(boxName);
        debugPrint('✅ Deleted box from disk: $boxName');
      } catch (e) {
        debugPrint('⚠️ Error deleting box $boxName: $e');
        // Continue with other boxes even if one fails to delete
      }
    }

    // As a final fallback, try to clear all Hive data
    try {
      await Hive.deleteFromDisk();
      debugPrint('��� All Hive data cleared from disk');
    } catch (e) {
      debugPrint('⚠️ Error with global Hive clear: $e');
    }

    debugPrint('✅ Hive boxes cleared successfully');
  } catch (e) {
    debugPrint('❌ Error clearing Hive boxes: $e');
    // Last resort - try to clear everything
    try {
      await Hive.deleteFromDisk();
      debugPrint('✅ All Hive data cleared from disk as fallback');
    } catch (e2) {
      debugPrint('❌ Failed to clear Hive data from disk: $e2');
      rethrow;
    }
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
