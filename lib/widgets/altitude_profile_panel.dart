import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';

class AltitudeProfilePanel extends StatefulWidget {
  const AltitudeProfilePanel({super.key});

  @override
  State<AltitudeProfilePanel> createState() => _AltitudeProfilePanelState();
}

class _AltitudeProfilePanelState extends State<AltitudeProfilePanel> {
  int? _selectedWaypointIndex;

  @override
  Widget build(BuildContext context) {
    return Consumer<FlightPlanService>(
      builder: (context, flightPlanService, child) {
        final flightPlan = flightPlanService.currentFlightPlan;

        if (flightPlan == null || flightPlan.waypoints.length < 2) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 200,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildAltitudeChart(flightPlan),
                ),
              ),
              if (_selectedWaypointIndex != null)
                _buildAltitudeEditor(flightPlanService, _selectedWaypointIndex!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, color: Colors.blue),
          const SizedBox(width: 8),
          const Text(
            'Altitude Profile',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          if (_selectedWaypointIndex != null)
            TextButton(
              onPressed: () => setState(() => _selectedWaypointIndex = null),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }

  Widget _buildAltitudeChart(FlightPlan flightPlan) {
    final waypoints = flightPlan.waypoints;
    final segments = flightPlan.segments;

    // Calculate cumulative distances for x-axis
    List<double> cumulativeDistances = [0];
    for (int i = 0; i < segments.length; i++) {
      cumulativeDistances.add(cumulativeDistances.last + segments[i].distance);
    }

    // Create chart spots
    List<FlSpot> spots = [];
    for (int i = 0; i < waypoints.length; i++) {
      spots.add(FlSpot(cumulativeDistances[i], waypoints[i].altitude));
    }

    // Find min/max altitudes for y-axis
    double minAlt = waypoints.map((w) => w.altitude).reduce((a, b) => a < b ? a : b);
    double maxAlt = waypoints.map((w) => w.altitude).reduce((a, b) => a > b ? a : b);

    // Add some padding to the altitude range
    double altRange = maxAlt - minAlt;
    if (altRange < 1000) altRange = 1000; // Minimum range of 1000 feet
    minAlt = (minAlt - altRange * 0.1).roundToDouble();
    maxAlt = (maxAlt + altRange * 0.1).roundToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 500,
          verticalInterval: flightPlan.totalDistance / 5,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
            axisNameWidget: const Text('Altitude (ft)', style: TextStyle(fontSize: 12)),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
            axisNameWidget: const Text('Distance (NM)', style: TextStyle(fontSize: 12)),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: flightPlan.totalDistance,
        minY: minAlt,
        maxY: maxAlt,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: _selectedWaypointIndex == index ? 8 : 5,
                  color: _selectedWaypointIndex == index ? Colors.red : Colors.blue,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
            if (event is FlTapUpEvent && touchResponse?.lineBarSpots != null) {
              final spot = touchResponse!.lineBarSpots!.first;
              setState(() {
                _selectedWaypointIndex = spot.spotIndex;
              });
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final waypoint = waypoints[barSpot.spotIndex];
                return LineTooltipItem(
                  '${waypoint.name ?? "WP${barSpot.spotIndex + 1}"}\n${barSpot.y.toInt()} ft',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAltitudeEditor(FlightPlanService flightPlanService, int waypointIndex) {
    final waypoint = flightPlanService.waypoints[waypointIndex];
    final TextEditingController altitudeController = TextEditingController(
      text: waypoint.altitude.toStringAsFixed(0),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
        color: Colors.grey,
      ),
      child: Row(
        children: [
          Text(
            '${waypoint.name ?? "Waypoint ${waypointIndex + 1}"}:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: TextField(
              controller: altitudeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Altitude',
                suffix: Text('ft'),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (value) {
                final altitude = double.tryParse(value);
                if (altitude != null && altitude >= 0) {
                  flightPlanService.updateWaypointAltitude(waypointIndex, altitude);
                  setState(() => _selectedWaypointIndex = null);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final altitude = double.tryParse(altitudeController.text);
              if (altitude != null && altitude >= 0) {
                flightPlanService.updateWaypointAltitude(waypointIndex, altitude);
                setState(() => _selectedWaypointIndex = null);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
