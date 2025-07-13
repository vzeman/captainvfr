import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';

class FloatingWaypointPanel extends StatefulWidget {
  final int waypointIndex;
  final VoidCallback onClose;

  const FloatingWaypointPanel({
    super.key,
    required this.waypointIndex,
    required this.onClose,
  });

  @override
  State<FloatingWaypointPanel> createState() => _FloatingWaypointPanelState();
}

class _FloatingWaypointPanelState extends State<FloatingWaypointPanel> {
  late TextEditingController _nameController;
  late TextEditingController _altitudeController;
  late TextEditingController _notesController;
  Offset _panelPosition = const Offset(20, 100);
  bool _isDragging = false;
  Size? _lastScreenSize;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _altitudeController = TextEditingController();
    _notesController = TextEditingController();
    _loadWaypointData();
  }

  void _loadWaypointData() {
    final flightPlanService = Provider.of<FlightPlanService>(
      context,
      listen: false,
    );
    final flightPlan = flightPlanService.currentFlightPlan;
    if (flightPlan != null &&
        widget.waypointIndex >= 0 &&
        widget.waypointIndex < flightPlan.waypoints.length) {
      final waypoint = flightPlan.waypoints[widget.waypointIndex];
      _nameController.text = waypoint.name ?? '';
      _altitudeController.text = waypoint.altitude.toStringAsFixed(0);
      _notesController.text = waypoint.notes ?? '';
    }
  }

  void _adjustPositionForScreenSize(Size newScreenSize) {
    if (_lastScreenSize != null && 
        (_lastScreenSize!.width != newScreenSize.width || 
         _lastScreenSize!.height != newScreenSize.height)) {
      
      // Calculate relative position as percentages
      final relativeX = _panelPosition.dx / _lastScreenSize!.width;
      final relativeY = _panelPosition.dy / _lastScreenSize!.height;
      
      // Determine panel width based on orientation
      final panelWidth = newScreenSize.width > newScreenSize.height ? 350.0 : 300.0;
      
      // Apply to new screen size and ensure panel stays visible
      final newX = (relativeX * newScreenSize.width).clamp(0.0, newScreenSize.width - panelWidth);
      final newY = (relativeY * newScreenSize.height).clamp(0.0, newScreenSize.height - 400);
      
      final newPosition = Offset(newX, newY);
      
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _panelPosition = newPosition;
          });
        }
      });
    }
    _lastScreenSize = newScreenSize;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _altitudeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateWaypointName(String value) {
    final flightPlanService = Provider.of<FlightPlanService>(
      context,
      listen: false,
    );
    flightPlanService.updateWaypointName(
      widget.waypointIndex,
      value.isEmpty ? null : value,
    );
  }

  void _updateWaypointAltitude(String value) {
    final altitude = double.tryParse(value);
    if (altitude != null) {
      final flightPlanService = Provider.of<FlightPlanService>(
        context,
        listen: false,
      );
      flightPlanService.updateWaypointAltitudeWithValidation(
        widget.waypointIndex,
        altitude,
      );
    }
  }

  void _updateWaypointNotes(String value) {
    final flightPlanService = Provider.of<FlightPlanService>(
      context,
      listen: false,
    );
    flightPlanService.updateWaypointNotes(
      widget.waypointIndex,
      value.isEmpty ? null : value,
    );
  }

  String _getWaypointTypeString(WaypointType type) {
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

  Color _getWaypointColor(WaypointType type) {
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

  @override
  Widget build(BuildContext context) {
    return Consumer<FlightPlanService>(
      builder: (context, flightPlanService, child) {
        final flightPlan = flightPlanService.currentFlightPlan;
        if (flightPlan == null ||
            widget.waypointIndex < 0 ||
            widget.waypointIndex >= flightPlan.waypoints.length) {
          return const SizedBox.shrink();
        }

        final waypoint = flightPlan.waypoints[widget.waypointIndex];
        final screenSize = MediaQuery.of(context).size;
        
        // Adjust position if screen size changed (orientation change)
        _adjustPositionForScreenSize(screenSize);

        return Positioned(
          left: _panelPosition.dx,
          top: _panelPosition.dy,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanUpdate: (details) {
              if (_isDragging) {
                final panelWidth = screenSize.width > screenSize.height ? 350.0 : 300.0;
                setState(() {
                  _panelPosition = Offset(
                    (_panelPosition.dx + details.delta.dx).clamp(
                      0,
                      screenSize.width - panelWidth,
                    ),
                    (_panelPosition.dy + details.delta.dy).clamp(
                      0,
                      screenSize.height - 400,
                    ),
                  );
                });
              }
            },
            onPanEnd: (_) => setState(() => _isDragging = false),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: screenSize.width > screenSize.height ? 350 : 300, // Larger in landscape
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getWaypointColor(
                      waypoint.type,
                    ).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with drag handle
                    Container(
                      decoration: BoxDecoration(
                        color: _getWaypointColor(
                          waypoint.type,
                        ).withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.drag_handle,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Waypoint ${widget.waypointIndex + 1} - ${_getWaypointTypeString(waypoint.type)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getWaypointColor(waypoint.type),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: widget.onClose,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name field
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              hintText: 'Enter waypoint name',
                              prefixIcon: Icon(Icons.label, size: 20),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onChanged: _updateWaypointName,
                          ),
                          const SizedBox(height: 12),

                          // Coordinates (read-only)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 20,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${waypoint.latitude.toStringAsFixed(6)}, ${waypoint.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Altitude field
                          TextField(
                            controller: _altitudeController,
                            decoration: const InputDecoration(
                              labelText: 'Altitude (ft)',
                              hintText: 'Enter altitude',
                              prefixIcon: Icon(Icons.flight, size: 20),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: _updateWaypointAltitude,
                          ),
                          const SizedBox(height: 12),

                          // Notes field
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              hintText: 'Add notes about this waypoint',
                              prefixIcon: Icon(Icons.note, size: 20),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            maxLines: 2,
                            onChanged: _updateWaypointNotes,
                          ),

                          // Segment info if not the last waypoint
                          if (widget.waypointIndex <
                              flightPlan.waypoints.length - 1) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              'To Next Waypoint',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSegmentInfo(
                                  Icons.straighten,
                                  '${waypoint.distanceTo(flightPlan.waypoints[widget.waypointIndex + 1]).toStringAsFixed(1)} NM',
                                  'Distance',
                                ),
                                _buildSegmentInfo(
                                  Icons.navigation,
                                  '${waypoint.bearingTo(flightPlan.waypoints[widget.waypointIndex + 1]).toStringAsFixed(0)}°',
                                  'Bearing',
                                ),
                                if (flightPlan.segments.length >
                                    widget.waypointIndex)
                                  _buildSegmentInfo(
                                    Icons.timer,
                                    '${flightPlan.segments[widget.waypointIndex].flightTime.toStringAsFixed(0)} min',
                                    'Time',
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmentInfo(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
