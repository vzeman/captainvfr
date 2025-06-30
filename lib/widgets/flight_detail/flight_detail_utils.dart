import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/flight.dart';

class FlightDetailUtils {
  // Format duration with seconds if less than 1 minute
  static String formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}s';
    } else {
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
  }

  // Format Zulu time
  static String formatZuluTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return '${utc.hour.toString().padLeft(2, '0')}:'
           '${utc.minute.toString().padLeft(2, '0')}:'
           '${utc.second.toString().padLeft(2, '0')}Z';
  }

  // Share flight data
  static void shareFlightData(Flight flight) {
    // Calculate min altitude from altitudes list
    final minAltitude = flight.altitudes.isNotEmpty
        ? flight.altitudes.reduce((a, b) => a < b ? a : b)
        : 0.0;

    // Prepare the flight data for sharing
    final StringBuffer sb = StringBuffer();
    sb.writeln('Flight Details:');
    sb.writeln('Date: ${DateFormat('MMM d, y').format(flight.startTime)}');
    sb.writeln('Duration: ${formatDuration(flight.duration)}');
    sb.writeln('Distance: ${(flight.distanceTraveled / 1000).toStringAsFixed(1)} km');
    sb.writeln('Max Speed: ${(flight.maxSpeed * 3.6).toStringAsFixed(1)} km/h');
    sb.writeln('Avg Speed: ${(flight.averageSpeed * 3.6).toStringAsFixed(1)} km/h');
    sb.writeln('Max Altitude: ${flight.maxAltitude.toStringAsFixed(0)} m');
    sb.writeln('Min Altitude: ${minAltitude.toStringAsFixed(0)} m');
    sb.writeln('Points: ${flight.path.length}');
    sb.writeln('Recording Started: ${formatZuluTime(flight.recordingStartedZulu)}');
    if (flight.recordingStoppedZulu != null) {
      sb.writeln('Recording Stopped: ${formatZuluTime(flight.recordingStoppedZulu!)}');
    }

    // Share the flight data using the correct SharePlus API
    Share.share(sb.toString());
  }
}
