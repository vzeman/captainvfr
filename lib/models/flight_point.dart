import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class FlightPoint extends HiveObject {
  @HiveField(0)
  late double latitude;
  @HiveField(1)
  late double longitude;
  @HiveField(2)
  late double altitude;         // In meters
  @HiveField(3)
  late double speed;            // In m/s
  @HiveField(4)
  late double heading;          // In degrees (0-360)
  @HiveField(5)
  late double accuracy;         // Position accuracy in meters
  @HiveField(6)
  late double verticalAccuracy;  // Vertical accuracy in meters
  @HiveField(7)
  late double speedAccuracy;     // Speed accuracy in m/s
  @HiveField(8)
  late double headingAccuracy;   // Heading accuracy in degrees
  @HiveField(9)
  late double xAcceleration;     // X-axis acceleration (m/s²)
  @HiveField(10)
  late double yAcceleration;     // Y-axis acceleration (m/s²)
  @HiveField(11)
  late double zAcceleration;     // Z-axis acceleration (m/s²)
  @HiveField(12)
  late double xGyro;            // X-axis rotation rate (rad/s)
  @HiveField(13)
  late double yGyro;            // Y-axis rotation rate (rad/s)
  @HiveField(14)
  late double zGyro;            // Z-axis rotation rate (rad/s)
  @HiveField(15)
  late double pressure;         // Air pressure in hPa
  @HiveField(16)
  late DateTime timestamp;

  FlightPoint({
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? heading,
    this.accuracy = 0.0,
    this.verticalAccuracy = 0.0,
    this.speedAccuracy = 0.0,
    this.headingAccuracy = 0.0,
    this.xAcceleration = 0.0,
    this.yAcceleration = 0.0,
    this.zAcceleration = 0.0,
    this.xGyro = 0.0,
    this.yGyro = 0.0,
    this.zGyro = 0.0,
    this.pressure = 0.0,
    DateTime? timestamp,
  }) {
    this.latitude = latitude ?? 0.0;
    this.longitude = longitude ?? 0.0;
    this.altitude = altitude ?? 0.0;
    this.speed = speed ?? 0.0;
    this.heading = heading ?? 0.0;
    this.timestamp = timestamp ?? DateTime.now();
  }
  
  // Calculate total acceleration (G-force)
  double get totalAcceleration {
    return math.sqrt(xAcceleration * xAcceleration + 
                   yAcceleration * yAcceleration + 
                   zAcceleration * zAcceleration);
  }
       
  // Calculate vibration magnitude
  double get vibrationMagnitude {
    return math.sqrt(xGyro * xGyro + 
                   yGyro * yGyro + 
                   zGyro * zGyro);
  }

  LatLng get position => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'verticalAccuracy': verticalAccuracy,
      'speedAccuracy': speedAccuracy,
      'headingAccuracy': headingAccuracy,
      'xAccel': xAcceleration,
      'yAccel': yAcceleration,
      'zAccel': zAcceleration,
      'xGyro': xGyro,
      'yGyro': yGyro,
      'zGyro': zGyro,
      'pressure': pressure,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory FlightPoint.fromJson(Map<String, dynamic> json) {
    return FlightPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      verticalAccuracy: (json['verticalAccuracy'] as num?)?.toDouble() ?? 0.0,
      speedAccuracy: (json['speedAccuracy'] as num?)?.toDouble() ?? 0.0,
      headingAccuracy: (json['headingAccuracy'] as num?)?.toDouble() ?? 0.0,
      xAcceleration: (json['xAccel'] as num?)?.toDouble() ?? 0.0,
      yAcceleration: (json['yAccel'] as num?)?.toDouble() ?? 0.0,
      zAcceleration: (json['zAccel'] as num?)?.toDouble() ?? 0.0,
      xGyro: (json['xGyro'] as num?)?.toDouble() ?? 0.0,
      yGyro: (json['yGyro'] as num?)?.toDouble() ?? 0.0,
      zGyro: (json['zGyro'] as num?)?.toDouble() ?? 0.0,
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
