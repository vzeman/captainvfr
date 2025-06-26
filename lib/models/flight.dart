import 'package:latlong2/latlong.dart';

class Flight {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final List<LatLng> path;
  final double maxAltitude;
  final double distanceTraveled;
  final Duration movingTime;
  final double maxSpeed;
  final double averageSpeed;
  final List<DateTime> timestamps; // Timestamp for each position in the path
  final List<double> speeds; // Speed between points in m/s
  final List<double> altitudes; // Altitude for each point
  
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

  Flight({
    String? id,
    DateTime? startTime,
    this.endTime,
    List<LatLng>? path,
    this.maxAltitude = 0,
    this.distanceTraveled = 0,
    this.movingTime = Duration.zero,
    this.maxSpeed = 0,
    this.averageSpeed = 0,
    List<DateTime>? timestamps,
    List<double>? speeds,
    List<double>? altitudes,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        startTime = startTime ?? DateTime.now(),
        path = path ?? [],
        timestamps = timestamps ?? [],
        speeds = speeds ?? [],
        altitudes = altitudes ?? [];
        
  // Create a copy with updated fields
  Flight copyWith({
    DateTime? endTime,
    List<LatLng>? path,
    double? maxAltitude,
    double? distanceTraveled,
    Duration? movingTime,
    double? maxSpeed,
    double? averageSpeed,
    List<DateTime>? timestamps,
    List<double>? speeds,
    List<double>? altitudes,
  }) {
    return Flight(
      id: id,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      path: path ?? this.path,
      maxAltitude: maxAltitude ?? this.maxAltitude,
      distanceTraveled: distanceTraveled ?? this.distanceTraveled,
      movingTime: movingTime ?? this.movingTime,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      timestamps: timestamps ?? this.timestamps,
      speeds: speeds ?? this.speeds,
      altitudes: altitudes ?? this.altitudes,
    );
  }

  // Convert Flight to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'path': path.map((point) => 
        {'lat': point.latitude, 'lng': point.longitude}
      ).toList(),
      'maxAltitude': maxAltitude,
      'distanceTraveled': distanceTraveled,
      'movingTime': movingTime.inMilliseconds,
      'maxSpeed': maxSpeed,
      'averageSpeed': averageSpeed,
      'timestamps': timestamps.map((t) => t.toIso8601String()).toList(),
      'speeds': speeds,
      'altitudes': altitudes,
    };
  }

  // Create Flight from Map
  factory Flight.fromMap(Map<String, dynamic> map) {
    return Flight(
      id: map['id'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      path: (map['path'] as List).map((point) => 
        LatLng(point['lat'], point['lng'])
      ).toList(),
      maxAltitude: map['maxAltitude']?.toDouble() ?? 0.0,
      distanceTraveled: map['distanceTraveled']?.toDouble() ?? 0.0,
      movingTime: Duration(milliseconds: (map['movingTime'] ?? 0) as int),
      maxSpeed: (map['maxSpeed'] ?? 0.0).toDouble(),
      averageSpeed: (map['averageSpeed'] ?? 0.0).toDouble(),
      timestamps: map['timestamps'] != null 
          ? (map['timestamps'] as List).map((t) => DateTime.parse(t)).toList()
          : [],
      speeds: map['speeds'] != null 
          ? (map['speeds'] as List).map((s) => (s as num).toDouble()).toList()
          : [],
      altitudes: map['altitudes'] != null
          ? (map['altitudes'] as List).map((a) => (a as num).toDouble()).toList()
          : [],
    );
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
