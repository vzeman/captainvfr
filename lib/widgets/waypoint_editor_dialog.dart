import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';
import '../services/settings_service.dart';
import '../utils/form_theme_helper.dart';

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
    // Altitude will be set in build method based on unit settings
    _altitudeController = TextEditingController();
    _nameController = TextEditingController(text: widget.waypoint.name ?? '');
    _notesController = TextEditingController(text: widget.waypoint.notes ?? '');
  }

  @override
  void dispose() {
    _altitudeController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final flightPlanService = Provider.of<FlightPlanService>(
      context,
      listen: false,
    );
    final settingsService = Provider.of<SettingsService>(
      context,
      listen: false,
    );
    final isMetric = settingsService.units == 'metric';

    // Update altitude - convert back to feet if metric
    var altitude =
        double.tryParse(_altitudeController.text) ?? widget.waypoint.altitude;
    if (isMetric) {
      altitude = altitude / 0.3048; // Convert meters to feet for storage
    }
    flightPlanService.updateWaypointAltitude(widget.waypointIndex, altitude);

    // Update name and notes using the new service methods
    flightPlanService.updateWaypointName(
      widget.waypointIndex,
      _nameController.text.isNotEmpty ? _nameController.text : null,
    );
    flightPlanService.updateWaypointNotes(
      widget.waypointIndex,
      _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    Navigator.of(context).pop();
  }

  void _deleteWaypoint() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FormThemeHelper.buildDialog(
          context: context,
          title: 'Delete Waypoint',
          content: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Are you sure you want to delete waypoint "${widget.waypoint.name ?? 'WP${widget.waypointIndex + 1}'}"?',
              style: TextStyle(color: FormThemeHelper.primaryTextColor),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FormThemeHelper.getSecondaryButtonStyle(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final flightPlanService = Provider.of<FlightPlanService>(
                  context,
                  listen: false,
                );
                flightPlanService.removeWaypoint(widget.waypointIndex);
                Navigator.of(context).pop(); // Close confirmation dialog
                Navigator.of(context).pop(); // Close editor dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';

        // Set altitude text based on unit settings
        if (_altitudeController.text.isEmpty) {
          final displayAltitude = isMetric
              ? widget.waypoint.altitude *
                    0.3048 // Convert to meters
              : widget.waypoint.altitude;
          _altitudeController.text = displayAltitude.toStringAsFixed(0);
        }

        return FormThemeHelper.buildDialog(
          context: context,
          title: 'Edit Waypoint ${widget.waypointIndex + 1}',
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waypoint coordinates (read-only)
                Text(
                  'Position: ${widget.waypoint.latitude.toStringAsFixed(6)}, ${widget.waypoint.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: FormThemeHelper.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Name field
                FormThemeHelper.buildFormField(
                  controller: _nameController,
                  labelText: 'Name',
                  hintText: 'Enter waypoint name',
                ),
                const SizedBox(height: 16),

                // Altitude field
                TextFormField(
                  controller: _altitudeController,
                  style: FormThemeHelper.inputTextStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,1}'),
                    ),
                  ],
                  decoration: FormThemeHelper.getInputDecoration(
                    isMetric
                        ? 'Altitude (m MSL)'
                        : 'Altitude (ft MSL)',
                    hintText: isMetric
                        ? 'Enter altitude in meters'
                        : 'Enter altitude in feet',
                  ).copyWith(
                    suffixText: isMetric ? 'm' : 'ft',
                    suffixStyle: TextStyle(color: FormThemeHelper.secondaryTextColor),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes field
                FormThemeHelper.buildFormField(
                  controller: _notesController,
                  labelText: 'Notes',
                  hintText: 'Enter waypoint notes',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Waypoint type indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getWaypointTypeColor(
                      widget.waypoint.type,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getWaypointTypeColor(widget.waypoint.type),
                    ),
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
              style: FormThemeHelper.getSecondaryButtonStyle(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _saveChanges,
              style: FormThemeHelper.getPrimaryButtonStyle(),
              child: const Text('Save'),
            ),
          ],
        );
      },
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