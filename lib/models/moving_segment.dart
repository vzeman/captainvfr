import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class MovingSegment extends HiveObject {
  @HiveField(0)
  DateTime start;

  @HiveField(1)
  DateTime end;

  @HiveField(2)
  Duration duration;

  @HiveField(3)
  double distance;

  @HiveField(4)
  double averageSpeed;

  @HiveField(5)
  double averageHeading;

  @HiveField(6)
  double startAltitude;

  @HiveField(7)
  double endAltitude;

  @HiveField(8)
  double averageAltitude;

  @HiveField(9)
  double maxAltitude;

  @HiveField(10)
  double minAltitude;

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

  // Format Zulu time for display
  String get startZuluFormatted => _formatZuluTime(start);
  String get endZuluFormatted => _formatZuluTime(end);

  static String _formatZuluTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return '${utc.hour.toString().padLeft(2, '0')}:'
           '${utc.minute.toString().padLeft(2, '0')}:'
           '${utc.second.toString().padLeft(2, '0')}Z';
  }

  // Format duration with seconds if less than 1 minute
  String get formattedDuration {
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}s';
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);

      if (hours > 0) {
        return '${hours}h ${minutes}m ${seconds}s';
      } else {
        return '${minutes}m ${seconds}s';
      }
    }
  }

  // Format average heading
  String get formattedHeading => '${averageHeading.toStringAsFixed(0)}°';

  // Format altitude information
  String get formattedStartAltitude => '${startAltitude.toStringAsFixed(0)} m';
  String get formattedEndAltitude => '${endAltitude.toStringAsFixed(0)} m';
  String get formattedAverageAltitude => '${averageAltitude.toStringAsFixed(0)} m';
  String get formattedMaxAltitude => '${maxAltitude.toStringAsFixed(0)} m';
  String get formattedMinAltitude => '${minAltitude.toStringAsFixed(0)} m';

  // Format average speed in km/h
  String get formattedAverageSpeed => '${(averageSpeed * 3.6).toStringAsFixed(1)} km/h';

  // Calculate altitude change
  double get altitudeChange => endAltitude - startAltitude;
  String get formattedAltitudeChange {
    final change = altitudeChange;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(0)} m';
  }
}
