import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';

class WaypointEditorDialog extends StatefulWidget {
  final int waypointIndex;
  final Waypoint waypoint;

  const WaypointEditorDialog({
    super.key,
    required this.waypointIndex,
    required this.waypoint,
  });

  @override
  State<WaypointEditorDialog> createState() => _WaypointEditorDialogState();
}

class _WaypointEditorDialogState extends State<WaypointEditorDialog> {
  late TextEditingController _altitudeController;
  late TextEditingController _nameController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _altitudeController = TextEditingController(
      text: widget.waypoint.altitude.toStringAsFixed(0),
    );
    _nameController = TextEditingController(
      text: widget.waypoint.name ?? '',
    );
    _notesController = TextEditingController(
      text: widget.waypoint.notes ?? '',
    );
  }

  @override
  void dispose() {
    _altitudeController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final flightPlanService = Provider.of<FlightPlanService>(context, listen: false);

    // Update altitude
    final altitude = double.tryParse(_altitudeController.text) ?? widget.waypoint.altitude;
    flightPlanService.updateWaypointAltitude(widget.waypointIndex, altitude);

    // Update name and notes using the new service methods
    flightPlanService.updateWaypointName(
      widget.waypointIndex,
      _nameController.text.isNotEmpty ? _nameController.text : null
    );
    flightPlanService.updateWaypointNotes(
      widget.waypointIndex,
      _notesController.text.isNotEmpty ? _notesController.text : null
    );

    Navigator.of(context).pop();
  }

  void _deleteWaypoint() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Waypoint'),
          content: Text('Are you sure you want to delete waypoint "${widget.waypoint.name ?? 'WP${widget.waypointIndex + 1}'}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final flightPlanService = Provider.of<FlightPlanService>(context, listen: false);
                flightPlanService.removeWaypoint(widget.waypointIndex);
                Navigator.of(context).pop(); // Close confirmation dialog
                Navigator.of(context).pop(); // Close editor dialog
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Waypoint ${widget.waypointIndex + 1}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Waypoint coordinates (read-only)
            Text(
              'Position: ${widget.waypoint.latitude.toStringAsFixed(6)}, ${widget.waypoint.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter waypoint name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Altitude field
            TextField(
              controller: _altitudeController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Altitude (ft MSL)',
                hintText: 'Enter altitude in feet',
                border: OutlineInputBorder(),
                suffixText: 'ft',
              ),
            ),
            const SizedBox(height: 16),

            // Notes field
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Enter waypoint notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Waypoint type indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getWaypointTypeColor(widget.waypoint.type).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _getWaypointTypeColor(widget.waypoint.type)),
              ),
              child: Text(
                'Type: ${_getWaypointTypeText(widget.waypoint.type)}',
                style: TextStyle(
                  color: _getWaypointTypeColor(widget.waypoint.type),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleteWaypoint,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Color _getWaypointTypeColor(WaypointType type) {
    switch (type) {
      case WaypointType.airport:
        return Colors.green;
      case WaypointType.navaid:
        return Colors.purple;
      case WaypointType.fix:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _getWaypointTypeText(WaypointType type) {
    switch (type) {
      case WaypointType.airport:
        return 'Airport';
      case WaypointType.navaid:
        return 'Navaid';
      case WaypointType.fix:
        return 'Fix';
      default:
        return 'User Waypoint';
    }
  }
}
