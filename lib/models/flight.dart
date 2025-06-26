import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';
import 'flight_point.dart';

// Extension to convert FlightPoint to LatLng
extension FlightPointExtension on FlightPoint {
  LatLng toLatLng() => LatLng(latitude, longitude);
}

@HiveType(typeId: 0)
class Flight extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  DateTime startTime;
  
  @HiveField(2)
  DateTime? endTime;
  
  @HiveField(3)
  final List<FlightPoint> path;
  
  @HiveField(4)
  double maxAltitude;
  
  @HiveField(5)
  double distanceTraveled;
  
  @HiveField(6)
  Duration movingTime;
  
  @HiveField(7)
  double maxSpeed;
  
  @HiveField(8)
  double averageSpeed;
  
  // Computed properties instead of stored fields for better data consistency
  List<DateTime> get timestamps => path.map((p) => p.timestamp).toList();
  List<double> get speeds => path.map((p) => p.speed).toList();
  List<double> get altitudes => path.map((p) => p.altitude).toList();
  List<double> get vibrationData => path.map((p) => p.vibrationMagnitude).toList();
  
  // Add default constructor for Hive
  Flight({
    required this.id,
    required this.startTime,
    this.endTime,
    List<FlightPoint>? path,
    double? maxAltitude,
    double? distanceTraveled,
    Duration? movingTime,
    double? maxSpeed,
    double? averageSpeed,
  }) : 
    path = path ?? [],
    maxAltitude = maxAltitude ?? 0.0,
    distanceTraveled = distanceTraveled ?? 0.0,
    movingTime = movingTime ?? Duration.zero,
    maxSpeed = maxSpeed ?? 0.0,
    averageSpeed = averageSpeed ?? 0.0;

  // Factory constructor for creating a new flight
  factory Flight.newFlight() {
    final now = DateTime.now();
    return Flight(
      id: now.millisecondsSinceEpoch.toString(),
      startTime: now,
      path: [],
      maxAltitude: 0.0,
      distanceTraveled: 0.0,
      movingTime: Duration.zero,
      maxSpeed: 0.0,
      averageSpeed: 0.0,
    );
  }
  
  // Get list of all positions as LatLng
  List<LatLng> get positions {
    return path.map((point) => LatLng(point.latitude, point.longitude)).toList();
  }
  
  // Create a copy of the flight with updated fields
  Flight copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    List<FlightPoint>? path,
    double? maxAltitude,
    double? distanceTraveled,
    Duration? movingTime,
    double? maxSpeed,
    double? averageSpeed,
  }) {
    return Flight(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      path: path ?? List.from(this.path),
      maxAltitude: maxAltitude ?? this.maxAltitude,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      movingTime: movingTime ?? this.movingTime,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
    );
  }

  // Create Flight from Map
  factory Flight.fromMap(Map<String, dynamic> map) {
    final path = map['path'] != null 
        ? (map['path'] as List<dynamic>).map<FlightPoint>((dynamic point) {
            final p = point as Map<String, dynamic>;
            return FlightPoint(
              latitude: (p['latitude'] ?? p['lat'] ?? 0.0).toDouble(),
              longitude: (p['longitude'] ?? p['lng'] ?? 0.0).toDouble(),
              altitude: (p['altitude'] ?? 0.0).toDouble(),
              speed: (p['speed'] ?? 0.0).toDouble(),
              heading: (p['heading'] ?? 0.0).toDouble(),
              timestamp: p['timestamp'] != null 
                  ? DateTime.parse(p['timestamp'].toString())
                  : DateTime.now(),
              // Default values for sensor data
              accuracy: (p['accuracy'] ?? 0.0).toDouble(),
              verticalAccuracy: (p['verticalAccuracy'] ?? 0.0).toDouble(),
              speedAccuracy: (p['speedAccuracy'] ?? 0.0).toDouble(),
              headingAccuracy: (p['headingAccuracy'] ?? 0.0).toDouble(),
              xAcceleration: (p['xAcceleration'] ?? 0.0).toDouble(),
              yAcceleration: (p['yAcceleration'] ?? 0.0).toDouble(),
              zAcceleration: (p['zAcceleration'] ?? 0.0).toDouble(),
              xGyro: (p['xGyro'] ?? 0.0).toDouble(),
              yGyro: (p['yGyro'] ?? 0.0).toDouble(),
              zGyro: (p['zGyro'] ?? 0.0).toDouble(),
              pressure: (p['pressure'] ?? 0.0).toDouble(),
            );
          }).toList()
        : <FlightPoint>[];

    return Flight(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: map['startTime'] != null 
          ? DateTime.parse(map['startTime']) 
          : DateTime.now(),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      path: path,
      maxAltitude: map['maxAltitude']?.toDouble() ?? 0.0,
      distanceTraveled: map['distanceTraveled']?.toDouble() ?? 0.0,
      movingTime: Duration(milliseconds: (map['movingTime'] ?? 0) as int),
      maxSpeed: (map['maxSpeed'] ?? 0.0).toDouble(),
      averageSpeed: (map['averageSpeed'] ?? 0.0).toDouble(),
    );
  }
  
  // Derived properties
  Duration get duration => endTime != null 
      ? endTime!.difference(startTime)
      : DateTime.now().difference(startTime);
      
  bool get isComplete => endTime != null;
  
  // Calculate time spent moving (speed > 1 m/s)
  Duration get movingTimeCalculated {
    if (speeds.isEmpty) return Duration.zero;
    final movingPoints = speeds.where((speed) => speed > 1.0).length;
    return Duration(seconds: (duration.inSeconds * (movingPoints / speeds.length)).round());
  }

  // Format duration as HH:MM:SS
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
  
  // Format distance in meters to kilometers with 1 decimal place
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  
  // Format speed in m/s to km/h with 1 decimal place
  static String formatSpeed(double speedMps) {
    final speedKph = speedMps * 3.6;
    return '${speedKph.toStringAsFixed(1)} km/h';
  }
}
