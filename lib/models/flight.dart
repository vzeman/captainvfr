import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';
import 'flight_point.dart';
import 'moving_segment.dart';
import 'flight_segment.dart';

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

  // New time tracking fields
  @HiveField(9)
  DateTime recordingStartedZulu;

  @HiveField(10)
  DateTime? recordingStoppedZulu;

  @HiveField(11)
  DateTime? movingStartedZulu;

  @HiveField(12)
  DateTime? movingStoppedZulu;

  @HiveField(13)
  final List<MovingSegment> movingSegments;

  @HiveField(14)
  final List<FlightSegment> flightSegments;

  Flight({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.path,
    this.maxAltitude = 0.0,
    this.distanceTraveled = 0.0,
    this.movingTime = Duration.zero,
    this.maxSpeed = 0.0,
    this.averageSpeed = 0.0,
    required this.recordingStartedZulu,
    this.recordingStoppedZulu,
    this.movingStartedZulu,
    this.movingStoppedZulu,
    List<MovingSegment>? movingSegments,
    List<FlightSegment>? flightSegments,
  }) : movingSegments = movingSegments ?? [],
       flightSegments = flightSegments ?? [];

  Duration get duration => endTime != null
      ? endTime!.difference(startTime)
      : DateTime.now().difference(startTime);

  // Get all positions as LatLng for map display
  List<LatLng> get positions => path.map((point) => point.toLatLng()).toList();

  // Get altitudes for charts
  List<double> get altitudes => path.map((point) => point.altitude).toList();

  // Get speeds for charts
  List<double> get speeds => path.map((point) => point.speed).toList();

  // Get accelerometer data for vibration analysis
  List<double> get vibrationData {
    return path.map((point) {
      final x = point.xAcceleration ?? 0.0;
      final y = point.yAcceleration ?? 0.0;
      final z = point.zAcceleration ?? 0.0;
      return (x * x + y * y + z * z).abs(); // Magnitude of acceleration
    }).toList();
  }

  // Get all segments (both moving and flight segments) for visualization
  List<dynamic> get allSegments {
    final List<dynamic> segments = [];
    segments.addAll(movingSegments);
    segments.addAll(flightSegments);
    // Sort by start time
    segments.sort((a, b) {
      final aStart = a is MovingSegment ? a.start : (a as FlightSegment).startTime;
      final bStart = b is MovingSegment ? b.start : (b as FlightSegment).startTime;
      return aStart.compareTo(bStart);
    });
    return segments;
  }

  // Additional computed properties
  Duration get totalRecordingTime {
    if (recordingStoppedZulu != null) {
      return recordingStoppedZulu!.difference(recordingStartedZulu);
    }
    return DateTime.now().toUtc().difference(recordingStartedZulu);
  }

  // Pause points (for tracking stops during flight)
  List<FlightPoint> get pausePoints {
    // This would be populated by the flight service
    // For now, return empty list
    return [];
  }

  // Add copyWith method for creating modified copies
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
    DateTime? recordingStartedZulu,
    DateTime? recordingStoppedZulu,
    DateTime? movingStartedZulu,
    DateTime? movingStoppedZulu,
    List<MovingSegment>? movingSegments,
    List<FlightSegment>? flightSegments,
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
      recordingStartedZulu: recordingStartedZulu ?? this.recordingStartedZulu,
      recordingStoppedZulu: recordingStoppedZulu ?? this.recordingStoppedZulu,
      movingStartedZulu: movingStartedZulu ?? this.movingStartedZulu,
      movingStoppedZulu: movingStoppedZulu ?? this.movingStoppedZulu,
      movingSegments: movingSegments ?? List.from(this.movingSegments),
      flightSegments: flightSegments ?? List.from(this.flightSegments),
    );
  }
}
