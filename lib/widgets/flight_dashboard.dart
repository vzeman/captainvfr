
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/flight_plan_service.dart';
import '../services/flight_service.dart';
import '../services/aircraft_settings_service.dart';
import '../models/flight.dart';
import '../services/barometer_service.dart';

// Custom icons for the flight dashboard
class FlightIcons {
  // Compass icon that can be rotated
  static Widget compass(double? heading, {double size = 24}) {
    return Transform.rotate(
      angle: (heading ?? 0) * (pi / 180) * -1,
      child: Icon(Icons.explore, size: size, color: Colors.blueAccent),
    );
  }
  
  // Altitude icon
  static const IconData altitude = Icons.terrain;
  
  // Speed icon
  static const IconData speed = Icons.speed;
  
  // Time icon
  static const IconData time = Icons.timer;
  
  // Distance icon
  static const IconData distance = Icons.terrain;
  
  // Vertical speed icon
  static const IconData verticalSpeed = Icons.linear_scale;
  
  // Baro icon
  static const IconData baro = Icons.speed;
}

class FlightDashboard extends StatelessWidget {
  const FlightDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final flightService = Provider.of<FlightService>(context);
    final barometerService = Provider.of<BarometerService>(context);
    
    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: const Color(0xB3000000), // Black with 0.7 opacity
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: const Color(0x7F448AFF), width: 1.0), // Blue accent with 0.5 opacity
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, flightService),
                      const SizedBox(height: 8),
                      Flexible(
                        child: _buildMainIndicators(context, flightService, barometerService),
                      ),
                      const SizedBox(height: 6),
                      _buildSecondaryIndicators(context, flightService, barometerService),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FlightService flightService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Compact aircraft selection at top-left
        _buildCompactAircraftSelector(context, flightService),
        const Text(
          'FLIGHT DATA',
          style: TextStyle(
            color: Colors.blueAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        // Larger tracking button for better visibility
        IconButton(
          icon: Icon(
            flightService.isTracking ? Icons.stop : Icons.play_arrow,
            color: flightService.isTracking ? Colors.red : Colors.green,
            size: 28,
          ),
          onPressed: () {
            if (flightService.isTracking) {
              flightService.stopTracking();
            } else {
              flightService.startTracking();
            }
          },
          tooltip: flightService.isTracking ? 'Stop Tracking' : 'Start Tracking',
        ),
      ],
    );
  }

  Widget _buildCompactAircraftSelector(BuildContext context, FlightService flightService) {
    return Consumer<AircraftSettingsService>(
      builder: (context, aircraftService, child) {
        final selectedAircraft = aircraftService.selectedAircraft;

        return InkWell(
          onTap: () => _showAircraftSelectionDialog(context, aircraftService, flightService),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight, color: Colors.blueAccent, size: 14),
                const SizedBox(width: 4),
                Text(
                  selectedAircraft?.name ?? 'Select',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, color: Colors.blueAccent, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAircraftSelectionDialog(BuildContext context, AircraftSettingsService aircraftService, FlightService flightService) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Aircraft'),
          content: SizedBox(
            width: double.maxFinite,
            child: aircraftService.aircrafts.isEmpty
                ? const Text('No aircraft available. Please add an aircraft first.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: aircraftService.aircrafts.length,
                    itemBuilder: (context, index) {
                      final aircraft = aircraftService.aircrafts[index];
                      final isSelected = aircraft.id == aircraftService.selectedAircraft?.id;

                      return ListTile(
                        leading: Icon(
                          Icons.flight,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        title: Text(aircraft.name),
                        subtitle: Text('${aircraft.manufacturer} ${aircraft.model}'),
                        trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                        selected: isSelected,
                        onTap: () {
                          // Select the aircraft by ID
                          aircraftService.aircraftService.selectAircraft(aircraft.id);
                          // Set aircraft in flight service
                          flightService.setAircraft(aircraft);
                          Navigator.of(dialogContext).pop();
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainIndicators(BuildContext context, FlightService flightService, BarometerService barometerService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildIndicator(
          'ALTITUDE',
          (flightService.barometricAltitude ?? 0).toStringAsFixed(0),
          'm',
          FlightIcons.altitude,
        ),
        _buildIndicator(
          'SPEED',
          (flightService.currentSpeed * 1.94384).toStringAsFixed(0), // Convert m/s to knots
          'kt',
          FlightIcons.speed,
        ),
        _buildIndicator(
          'HEADING',
          flightService.currentHeading?.toStringAsFixed(0) ?? '---',
          '°',
          Icons.explore,
        ),
      ],
    );
  }

  Widget _buildSecondaryIndicators(BuildContext context, FlightService flightService, BarometerService barometerService) {
    // Reduce the number of indicators when space is tight
    final hasFlightPlan = Provider.of<FlightPlanService>(context, listen: false).currentFlightPlan != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSmallIndicator(
            'TIME',
            flightService.formattedFlightTime,
            FlightIcons.time,
          ),
          const SizedBox(width: 8),
          _buildSmallIndicator(
            'DIST',
            '${(flightService.totalDistance / 1000).toStringAsFixed(1)} km',
            FlightIcons.distance,
          ),
          const SizedBox(width: 8),
          _buildSmallIndicator(
            'V/SPD',
            '${flightService.verticalSpeed.toStringAsFixed(1)}',
            FlightIcons.verticalSpeed,
          ),
          const SizedBox(width: 8),
          _buildSmallIndicator(
            'FUEL',
            '${flightService.fuelUsed.toStringAsFixed(1)}',
            Icons.local_gas_station,
          ),
          if (hasFlightPlan) ...[
            const SizedBox(width: 8),
            _buildSmallIndicator(
              'NEXT',
              _buildNextWaypointInfo(flightService, context),
              Icons.flag,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndicator(String label, String value, String unit, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                unit,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallIndicator(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 12),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// Compute distance/time to next waypoint if a plan is loaded
  String _buildNextWaypointInfo(FlightService flightService, BuildContext context) {
    final planSvc = Provider.of<FlightPlanService>(context, listen: false);
    final plan = planSvc.currentFlightPlan;
    if (plan == null || flightService.flightPath.isEmpty) return '--';
    final currentPos = flightService.flightPath.last.toLatLng();
    final wp = plan.waypoints.first;
    final dest = LatLng(wp.latitude, wp.longitude);
    final meterDist = const Distance().as(LengthUnit.Meter, currentPos, dest);
    final km = meterDist / 1000;
    final speedKmh = flightService.currentSpeed * 3.6;
    final etaMin = speedKmh > 0 ? (km / speedKmh) * 60 : 0;
    return '${km.toStringAsFixed(1)} km / ${etaMin.toStringAsFixed(0)} min';
  }
}
