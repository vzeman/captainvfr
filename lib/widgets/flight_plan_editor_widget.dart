import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';
import 'waypoint_editor_dialog.dart';

class FlightPlanEditorWidget extends StatelessWidget {
  const FlightPlanEditorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FlightPlanService>(
      builder: (context, flightPlanService, child) {
        final flightPlan = flightPlanService.currentFlightPlan;

        if (flightPlan == null || flightPlan.waypoints.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No waypoints in flight plan. Tap on the map to add waypoints.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.flight_takeoff, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Flight Plan - ${flightPlan.waypoints.length} waypoints',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${flightPlan.totalDistance.toStringAsFixed(1)} NM',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: flightPlan.waypoints.length,
                  onReorder: (oldIndex, newIndex) {
                    flightPlanService.reorderWaypoints(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final waypoint = flightPlan.waypoints[index];

                    return WaypointListTile(
                      key: ValueKey(waypoint.id),
                      waypoint: waypoint,
                      index: index,
                      onTap: () => _editWaypoint(context, index, waypoint),
                      onDelete: () => _confirmDeleteWaypoint(context, index, waypoint),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editWaypoint(BuildContext context, int index, Waypoint waypoint) {
    showDialog(
      context: context,
      builder: (context) => WaypointEditorDialog(
        waypointIndex: index,
        waypoint: waypoint,
      ),
    );
  }

  void _confirmDeleteWaypoint(BuildContext context, int index, Waypoint waypoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Waypoint'),
        content: Text(
          'Are you sure you want to delete waypoint "${waypoint.name ?? 'WP${index + 1}'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<FlightPlanService>(context, listen: false)
                  .removeWaypoint(index);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class WaypointListTile extends StatelessWidget {
  final Waypoint waypoint;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const WaypointListTile({
    super.key,
    required this.waypoint,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getWaypointColor(waypoint.type),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          waypoint.name ?? 'WP${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${waypoint.latitude.toStringAsFixed(4)}, ${waypoint.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${waypoint.altitude.toStringAsFixed(0)} ft MSL',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
            if (waypoint.notes != null && waypoint.notes!.isNotEmpty)
              Text(
                waypoint.notes!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getWaypointColor(waypoint.type).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _getWaypointColor(waypoint.type)),
              ),
              child: Text(
                _getWaypointTypeText(waypoint.type),
                style: TextStyle(
                  color: _getWaypointColor(waypoint.type),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Color _getWaypointColor(WaypointType type) {
    switch (type) {
      case WaypointType.airport:
        return Colors.green;
      case WaypointType.navaid:
        return Colors.purple;
      case WaypointType.fix:
        return Colors.orange;
      case WaypointType.user:
      return Colors.blue;
    }
  }

  String _getWaypointTypeText(WaypointType type) {
    switch (type) {
      case WaypointType.airport:
        return 'APT';
      case WaypointType.navaid:
        return 'NAV';
      case WaypointType.fix:
        return 'FIX';
      case WaypointType.user:
      return 'USR';
    }
  }
}
