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
      constraints: const BoxConstraints(
        minHeight: 120,
        maxHeight: 200,
        minWidth: 300,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: const Color(0xB3000000), // Black with 0.7 opacity
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: const Color(0x7F448AFF), width: 1.0), // Blue accent with 0.5 opacity
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with fixed height
              SizedBox(
                height: 40,
                child: _buildHeader(context, flightService),
              ),
              const SizedBox(height: 8),
              // Main indicators with fixed height
              SizedBox(
                height: 60,
                child: _buildMainIndicators(context, flightService, barometerService),
              ),
              const SizedBox(height: 8),
              // Secondary indicators with fixed height
              SizedBox(
                height: 30,
                child: _buildSecondaryIndicators(context, flightService, barometerService),
              ),
            ],
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
        Flexible(
          flex: 2,
          child: _buildCompactAircraftSelector(context, flightService),
        ),
        const Flexible(
          flex: 3,
          child: Text(
            'FLIGHT DATA',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Larger tracking button for better visibility
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: Icon(
              flightService.isTracking ? Icons.stop : Icons.play_arrow,
              color: flightService.isTracking ? Colors.red : Colors.green,
              size: 24,
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight, color: Colors.blueAccent, size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    selectedAircraft?.name ?? 'Select',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.blueAccent, size: 14),
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _buildIndicator(
            'ALT',
            (flightService.barometricAltitude ?? 0).toStringAsFixed(0),
            'm',
            FlightIcons.altitude,
          ),
        ),
        Expanded(
          child: _buildIndicator(
            'SPEED',
            (flightService.currentSpeed * 1.94384).toStringAsFixed(0), // Convert m/s to knots
            'kt',
            FlightIcons.speed,
          ),
        ),
        Expanded(
          child: _buildIndicator(
            'HDG',
            flightService.currentHeading?.toStringAsFixed(0) ?? '---',
            '°',
            Icons.explore,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryIndicators(BuildContext context, FlightService flightService, BarometerService barometerService) {
    final hasFlightPlan = Provider.of<FlightPlanService>(context, listen: false).currentFlightPlan != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _buildSmallIndicator(
            'TIME',
            flightService.formattedFlightTime,
            FlightIcons.time,
          ),
        ),
        Expanded(
          child: _buildSmallIndicator(
            'DIST',
            '${(flightService.totalDistance / 1000).toStringAsFixed(1)}km',
            FlightIcons.distance,
          ),
        ),
        Expanded(
          child: _buildSmallIndicator(
            'V/S',
            flightService.verticalSpeed.toStringAsFixed(1),
            FlightIcons.verticalSpeed,
          ),
        ),
        Expanded(
          child: _buildSmallIndicator(
            'FUEL',
            flightService.fuelUsed.toStringAsFixed(1),
            Icons.local_gas_station,
          ),
        ),
        if (hasFlightPlan)
          Expanded(
            child: _buildSmallIndicator(
              'NEXT',
              _buildNextWaypointInfo(flightService, context),
              Icons.flag,
            ),
          ),
      ],
    );
  }

  Widget _buildIndicator(String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(icon, color: Colors.blueAccent, size: 14),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 1),
              Text(
                unit,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallIndicator(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.blueAccent, size: 8),
              const SizedBox(width: 1),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 7,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  /// Compute distance/time to next waypoint if a plan is loaded
  String _buildNextWaypointInfo(FlightService flightService, BuildContext context) {
    final planSvc = Provider.of<FlightPlanService>(context, listen: false);
    final plan = planSvc.currentFlightPlan;
    // Check for all required conditions: plan exists, has waypoints, and flight path has data
    if (plan == null || plan.waypoints.isEmpty || flightService.flightPath.isEmpty) {
      return '--';
    }

    try {
      final currentPos = flightService.flightPath.last.toLatLng();
      final wp = plan.waypoints.first;
      final dest = LatLng(wp.latitude, wp.longitude);
      final meterDist = const Distance().as(LengthUnit.Meter, currentPos, dest);
      final km = meterDist / 1000;
      final speedKmh = flightService.currentSpeed * 3.6;
      final etaMin = speedKmh > 0 ? (km / speedKmh) * 60 : 0;
      return '${km.toStringAsFixed(1)}km/${etaMin.toStringAsFixed(0)}min';
    } catch (e) {
      // Fallback in case of any unexpected errors
      return '--';
    }
  }
}
