import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/flight_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/barometer_service.dart';
import 'flight_dashboard/components/expanded_view.dart';
import 'flight_dashboard/components/collapsed_view.dart';

class FlightDashboard extends StatefulWidget {
  final bool? isExpanded;
  final Function(bool)? onExpandedChanged;

  const FlightDashboard({super.key, this.isExpanded, this.onExpandedChanged});

  @override
  State<FlightDashboard> createState() => _FlightDashboardState();
}

class _FlightDashboardState extends State<FlightDashboard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded ?? true;

    // Auto-select aircraft after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectAircraft();
    });
  }

  void _autoSelectAircraft() {
    final aircraftService = context.read<AircraftSettingsService>();
    final flightService = context.read<FlightService>();

    // Only auto-select if no aircraft is currently selected
    if (aircraftService.selectedAircraft == null &&
        aircraftService.aircrafts.isNotEmpty) {
      if (aircraftService.aircrafts.length == 1) {
        // Only one aircraft - auto-select it
        aircraftService.aircraftService.selectAircraft(
          aircraftService.aircrafts.first.id,
        );
        if (flightService.isTracking) {
          flightService.setAircraft(aircraftService.aircrafts.first);
        }
      } else if (aircraftService.aircrafts.length > 1) {
        // Multiple aircraft - try to select the last used one
        final flights = flightService.flights;
        if (flights.isNotEmpty) {
          // Since Flight model doesn't have aircraftId, we can't implement this yet
          // For now, just select the first aircraft
          aircraftService.aircraftService.selectAircraft(
            aircraftService.aircrafts.first.id,
          );
          if (flightService.isTracking) {
            flightService.setAircraft(aircraftService.aircrafts.first);
          }
        }
      }
    }
  }

  void _toggleExpanded(bool expanded) {
    setState(() {
      _isExpanded = expanded;
    });
    widget.onExpandedChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final flightService = Provider.of<FlightService>(context);
    final barometerService = Provider.of<BarometerService>(context);

    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    // Responsive margins and width
    final horizontalMargin = isPhone ? 8.0 : 16.0;
    final maxWidth = isPhone ? double.infinity : (isTablet ? 600.0 : 800.0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: 16.0,
      ),
      constraints: BoxConstraints(
        minHeight: _isExpanded ? 160 : 60,
        maxHeight: _isExpanded ? 260 : 60,
        minWidth: 300,
        maxWidth: maxWidth,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(_isExpanded ? 12.0 : 8.0),
          decoration: BoxDecoration(
            color: const Color(0xB3000000), // Black with 0.7 opacity
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: const Color(0x7F448AFF),
              width: 1.0,
            ), // Blue accent with 0.5 opacity
          ),
          child: _isExpanded
              ? ExpandedView(
                  onCollapse: () => _toggleExpanded(false),
                  flightService: flightService,
                  barometerService: barometerService,
                )
              : CollapsedView(
                  onExpand: () => _toggleExpanded(true),
                ),
        ),
      ),
    );
  }
}
