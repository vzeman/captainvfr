import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/flight_service.dart';
import '../../../services/barometer_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/flight_plan_service.dart';
import '../models/flight_icons.dart';
import 'small_indicator_widget.dart';

/// Secondary indicators showing time, distance, vertical speed, G-force and flight plan info
class SecondaryIndicators extends StatelessWidget {
  final FlightService flightService;
  final BarometerService barometerService;

  const SecondaryIndicators({
    super.key,
    required this.flightService,
    required this.barometerService,
  });

  @override
  Widget build(BuildContext context) {
    final hasFlightPlan =
        Provider.of<FlightPlanService>(
          context,
          listen: false,
        ).currentFlightPlan !=
        null;

    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';
        final distanceMeters = flightService.totalDistance;
        final displayDistance = isMetric
            ? distanceMeters / 1000 // Convert to km
            : distanceMeters * 0.000621371; // Convert to miles
        final distanceUnit = isMetric ? 'km' : 'mi';

        // Convert vertical speed based on units
        final verticalSpeedFpm = flightService.verticalSpeed;
        final displayVerticalSpeed = isMetric
            ? verticalSpeedFpm * 0.00508 // Convert fpm to m/s
            : verticalSpeedFpm;
        final verticalSpeedUnit = isMetric ? 'm/s' : 'fpm';
        final verticalSpeedStr = isMetric
            ? displayVerticalSpeed.toStringAsFixed(1)
            : displayVerticalSpeed.toStringAsFixed(0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: SmallIndicatorWidget(
                label: 'TIME',
                value: flightService.formattedFlightTime,
                icon: FlightIcons.time,
              ),
            ),
            Expanded(
              child: SmallIndicatorWidget(
                label: 'DIST',
                value: '${displayDistance.toStringAsFixed(1)}$distanceUnit',
                icon: FlightIcons.distance,
              ),
            ),
            Expanded(
              child: SmallIndicatorWidget(
                label: 'V/S',
                value: '$verticalSpeedStr $verticalSpeedUnit',
                icon: FlightIcons.verticalSpeed,
              ),
            ),
            Expanded(
              child: SmallIndicatorWidget(
                label: 'G',
                value: '${flightService.currentGForce.toStringAsFixed(2)}g',
                icon: Icons.speed,
              ),
            ),
            if (hasFlightPlan)
              Expanded(
                child: SmallIndicatorWidget(
                  label: 'NEXT',
                  value: _buildNextWaypointInfo(flightService, context),
                  icon: Icons.flag,
                ),
              ),
            if (hasFlightPlan)
              Expanded(
                child: SmallIndicatorWidget(
                  label: 'ETA',
                  value: _buildTotalFlightETA(flightService, context),
                  icon: Icons.flight_land,
                ),
              ),
          ],
        );
      },
    );
  }

  String _buildNextWaypointInfo(FlightService flightService, BuildContext context) {
    final flightPlan = Provider.of<FlightPlanService>(context, listen: false)
        .currentFlightPlan;
    if (flightPlan == null || flightPlan.waypoints.isEmpty) {
      return '--';
    }

    // For now, just return the first waypoint name
    // In a full implementation, this would track the current waypoint
    final waypointName = flightPlan.waypoints.first.name ?? '--';
    return waypointName.length > 6
        ? waypointName.substring(0, 6)
        : waypointName;
  }

  String _buildTotalFlightETA(FlightService flightService, BuildContext context) {
    final flightPlan = Provider.of<FlightPlanService>(context, listen: false)
        .currentFlightPlan;
    if (flightPlan == null || flightService.currentSpeed <= 0) {
      return '--:--';
    }

    // Calculate remaining distance and time
    // This is a simplified calculation - in reality would need more complex logic
    final remainingDistance = flightPlan.totalDistance - flightService.totalDistance;
    if (remainingDistance <= 0) {
      return 'ARR';
    }

    final remainingTimeHours = remainingDistance / (flightService.currentSpeed * 3.6);
    final hours = remainingTimeHours.floor();
    final minutes = ((remainingTimeHours - hours) * 60).round();

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}