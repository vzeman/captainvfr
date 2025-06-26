import 'package:latlong2/latlong.dart';

class FlightPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double heading;
  final DateTime timestamp;

  FlightPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.heading,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  LatLng get position => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory FlightPoint.fromJson(Map<String, dynamic> json) {
    return FlightPoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      altitude: json['altitude'] as double,
      speed: json['speed'] as double,
      heading: json['heading'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
