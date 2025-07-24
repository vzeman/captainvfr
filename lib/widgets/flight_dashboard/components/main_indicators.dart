import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/flight_service.dart';
import '../../../services/barometer_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/flight_plan_service.dart';
import '../../../widgets/compass_widget.dart';
import '../models/flight_icons.dart';
import 'indicator_widget.dart';

/// Main indicators section showing altitude, speed and compass
class MainIndicators extends StatelessWidget {
  final FlightService flightService;
  final BarometerService barometerService;

  const MainIndicators({
    super.key,
    required this.flightService,
    required this.barometerService,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';
        final altitude = flightService.barometricAltitude ?? 0;
        final displayAltitude = isMetric
            ? altitude
            : altitude * 3.28084; // Convert m to ft
        final altitudeUnit = isMetric ? 'm' : 'ft';

        // Convert speed based on units
        final speedMs = flightService.currentSpeed;
        final displaySpeed = isMetric
            ? speedMs * 3.6 // Convert m/s to km/h
            : speedMs * 1.94384; // Convert m/s to knots
        final speedUnit = isMetric ? 'km/h' : 'kt';

        // Get target heading from flight plan
        double? targetHeading;
        final flightPlan = Provider.of<FlightPlanService>(context, listen: false)
            .currentFlightPlan;
        if (flightPlan != null && 
            flightPlan.waypoints.isNotEmpty && 
            flightService.flightPath.isNotEmpty) {
          final currentPosition = flightService.flightPath.last;
          final nextWaypoint = flightPlan.waypoints.first;
          final distance = Distance();
          final bearing = distance.bearing(
            LatLng(currentPosition.latitude, currentPosition.longitude),
            LatLng(nextWaypoint.latitude, nextWaypoint.longitude),
          );
          targetHeading = bearing;
        }

        return Row(
          children: [
            Expanded(
              child: IndicatorWidget(
                label: 'ALT',
                value: displayAltitude.toStringAsFixed(0),
                unit: altitudeUnit,
                icon: FlightIcons.altitude,
              ),
            ),
            Expanded(
              child: IndicatorWidget(
                label: 'SPEED',
                value: displaySpeed.toStringAsFixed(0),
                unit: speedUnit,
                icon: FlightIcons.speed,
              ),
            ),
            Expanded(
              child: Center(
                child: CompassWidget(
                  heading: flightService.currentHeading ?? 0,
                  targetHeading: targetHeading,
                  size: 50,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}