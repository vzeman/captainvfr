import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/map_screen.dart';
import 'screens/offline_data_screen.dart';
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
import 'services/connectivity_service.dart';
import 'services/platform_services.dart';
import 'services/vibration_measurement_service.dart';
import 'services/openaip_service.dart';
import 'widgets/connectivity_banner.dart';
import 'widgets/loading_screen.dart';
import 'services/background_data_service.dart';
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
import 'models/flight_plan.dart';
import 'models/airspace.dart';
import 'models/reporting_point.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Show loading screen immediately
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoadingScreen(),
  ));
  
  try {
    // Initialize Hive and register adapters
    await Hive.initFlutter();
    
    // Migration: Clear airspaces and reporting points caches due to typeId change
    try {
      if (await Hive.boxExists('airspaces')) {
        await Hive.deleteBoxFromDisk('airspaces');
        debugPrint('🗑️ Cleared airspaces cache for migration');
      }
      if (await Hive.boxExists('reportingPoints')) {
        await Hive.deleteBoxFromDisk('reportingPoints');
        debugPrint('🗑️ Cleared reporting points cache for migration');
      }
    } catch (e) {
      debugPrint('⚠️ Error during cache migration: $e');
    }

    // Register flight-related adapters
    Hive.registerAdapter(FlightAdapter());
    Hive.registerAdapter(FlightPointAdapter());
    Hive.registerAdapter(MovingSegmentAdapter());
    Hive.registerAdapter(FlightSegmentAdapter());

    // Register flight plan adapters
    Hive.registerAdapter(FlightPlanAdapter());
    Hive.registerAdapter(WaypointAdapter());
    Hive.registerAdapter(WaypointTypeAdapter());
    Hive.registerAdapter(FlightRulesAdapter());
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
    
    // Register airspace adapter
    Hive.registerAdapter(AirspaceAdapter());
    
    // Register reporting point adapter
    Hive.registerAdapter(ReportingPointAdapter());

    // Initialize cache service first
    final cacheService = CacheService();
    await cacheService.initialize();
    debugPrint('✅ Cache service initialized');

    // Initialize connectivity service first
    final connectivityService = ConnectivityService();
    await connectivityService.initialize();
    connectivityService.startPeriodicChecks();
    debugPrint('✅ Connectivity service initialized');
    
    // Log network diagnostics for Android 12+ debugging
    await PlatformServices.logNetworkState();
    
    // Initialize vibration measurement service (using accelerometer)
    final vibrationMeasurementService = VibrationMeasurementService();
    try {
      await vibrationMeasurementService.initialize();
      debugPrint('✅ Vibration measurement service initialized');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize vibration measurement service: $e');
    }

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
    
    // Initialize OpenAIP service
    final openAIPService = OpenAIPService();
    
    // Initialize OpenAIP service (this will load API key and reporting points if needed)
    try {
      await openAIPService.initialize();
      debugPrint('✅ OpenAIP service initialized');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize OpenAIP service: $e');
    }
    
    // Initialize background data service
    final backgroundDataService = BackgroundDataService();
    await backgroundDataService.initialize(
      airportService: airportService,
      runwayService: runwayService,
      navaidService: navaidService,
      frequencyService: frequencyService,
      cacheService: cacheService,
    );

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

    // Initialize checklist service
    await checklistService.initialize();
    
    // Initialize license service
    await licenseService.initialize();
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectivityService>.value(
            value: connectivityService,
          ),
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
          Provider<OpenAIPService>.value(value: openAIPService),
          Provider<VibrationMeasurementService>.value(value: vibrationMeasurementService),
          ChangeNotifierProvider<BackgroundDataService>.value(
            value: backgroundDataService,
          ),
        ],
        child: const CaptainVFRApp(),
      ),
    );

    // Initialize flight service and start background data loading after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await flightService.initialize();
        debugPrint('✅ Flight service initialized successfully');
      } catch (e, stackTrace) {
        debugPrint('⚠️ Flight service initialization failed: $e');
        debugPrint('Stack trace: $stackTrace');
        // Don't crash the app if flight service fails
      }
      
      // Start loading data in the background
      debugPrint('🚀 Starting background data loading...');
      backgroundDataService.loadDataInBackground();
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

  // Show loading screen first
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoadingScreen(),
  ));

  // Create minimal services
  final connectivityService = ConnectivityService();
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
  
  // Initialize connectivity service even in minimal mode
  connectivityService.initialize().then((_) {
    connectivityService.startPeriodicChecks();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivityService),
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
// Future<void> _initializeDataServices(
//   AirportService airportService,
//   RunwayService runwayService,
//   NavaidService navaidService,
//   WeatherService weatherService,
//   FrequencyService frequencyService,
// ) async {
//   debugPrint('🚀 Initializing data services and checking cache...');
// 
//   try {
//     // Initialize all services
//     await Future.wait([
//       airportService.initialize(),
//       runwayService.initialize(),
//       navaidService.initialize(),
//       weatherService.initialize(),
//       frequencyService.initialize(),
//     ]);
// 
//     // Check if we have cached data, if not, fetch from network
//     final futures = <Future>[];
// 
//     // Check airports
//     if (airportService.airports.isEmpty) {
//       debugPrint('📡 No cached airports found, fetching from network...');
//       futures.add(airportService.fetchNearbyAirports());
//     } else {
//       debugPrint('�� Found ${airportService.airports.length} cached airports');
//     }
// 
//     // Check runways
//     if (runwayService.runways.isEmpty) {
//       debugPrint('📡 No cached runways found, fetching from network...');
//       futures.add(runwayService.fetchRunways());
//     } else {
//       debugPrint('✅ Found ${runwayService.runways.length} cached runways');
//     }
// 
//     // Check navaids
//     if (navaidService.navaids.isEmpty) {
//       debugPrint('📡 No cached navaids found, fetching from network...');
//       futures.add(navaidService.fetchNavaids());
//     } else {
//       debugPrint('✅ Found ${navaidService.navaids.length} cached navaids');
//     }
// 
//     // Check frequencies
//     if (frequencyService.frequencies.isEmpty) {
//       debugPrint('���� No cached frequencies found, fetching from network...');
//       futures.add(frequencyService.fetchFrequencies());
//     } else {
//       debugPrint('✅ Found ${frequencyService.frequencies.length} cached frequencies');
//     }
// 
//     // Wait for all network requests to complete
//     if (futures.isNotEmpty) {
//       await Future.wait(futures);
//       debugPrint('✅ All missing data has been fetched and cached');
//     } else {
//       debugPrint('✅ All data was available from cache');
//     }
// 
//   } catch (e, stackTrace) {
//     debugPrint('❌ Error initializing data services: $e');
//     debugPrint('Stack trace: $stackTrace');
//     // Continue with app initialization even if data loading fails
//   }
// }

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

class CaptainVFRApp extends StatefulWidget {
  const CaptainVFRApp({super.key});

  @override
  State<CaptainVFRApp> createState() => _CaptainVFRAppState();
}

class _CaptainVFRAppState extends State<CaptainVFRApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Navigate to main screen after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const ConnectivityBanner(
            child: MapScreen(),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
      home: const LoadingScreen(),
      routes: {
        '/offline_data': (context) => const OfflineDataScreen(),
      },
    );
  }
}

// Add any additional theme extensions or custom widgets here
