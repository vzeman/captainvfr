import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'flight_point.dart';

@HiveType(typeId: 4)
class FlightSegment extends HiveObject {
  @HiveField(0)
  final DateTime startTime;

  @HiveField(1)
  final DateTime endTime;

  @HiveField(2)
  final List<FlightPoint> points;

  @HiveField(3)
  final double distance; // in meters

  @HiveField(4)
  final double averageSpeed; // in m/s

  @HiveField(5)
  final double averageHeading; // in degrees

  @HiveField(6)
  final double startAltitude; // in meters

  @HiveField(7)
  final double endAltitude; // in meters

  @HiveField(8)
  final double averageAltitude; // in meters

  @HiveField(9)
  final double maxAltitude; // in meters

  @HiveField(10)
  final double minAltitude; // in meters

  @HiveField(11)
  final String type; // Type of segment for map display

  FlightSegment({
    required this.startTime,
    required this.endTime,
    required this.points,
    required this.distance,
    required this.averageSpeed,
    required this.averageHeading,
    required this.startAltitude,
    required this.endAltitude,
    required this.averageAltitude,
    required this.maxAltitude,
    required this.minAltitude,
    this.type = 'flight', // Default type
  });

  factory FlightSegment.fromPoints(List<FlightPoint> segmentPoints) {
    if (segmentPoints.isEmpty) {
      throw ArgumentError('Cannot create segment from empty points list');
    }

    final startTime = segmentPoints.first.timestamp;
    final endTime = segmentPoints.last.timestamp;

    double totalDistance = 0.0;
    double totalSpeed = 0.0;
    double totalHeading = 0.0;
    double totalAltitude = 0.0;
    double maxAlt = segmentPoints.first.altitude;
    double minAlt = segmentPoints.first.altitude;

    for (int i = 0; i < segmentPoints.length; i++) {
      final point = segmentPoints[i];
      totalSpeed += point.speed;
      totalHeading += point.heading;
      totalAltitude += point.altitude;

      if (point.altitude > maxAlt) maxAlt = point.altitude;
      if (point.altitude < minAlt) minAlt = point.altitude;

      if (i > 0) {
        final prevPoint = segmentPoints[i - 1];
        final distance = _calculateDistance(
          prevPoint.latitude, prevPoint.longitude,
          point.latitude, point.longitude,
        );
        totalDistance += distance;
      }
    }

    final pointCount = segmentPoints.length;

    return FlightSegment(
      startTime: startTime,
      endTime: endTime,
      points: List.from(segmentPoints),
      distance: totalDistance,
      averageSpeed: totalSpeed / pointCount,
      averageHeading: totalHeading / pointCount,
      startAltitude: segmentPoints.first.altitude,
      endAltitude: segmentPoints.last.altitude,
      averageAltitude: totalAltitude / pointCount,
      maxAltitude: maxAlt,
      minAltitude: minAlt,
      type: 'flight', // Default type for segments created from points
    );
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Duration get duration => endTime.difference(startTime);

  // Convert speed from m/s to km/h
  double get averageSpeedKmh => averageSpeed * 3.6;

  // Get formatted duration
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  // Get formatted distance
  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    } else {
      return '${distance.toStringAsFixed(0)} m';
    }
  }

  // Get LatLng coordinates for map display
  List<LatLng> get coordinates {
    return points.map((point) => LatLng(point.latitude, point.longitude)).toList();
  }

  // Get start and end LatLng for markers
  LatLng get startLatLng {
    if (points.isEmpty) throw StateError('FlightSegment has no points');
    return LatLng(points.first.latitude, points.first.longitude);
  }

  LatLng get endLatLng {
    if (points.isEmpty) throw StateError('FlightSegment has no points');
    return LatLng(points.last.latitude, points.last.longitude);
  }
}
