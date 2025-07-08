import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/flight_plan_service.dart';
import '../services/flight_service.dart';
import '../services/aircraft_settings_service.dart';
import '../models/flight.dart';
import '../services/barometer_service.dart';
import 'themed_dialog.dart';
import 'compass_widget.dart';

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
        minHeight: 160,
        maxHeight: 260,
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
                height: 90,
                child: _buildMainIndicators(context, flightService, barometerService),
              ),
              const SizedBox(height: 8),
              // Secondary indicators with fixed height
              SizedBox(
                height: 30,
                child: _buildSecondaryIndicators(context, flightService, barometerService),
              ),
              const SizedBox(height: 8),
              // Additional indicators with fixed height
              SizedBox(
                height: 30,
                child: _buildAdditionalIndicators(context, flightService, barometerService),
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
            'FLIGHT',
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
    ThemedDialog.show(
      context: context,
      title: 'Select Aircraft',
      content: SizedBox(
        width: double.maxFinite,
        child: aircraftService.aircrafts.isEmpty
            ? const Text(
                'No aircraft available. Please add an aircraft first.',
                style: TextStyle(color: Colors.white70),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: aircraftService.aircrafts.length,
                itemBuilder: (context, index) {
                  final aircraft = aircraftService.aircrafts[index];
                  final isSelected = aircraft.id == aircraftService.selectedAircraft?.id;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0x1A448AFF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0x7F448AFF) : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.flight,
                        color: isSelected ? const Color(0xFF448AFF) : Colors.white54,
                      ),
                      title: Text(
                        aircraft.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${aircraft.manufacturer} ${aircraft.model}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: Color(0xFF448AFF)) 
                          : null,
                      onTap: () {
                        // Select the aircraft by ID
                        aircraftService.aircraftService.selectAircraft(aircraft.id);
                        // Set aircraft in flight service
                        flightService.setAircraft(aircraft);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildMainIndicators(BuildContext context, FlightService flightService, BarometerService barometerService) {
    final flightPlanService = Provider.of<FlightPlanService>(context);
    final currentFlightPlan = flightPlanService.currentFlightPlan;
    
    // Calculate target heading if flight plan is active
    double? targetHeading;
    if (currentFlightPlan != null && currentFlightPlan.waypoints.length >= 2) {
      // For now, just show heading from first to second waypoint
      // In a real implementation, we'd track the active segment
      final firstWaypoint = currentFlightPlan.waypoints[0];
      final secondWaypoint = currentFlightPlan.waypoints[1];
      
      // Calculate bearing between waypoints
      final distance = Distance();
      targetHeading = distance.bearing(
        LatLng(firstWaypoint.latitude, firstWaypoint.longitude),
        LatLng(secondWaypoint.latitude, secondWaypoint.longitude),
      );
      // Convert from [-180, 180] to [0, 360]
      if (targetHeading < 0) targetHeading += 360;
    }
    
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
            '${flightService.verticalSpeed.toStringAsFixed(0)} fpm',
            FlightIcons.verticalSpeed,
          ),
        ),
        Expanded(
          child: _buildSmallIndicator(
            'G',
            '${flightService.currentGForce.toStringAsFixed(2)}g',
            Icons.speed,
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

  Widget _buildAdditionalIndicators(BuildContext context, FlightService flightService, BarometerService barometerService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _buildSmallIndicator(
            'PRESS',
            '${flightService.currentPressure.toStringAsFixed(0)} hPa',
            Icons.compress,
          ),
        ),
        Expanded(
          child: _buildSmallIndicator(
            'FUEL',
            '${flightService.fuelUsed.toStringAsFixed(1)} gal',
            Icons.local_gas_station,
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
