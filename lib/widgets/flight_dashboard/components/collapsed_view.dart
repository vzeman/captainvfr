import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/flight_service.dart';
import '../../../services/heading_service.dart';
import '../../../services/settings_service.dart';
import '../../../screens/flight_detail_screen.dart';
import '../models/flight_icons.dart';
import 'stop_tracking_dialog.dart';

/// Collapsed view of the flight dashboard showing essential flight data
class CollapsedView extends StatelessWidget {
  final VoidCallback onExpand;

  const CollapsedView({
    super.key,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final flightService = Provider.of<FlightService>(context);
    final headingService = Provider.of<HeadingService>(context);
    
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';
        final altitude = flightService.barometricAltitude ?? 0;
        final displayAltitude = isMetric
            ? altitude
            : altitude * 3.28084; // Convert m to ft
        final altitudeUnit = isMetric ? 'm' : 'ft';

        return LayoutBuilder(
          builder: (context, constraints) {
            // Calculate dynamic sizes based on available width
            final availableWidth = constraints.maxWidth;

            // Base sizes that scale with available width
            double iconSize = 12.0;
            double fontSize = 12.0;
            double buttonSize = 28.0;
            double spacing = 2.0;

            if (availableWidth > 400) {
              iconSize = 14.0;
              fontSize = 13.0;
              buttonSize = 32.0;
              spacing = 4.0;
            } else if (availableWidth < 300) {
              iconSize = 10.0;
              fontSize = 11.0;
              buttonSize = 24.0;
              spacing = 1.0;
            }

            // Convert speed based on units
            final speedMs = flightService.currentSpeed;
            final displaySpeed = isMetric
                ? speedMs * 3.6 // Convert m/s to km/h
                : speedMs * 1.94384; // Convert m/s to knots
            final speedUnit = isMetric ? 'km/h' : 'kt';

            return Row(
              children: [
                // Expand button
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: IconButton(
                    icon: Icon(
                      Icons.expand_more,
                      color: const Color(0xFF448AFF),
                      size: iconSize + 4,
                    ),
                    onPressed: onExpand,
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(width: spacing * 2),
                // Speed
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FlightIcons.speed,
                        color: Colors.blueAccent,
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Flexible(
                        child: Text(
                          '${displaySpeed.toStringAsFixed(0)} $speedUnit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Altitude
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FlightIcons.altitude,
                        color: Colors.blueAccent,
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Flexible(
                        child: Text(
                          '${displayAltitude.toStringAsFixed(0)} $altitudeUnit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Heading - Use HeadingService for always-on heading data
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (context) {
                          final hasHeading = headingService.currentHeading != null;
                          return Icon(
                            Icons.navigation,
                            color: hasHeading ? Colors.blueAccent : Colors.grey,
                            size: iconSize,
                          );
                        },
                      ),
                      SizedBox(width: spacing),
                      Flexible(
                        child: Builder(
                          builder: (context) {
                            final hasHeading = headingService.currentHeading != null;
                            return Text(
                              headingService.getFormattedHeading(),
                              style: TextStyle(
                                color: hasHeading ? Colors.white : Colors.grey,
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Tracking button - Made larger for better visibility
                SizedBox(
                  width: buttonSize * 1.5,
                  height: buttonSize * 1.5,
                  child: IconButton(
                    icon: Icon(
                      flightService.isTracking ? Icons.stop : Icons.play_arrow,
                      color: flightService.isTracking
                          ? Colors.red
                          : Colors.green,
                      size: (iconSize + 4) * 1.5,
                    ),
                    onPressed: () async {
                      if (flightService.isTracking) {
                        // Show confirmation dialog
                        final shouldStop = await StopTrackingDialog.show(context);
                        if (shouldStop == true) {
                          final savedFlight = await flightService.stopTracking();
                          
                          // Navigate to flight detail if a flight was saved
                          if (savedFlight != null && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FlightDetailScreen(flight: savedFlight),
                              ),
                            );
                          }
                        }
                      } else {
                        flightService.startTracking();
                      }
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}