import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/flight_service.dart';
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    maxHeight: 200,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 12),
                      _buildMainIndicators(flightService, barometerService),
                      const SizedBox(height: 12),
                      _buildSecondaryIndicators(flightService, barometerService),
                      const SizedBox(height: 4), // Add a little extra space at the bottom
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

  Widget _buildHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'FLIGHT DATA',
          style: TextStyle(
            color: Colors.blueAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          'CAPTAIN VFR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildMainIndicators(FlightService flightService, BarometerService barometerService) {
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
          Icons.explore, // Will be replaced with rotating compass
        ),
      ],
    );
  }

  Widget _buildSecondaryIndicators(FlightService flightService, BarometerService barometerService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSmallIndicator(
          'TIME',
          flightService.formattedFlightTime,
          FlightIcons.time,
        ),
        _buildSmallIndicator(
          'DIST',
          '${(flightService.totalDistance / 1000).toStringAsFixed(1)} km',
          FlightIcons.distance,
        ),
        _buildSmallIndicator(
          'VERT SPD',
          '${flightService.verticalSpeed.toStringAsFixed(1)} m/s',
          FlightIcons.verticalSpeed,
        ),
        _buildSmallIndicator(
          'BARO',
          '${barometerService.pressureHPa?.toStringAsFixed(1) ?? '--'} hPa',
          FlightIcons.baro,
        ),
      ],
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
}
