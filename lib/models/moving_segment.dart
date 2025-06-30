import 'package:hive/hive.dart';

@HiveType(typeId: 3)
class MovingSegment extends HiveObject {
  @HiveField(0)
  final DateTime start;

  @HiveField(1)
  final DateTime end;

  @HiveField(2)
  final Duration duration;

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

  MovingSegment({
    required this.start,
    required this.end,
    required this.duration,
    required this.distance,
    required this.averageSpeed,
    required this.averageHeading,
    required this.startAltitude,
    required this.endAltitude,
    required this.averageAltitude,
    required this.maxAltitude,
    required this.minAltitude,
  });

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

  // Additional formatting methods for the UI
  String get formattedAverageSpeed => '${averageSpeedKmh.toStringAsFixed(1)} km/h';

  String get formattedHeading => '${averageHeading.toStringAsFixed(0)}°';

  String get formattedStartAltitude => '${startAltitude.toStringAsFixed(0)} m';

  String get formattedEndAltitude => '${endAltitude.toStringAsFixed(0)} m';

  String get formattedAverageAltitude => '${averageAltitude.toStringAsFixed(0)} m';

  String get formattedMaxAltitude => '${maxAltitude.toStringAsFixed(0)} m';

  String get formattedMinAltitude => '${minAltitude.toStringAsFixed(0)} m';

  double get altitudeChange => endAltitude - startAltitude;

  String get formattedAltitudeChange {
    final change = altitudeChange;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(0)} m';
  }

  String get startZuluFormatted {
    final utc = start.toUtc();
    return '${utc.hour.toString().padLeft(2, '0')}:'
           '${utc.minute.toString().padLeft(2, '0')}:'
           '${utc.second.toString().padLeft(2, '0')}Z';
  }

  String get endZuluFormatted {
    final utc = end.toUtc();
    return '${utc.hour.toString().padLeft(2, '0')}:'
           '${utc.minute.toString().padLeft(2, '0')}:'
           '${utc.second.toString().padLeft(2, '0')}Z';
  }
}
