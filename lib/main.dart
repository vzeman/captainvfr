import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_screen.dart';
import 'services/location_service.dart';
import 'services/barometer_service.dart';
import 'services/flight_service.dart';
import 'services/airport_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize services
    final locationService = LocationService();
    final barometerService = BarometerService();
    final airportService = AirportService();
    final flightService = FlightService(
      barometerService: barometerService,
    );

    // Initialize the app with providers
    runApp(
      MultiProvider(
        providers: [
          Provider<LocationService>.value(value: locationService),
          Provider<BarometerService>.value(value: barometerService),
          ChangeNotifierProvider<FlightService>.value(
            value: flightService,
          ),
          Provider<AirportService>.value(value: airportService),
        ],
        child: const CaptainVFRApp(),
      ),
    );

    // Initialize services after first frame
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
          background: const Color(0xFF121212),
          onSurface: Colors.white,
          surfaceVariant: const Color(0xFF121212),
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
