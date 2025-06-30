import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:hive/hive.dart';
import '../models/flight.dart';
import '../models/flight_point.dart';
import '../adapters/latlng_adapter.dart';

class FlightStorageService {
  static const String _flightBox = 'flights';
  static const String _flightPointsBox = 'flight_points';
  
  static Future<void> init() async {
    // Initialize Hive with a valid directory in your app
    final appDocumentDir = await path_provider.getApplicationDocumentsDirectory();
    
    // Initialize Hive
    if (!Hive.isAdapterRegistered(0)) {
      Hive.init(appDocumentDir.path);
      
      // Register adapters
      Hive.registerAdapter(FlightAdapter());
      Hive.registerAdapter(FlightPointAdapter());
      Hive.registerAdapter(LatLngAdapter());
      
      // Open the boxes
      await Hive.openBox<Flight>(_flightBox);
      await Hive.openBox<FlightPoint>(_flightPointsBox);
    }
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
  
  // Delete a flight and its points
  static Future<void> deleteFlight(String id) async {
    final flightBox = Hive.box<Flight>(_flightBox);
    final flightPointsBox = Hive.box<FlightPoint>(_flightPointsBox);
    
    // Delete all points for this flight
    int i = 0;
    while (true) {
      final pointKey = '${id}_$i';
      if (!flightPointsBox.containsKey(pointKey)) break;
      await flightPointsBox.delete(pointKey);
      i++;
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

// Adapter for Flight class
// Adapter for FlightPoint class
class FlightPointAdapter extends TypeAdapter<FlightPoint> {
  @override
  final int typeId = 1;

  @override
  FlightPoint read(BinaryReader reader) {
    return FlightPoint(
      latitude: reader.readDouble(),
      longitude: reader.readDouble(),
      altitude: reader.readDouble(),
      speed: reader.readDouble(),
      heading: reader.readDouble(),
      accuracy: reader.readDouble(),
      verticalAccuracy: reader.readDouble(),
      speedAccuracy: reader.readDouble(),
      headingAccuracy: reader.readDouble(),
      xAcceleration: reader.readDouble(),
      yAcceleration: reader.readDouble(),
      zAcceleration: reader.readDouble(),
      xGyro: reader.readDouble(),
      yGyro: reader.readDouble(),
      zGyro: reader.readDouble(),
      pressure: reader.readDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt(), isUtc: true),
    );
  }

  @override
  void write(BinaryWriter writer, FlightPoint obj) {
    writer.writeDouble(obj.latitude);
    writer.writeDouble(obj.longitude);
    writer.writeDouble(obj.altitude);
    writer.writeDouble(obj.speed);
    writer.writeDouble(obj.heading);
    writer.writeDouble(obj.accuracy);
    writer.writeDouble(obj.verticalAccuracy);
    writer.writeDouble(obj.speedAccuracy);
    writer.writeDouble(obj.headingAccuracy);
    writer.writeDouble(obj.xAcceleration);
    writer.writeDouble(obj.yAcceleration);
    writer.writeDouble(obj.zAcceleration);
    writer.writeDouble(obj.xGyro);
    writer.writeDouble(obj.yGyro);
    writer.writeDouble(obj.zGyro);
    writer.writeDouble(obj.pressure);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
  }
}

// Adapter for Flight class
class FlightAdapter extends TypeAdapter<Flight> {
  @override
  final int typeId = 0;

  @override
  Flight read(BinaryReader reader) {
    final id = reader.readString();
    final startTime = DateTime.fromMillisecondsSinceEpoch(reader.readInt(), isUtc: true);
    final endTime = reader.readBool() ? DateTime.fromMillisecondsSinceEpoch(reader.readInt(), isUtc: true) : null;
    
    // Read flight stats
    final maxAltitude = reader.readDouble();
    final distanceTraveled = reader.readDouble();
    final movingTime = Duration(milliseconds: reader.readInt());
    final maxSpeed = reader.readDouble();
    final averageSpeed = reader.readDouble();
    
    // Try to read time tracking fields (for backward compatibility with old data)
    DateTime recordingStartedZulu = startTime.toUtc(); // Default
    DateTime? recordingStoppedZulu;
    DateTime? movingStartedZulu;
    DateTime? movingStoppedZulu;

    try {
      // Try to read new time tracking fields
      if (reader.readBool()) { // recordingStartedZulu present
        recordingStartedZulu = DateTime.fromMillisecondsSinceEpoch(reader.readInt(), isUtc: true);
      }
      if (reader.readBool()) { // recordingStoppedZulu present
        recordingStoppedZulu = DateTime.fromMillisecondsSinceEpoch(reader.readInt(), isUtc: true);
      }
      if (reader.readBool()) { // movingStartedZulu present
        movingStartedZulu = DateTime.fromMillisecondsSinceEpoch(reader.readInt(), isUtc: true);
      }
      if (reader.readBool()) { // movingStoppedZulu present
        movingStoppedZulu = DateTime.fromMillisecondsSinceEpoch(reader.readInt(), isUtc: true);
      }
    } catch (e) {
      // If we can't read these fields, it means we're reading old data format
      // Use defaults that we already set above
    }

    // Create a flight with minimal data - points and segments will be loaded separately
    return Flight(
      id: id,
      startTime: startTime,
      endTime: endTime,
      path: const [], // Points will be loaded separately
      maxAltitude: maxAltitude,
      distanceTraveled: distanceTraveled,
      movingTime: movingTime,
      maxSpeed: maxSpeed,
      averageSpeed: averageSpeed,
      recordingStartedZulu: recordingStartedZulu,
      recordingStoppedZulu: recordingStoppedZulu,
      movingStartedZulu: movingStartedZulu,
      movingStoppedZulu: movingStoppedZulu,
      movingSegments: const [], // Segments will be loaded separately if needed
      flightSegments: const [], // Segments will be loaded separately if needed
    );
  }

  @override
  void write(BinaryWriter writer, Flight obj) {
    // Write basic flight info
    writer.writeString(obj.id);
    writer.writeInt(obj.startTime.millisecondsSinceEpoch);    
    writer.writeBool(obj.endTime != null);
    if (obj.endTime != null) {
      writer.writeInt(obj.endTime!.millisecondsSinceEpoch);
    }
    
    // Write flight stats
    writer.writeDouble(obj.maxAltitude);
    writer.writeDouble(obj.distanceTraveled);
    writer.writeInt(obj.movingTime.inMilliseconds);
    writer.writeDouble(obj.maxSpeed);
    writer.writeDouble(obj.averageSpeed);
    
    // Write time tracking fields
    writer.writeBool(true); // recordingStartedZulu present
    writer.writeInt(obj.recordingStartedZulu.millisecondsSinceEpoch);
    writer.writeBool(obj.recordingStoppedZulu != null);
    if (obj.recordingStoppedZulu != null) {
      writer.writeInt(obj.recordingStoppedZulu!.millisecondsSinceEpoch);
    }
    writer.writeBool(obj.movingStartedZulu != null);
    if (obj.movingStartedZulu != null) {
      writer.writeInt(obj.movingStartedZulu!.millisecondsSinceEpoch);
    }
    writer.writeBool(obj.movingStoppedZulu != null);
    if (obj.movingStoppedZulu != null) {
      writer.writeInt(obj.movingStoppedZulu!.millisecondsSinceEpoch);
    }

    // Note: We don't serialize the path points here - they are stored separately
    // in the flight_points box with composite keys
  }
}
