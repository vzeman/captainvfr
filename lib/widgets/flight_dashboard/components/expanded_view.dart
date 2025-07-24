import 'package:flutter/material.dart';
import '../../../services/flight_service.dart';
import '../../../services/barometer_service.dart';
import 'dashboard_header.dart';
import 'main_indicators.dart';
import 'secondary_indicators.dart';
import 'additional_indicators.dart';

/// Expanded view of the flight dashboard showing all flight information
class ExpandedView extends StatelessWidget {
  final VoidCallback onCollapse;
  final FlightService flightService;
  final BarometerService barometerService;

  const ExpandedView({
    super.key,
    required this.onCollapse,
    required this.flightService,
    required this.barometerService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with fixed height
        SizedBox(
          height: 40,
          child: DashboardHeader(
            onCollapse: onCollapse,
            flightService: flightService,
          ),
        ),
        const SizedBox(height: 8),
        // Main indicators with fixed height
        SizedBox(
          height: 90,
          child: MainIndicators(
            flightService: flightService,
            barometerService: barometerService,
          ),
        ),
        const SizedBox(height: 8),
        // Secondary indicators
        SecondaryIndicators(
          flightService: flightService,
          barometerService: barometerService,
        ),
        const SizedBox(height: 8),
        // Additional indicators
        AdditionalIndicators(
          flightService: flightService,
          barometerService: barometerService,
        ),
      ],
    );
  }
}