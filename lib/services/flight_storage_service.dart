import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:hive/hive.dart';
import '../models/flight.dart';
import '../models/flight_point.dart';
import '../adapters/latlng_adapter.dart';

class FlightStorageService {
  static const String _flightBox = 'flights';
  static const String _flightPointsBox = 'flight_points';
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // Initialize Hive with a valid directory in your app
    final appDocumentDir = await path_provider
        .getApplicationDocumentsDirectory();

    // Initialize Hive
    Hive.init(appDocumentDir.path);

    // Register adapters only if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FlightAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FlightPointAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(LatLngAdapter());
    }

    // Open the boxes
    await Hive.openBox<Flight>(_flightBox);
    await Hive.openBox<FlightPoint>(_flightPointsBox);

    _initialized = true;
  }

  // Save a flight and its points
  static Future<void> saveFlight(Flight flight) async {
    final flightBox = Hive.box<Flight>(_flightBox);
    final flightPointsBox = Hive.box<FlightPoint>(_flightPointsBox);

    // Save all points with a composite key first
    for (var i = 0; i < flight.path.length; i++) {
      final point = flight.path[i];
      await flightPointsBox.put('${flight.id}_$i', point);
    }

    // Save the flight after points to ensure all points are stored
    await flightBox.put(flight.id, flight);
  }

  // Get all flights
  static Future<List<Flight>> getAllFlights() async {
    final flightBox = Hive.box<Flight>(_flightBox);
    final flightPointsBox = Hive.box<FlightPoint>(_flightPointsBox);

    final flights = <Flight>[];

    for (final flight in flightBox.values) {
      // Retrieve all points for this flight
      final path = <FlightPoint>[];

      int i = 0;
      while (true) {
        final point = flightPointsBox.get('${flight.id}_$i');
        if (point == null) break;

        path.add(point);
        i++;
      }

      // Create a flight instance with the loaded points
      final flightWithPath = flight.copyWith(path: path);
      flights.add(flightWithPath);
    }

    return flights;
  }

  // Get a specific flight by ID with all its points
  static Future<Flight?> getFlight(String id) async {
    final flightBox = Hive.box<Flight>(_flightBox);
    final flightPointsBox = Hive.box<FlightPoint>(_flightPointsBox);

    // Find the flight by ID
    final flight = flightBox.get(id);
    if (flight == null) return null;

    // Retrieve all points for this flight
    final path = <FlightPoint>[];

    int i = 0;
    while (true) {
      final point = flightPointsBox.get('${flight.id}_$i');
      if (point == null) break;

      path.add(point);
      i++;
    }

    // Return a new flight instance with the loaded points
    return flight.copyWith(
      path: path,
      // These will be recalculated by the Flight model
      maxAltitude: null,
      maxSpeed: null,
      averageSpeed: null,
      movingTime: null,
      distanceTraveled: null,
    );
  }

  // Delete a flight by ID and all its points
  static Future<void> deleteFlight(String id) async {
    final flightBox = Hive.box<Flight>(_flightBox);
    final flightPointsBox = Hive.box<FlightPoint>(_flightPointsBox);

    // Delete all points for this flight
    int i = 0;
    while (true) {
      final key = '${id}_$i';
      if (flightPointsBox.containsKey(key)) {
        await flightPointsBox.delete(key);
        i++;
      } else {
        break;
      }
    }

    // Delete the flight
    await flightBox.delete(id);
  }

  // Clear all data (for testing/debugging)
  static Future<void> clearAll() async {
    await Hive.box<Flight>(_flightBox).clear();
    await Hive.box<FlightPoint>(_flightPointsBox).clear();
  }
}
