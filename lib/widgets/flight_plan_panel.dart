import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => flightPlanService.togglePlanningMode(),
              icon: Icon(flightPlanService.isPlanning ? Icons.stop : Icons.add_location),
              label: Text(flightPlanService.isPlanning ? 'Stop Planning' : 'Plan Flight'),
              style: ElevatedButton.styleFrom(
                backgroundColor: flightPlanService.isPlanning ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showClearConfirmation(context, flightPlanService),
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
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

  void _showClearConfirmation(BuildContext context, FlightPlanService flightPlanService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Flight Plan'),
        content: const Text('Are you sure you want to clear the current flight plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              flightPlanService.clearFlightPlan();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
