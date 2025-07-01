import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';

class FlightPlanPanel extends StatefulWidget {
  const FlightPlanPanel({super.key});

  @override
  State<FlightPlanPanel> createState() => _FlightPlanPanelState();
}

class _FlightPlanPanelState extends State<FlightPlanPanel> {
  final TextEditingController _cruiseSpeedController = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _cruiseSpeedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FlightPlanService>(
      builder: (context, flightPlanService, child) {
        final flightPlan = flightPlanService.currentFlightPlan;
        final isPlanning = flightPlanService.isPlanning;

        if (flightPlan == null && !isPlanning) {
          return const SizedBox.shrink();
        }

        return Container(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(flightPlanService),
              if (_isExpanded) _buildExpandedContent(flightPlanService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(FlightPlanService flightPlanService) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              flightPlanService.isPlanning ? Icons.flight_takeoff : Icons.map,
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flightPlanService.currentFlightPlan?.name ?? 'Flight Planning',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    flightPlanService.getFlightPlanSummary(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(FlightPlanService flightPlanService) {
    final flightPlan = flightPlanService.currentFlightPlan;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Column(
        children: [
          _buildCruiseSpeedInput(flightPlanService),
          if (flightPlan != null && flightPlan.waypoints.isNotEmpty)
            _buildWaypointsList(flightPlanService),
          // Add altitude profile chart here
          if (flightPlan != null && flightPlan.waypoints.length >= 2)
            _buildAltitudeProfileChart(flightPlanService),
          _buildActionButtons(flightPlanService),
        ],
      ),
    );
  }

  Widget _buildCruiseSpeedInput(FlightPlanService flightPlanService) {
    final cruiseSpeed = flightPlanService.currentFlightPlan?.cruiseSpeed;

    if (_cruiseSpeedController.text.isEmpty && cruiseSpeed != null) {
      _cruiseSpeedController.text = cruiseSpeed.toStringAsFixed(0);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.speed, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Cruise Speed:'),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _cruiseSpeedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '120',
                suffix: Text('kts'),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onChanged: (value) {
                final speed = double.tryParse(value);
                if (speed != null && speed > 0) {
                  flightPlanService.updateCruiseSpeed(speed);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointsList(FlightPlanService flightPlanService) {
    final waypoints = flightPlanService.waypoints;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: waypoints.length,
        itemBuilder: (context, index) {
          final waypoint = waypoints[index];
          final isLast = index == waypoints.length - 1;

          return _buildWaypointItem(
            flightPlanService,
            waypoint,
            index,
            isLast,
          );
        },
      ),
    );
  }

  Widget _buildWaypointItem(
    FlightPlanService flightPlanService,
    Waypoint waypoint,
    int index,
    bool isLast,
  ) {
    final segments = flightPlanService.currentFlightPlan?.segments ?? [];
    final segment = index < segments.length ? segments[index] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Waypoint number and line
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 20,
                    color: Colors.blue,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Waypoint info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      waypoint.name ?? 'Waypoint ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${waypoint.altitude.toStringAsFixed(0)} ft',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (segment != null && !isLast) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${segment.distance.toStringAsFixed(1)} NM',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${segment.bearing.toStringAsFixed(0)}°',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                      if (segment.flightTime > 0) ...[
                        const SizedBox(width: 16),
                        Text(
                          '${segment.flightTime.toStringAsFixed(0)} min',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete, size: 18),
            onPressed: () => _showDeleteConfirmation(context, flightPlanService, index),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(FlightPlanService flightPlanService) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Primary action buttons row
          Row(
            children: [
              // Start new flight plan button
              if (flightPlanService.currentFlightPlan == null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => flightPlanService.startNewFlightPlan(),
                    icon: const Icon(Icons.add),
                    label: const Text('Start Planning'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              // Save flight plan button
              if (flightPlanService.currentFlightPlan != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showSaveDialog(context, flightPlanService),
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

              if (flightPlanService.currentFlightPlan != null) ...[
                const SizedBox(width: 8),
                // Clear flight plan button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showClearDialog(context, flightPlanService),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Toggle planning mode button
          if (flightPlanService.currentFlightPlan != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => flightPlanService.togglePlanningMode(),
                  icon: Icon(flightPlanService.isPlanning ? Icons.done : Icons.edit),
                  label: Text(flightPlanService.isPlanning ? 'Finish Planning' : 'Edit Plan'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSaveDialog(BuildContext context, FlightPlanService flightPlanService) {
    final controller = TextEditingController(
      text: flightPlanService.currentFlightPlan?.name ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Flight Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Flight Plan Name',
                hintText: 'Enter a name for your flight plan',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              'This will save your flight plan for future use.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await flightPlanService.saveCurrentFlightPlan(customName: name);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Flight plan "$name" saved!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, FlightPlanService flightPlanService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Flight Plan'),
        content: const Text('Are you sure you want to clear the current flight plan? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              flightPlanService.clearFlightPlan();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Flight plan cleared'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, FlightPlanService flightPlanService, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Waypoint'),
        content: const Text('Are you sure you want to delete this waypoint?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              flightPlanService.removeWaypoint(index);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildAltitudeProfileChart(FlightPlanService flightPlanService) {
    final waypoints = flightPlanService.waypoints;
    final segments = flightPlanService.currentFlightPlan?.segments ?? [];

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

    // Find min/max altitudes for chart scaling
    final altitudes = waypoints.map((w) => w.altitude).toList();
    final minAlt = altitudes.reduce((a, b) => a < b ? a : b);
    final maxAlt = altitudes.reduce((a, b) => a > b ? a : b);
    final altRange = maxAlt - minAlt;
    final padding = altRange * 0.1; // 10% padding

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Altitude Profile',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  'Drag points to adjust altitude',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: cumulativeDistances.last,
                minY: minAlt - padding,
                maxY: maxAlt + padding,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: Colors.blue,
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
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(0)} NM',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(0)} ft',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  horizontalInterval: altRange > 0 ? altRange / 4 : 1000, // Use 1000ft intervals when altRange is 0
                  verticalInterval: cumulativeDistances.last / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[400]!, width: 1),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    // Handle both tap and drag events for better interaction
                    if ((event is FlTapUpEvent || event is FlPanUpdateEvent || event is FlPanEndEvent) &&
                        touchResponse != null && touchResponse.lineBarSpots != null) {
                      final spot = touchResponse.lineBarSpots!.first;
                      final waypointIndex = _findWaypointIndexFromDistance(
                        cumulativeDistances,
                        spot.x,
                      );
                      if (waypointIndex != -1) {
                        // Convert chart Y coordinate to altitude, ensuring it's within reasonable bounds
                        final chartHeight = maxAlt + padding - (minAlt - padding);
                        final normalizedY = (spot.y - (minAlt - padding)) / chartHeight;
                        final targetAltitude = ((1 - normalizedY) * chartHeight + (minAlt - padding))
                            .clamp(0.0, 20000.0);

                        // Only update if the altitude actually changed significantly
                        final currentAltitude = waypoints[waypointIndex].altitude;
                        if ((targetAltitude - currentAltitude).abs() > 50) { // 50ft threshold
                          flightPlanService.updateWaypointAltitude(waypointIndex, targetAltitude);
                        }
                      }
                    }
                  },
                  touchSpotThreshold: 50, // Increase touch sensitivity
                  distanceCalculator: (Offset touchPoint, Offset spotPixelCoordinates) {
                    // Custom distance calculation for better touch detection
                    return (touchPoint - spotPixelCoordinates).distance;
                  },
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.blue.withOpacity(0.8),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final waypointIndex = _findWaypointIndexFromDistance(
                          cumulativeDistances,
                          barSpot.x,
                        );
                        final waypointName = waypointIndex != -1
                            ? waypoints[waypointIndex].name ?? 'WP${waypointIndex + 1}'
                            : 'Point';

                        return LineTooltipItem(
                          '$waypointName\n${barSpot.y.toStringAsFixed(0)} ft\n${barSpot.x.toStringAsFixed(1)} NM',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _findWaypointIndexFromDistance(List<double> distances, double targetDistance) {
    for (int i = 0; i < distances.length; i++) {
      if ((distances[i] - targetDistance).abs() < 0.5) { // 0.5 NM tolerance
        return i;
      }
    }
    return -1;
  }
}
