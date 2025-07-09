import 'package:flutter/material.dart';
import '../models/flight.dart';
import '../widgets/altitude_vertical_speed_chart.dart';
import '../widgets/speed_chart.dart';
import '../widgets/vibration_chart.dart';
import '../widgets/flight_detail/flight_detail_map.dart';
import '../widgets/flight_detail/flight_info_tab.dart';
import '../widgets/flight_detail/flight_segments_tab.dart';
import '../widgets/flight_detail/flight_detail_utils.dart';

class FlightDetailScreen extends StatefulWidget {
  final Flight flight;

  const FlightDetailScreen({super.key, required this.flight});

  @override
  State<FlightDetailScreen> createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  dynamic _selectedSegment; // Can be MovingSegment or FlightSegment

  void _onSegmentSelected(dynamic segment) {
    setState(() {
      _selectedSegment = segment;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasAltitudeData = widget.flight.altitudes.isNotEmpty &&
                          widget.flight.altitudes.any((alt) => alt > 0);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flight Details'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Info'),
              Tab(icon: Icon(Icons.timeline), text: 'Segments'),
              Tab(icon: Icon(Icons.speed), text: 'Speed'),
              Tab(icon: Icon(Icons.vibration), text: 'Turbulence'),
              Tab(icon: Icon(Icons.terrain), text: 'Altitude'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                FlightDetailUtils.shareFlightData(widget.flight);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Map View
            Expanded(
              flex: 3,
              child: FlightDetailMap(
                flight: widget.flight,
                selectedSegment: _selectedSegment,
                onSegmentSelected: _onSegmentSelected,
              ),
            ),
            // Tab Bar View
            Expanded(
              flex: 3,
              child: TabBarView(
                children: [
                  // Info Tab
                  FlightInfoTab(
                    flight: widget.flight,
                    selectedSegment: _selectedSegment,
                    onSegmentSelected: _onSegmentSelected,
                  ),

                  // Segments Tab
                  FlightSegmentsTab(
                    flight: widget.flight,
                    selectedSegment: _selectedSegment,
                    onSegmentSelected: _onSegmentSelected,
                  ),

                  // Speed Tab
                  _buildChartTab(
                    widget.flight.speeds.isNotEmpty
                        ? SpeedChart(
                            speedData: widget.flight.speeds,
                            currentSpeed: widget.flight.speeds.isNotEmpty
                                ? widget.flight.speeds.last
                                : null,
                            minSpeed: 0,
                            maxSpeed: widget.flight.speeds.isNotEmpty
                                ? widget.flight.speeds.reduce((a, b) => a > b ? a : b)
                                : null,
                          )
                        : null,
                    Icons.speed,
                    'No speed data available',
                  ),

                  // Turbulence Tab
                  _buildChartTab(
                    widget.flight.vibrationData.isNotEmpty
                        ? VibrationChart(
                            vibrationData: widget.flight.vibrationData,
                            currentVibration: widget.flight.vibrationData.isNotEmpty
                                ? widget.flight.vibrationData.last
                                : null,
                            maxVibration: widget.flight.vibrationData.isNotEmpty
                                ? widget.flight.vibrationData.reduce((a, b) => a > b ? a : b)
                                : null,
                          )
                        : null,
                    Icons.vibration,
                    'No turbulence data available',
                  ),

                  // Altitude Tab
                  _buildChartTab(
                    hasAltitudeData
                        ? AltitudeVerticalSpeedChart(
                            altitudeData: widget.flight.altitudes,
                            verticalSpeedData: widget.flight.verticalSpeeds,
                            currentAltitude: widget.flight.altitudes.isNotEmpty
                                ? widget.flight.altitudes.last
                                : null,
                            minAltitude: widget.flight.altitudes.isNotEmpty
                                ? widget.flight.altitudes.reduce((a, b) => a < b ? a : b) - 50
                                : null,
                            maxAltitude: widget.flight.altitudes.isNotEmpty
                                ? widget.flight.altitudes.reduce((a, b) => a > b ? a : b) + 50
                                : null,
                          )
                        : null,
                    Icons.terrain,
                    'No altitude data available',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTab(Widget? chart, IconData icon, String noDataMessage) {
    return chart ?? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            noDataMessage,
            style: TextStyle(
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}
