import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';
import '../services/settings_service.dart';

class FloatingWaypointPanel extends StatefulWidget {
  final int waypointIndex;
  final VoidCallback onClose;
  final bool isEditMode;

  const FloatingWaypointPanel({
    super.key,
    required this.waypointIndex,
    required this.onClose,
    this.isEditMode = false,
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
            child: Container(
              width: screenSize.width > screenSize.height ? 320 : 280,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: _getWaypointColor(waypoint.type).withValues(alpha: 0.5),
                ),
              ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'WAYPOINT ${widget.waypointIndex + 1}',
                            style: TextStyle(
                              color: _getWaypointColor(waypoint.type),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onClose,
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white70,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Type and name
                          Row(
                            children: [
                              Icon(
                                _getWaypointIcon(waypoint.type),
                                size: 12,
                                color: _getWaypointColor(waypoint.type),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${waypoint.name ?? "Waypoint"} (${_getWaypointTypeString(waypoint.type)})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Coordinates
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 12,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${waypoint.latitude.toStringAsFixed(6)}, ${waypoint.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Altitude
                          Row(
                            children: [
                              const Icon(
                                Icons.flight,
                                size: 12,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Consumer<SettingsService>(
                                builder: (context, settings, child) {
                                  final isMetric = settings.units == 'metric';
                                  final altitude = isMetric ? waypoint.altitude * 0.3048 : waypoint.altitude;
                                  final unit = isMetric ? 'm' : 'ft';
                                  return Text(
                                    'Altitude: ${altitude.toStringAsFixed(0)} $unit',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          
                          // Notes if present
                          if (waypoint.notes != null && waypoint.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.note,
                                  size: 12,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    waypoint.notes!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Segment info if not the last waypoint
                          if (widget.waypointIndex <
                              flightPlan.waypoints.length - 1) ...[
                            const Divider(color: Colors.grey, height: 8),
                            const Text(
                              'TO NEXT WAYPOINT',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Consumer<SettingsService>(
                              builder: (context, settings, child) {
                                final isMetric = settings.units == 'metric';
                                final distance = waypoint.distanceTo(flightPlan.waypoints[widget.waypointIndex + 1]);
                                final displayDistance = isMetric ? distance * 1.852 : distance;
                                final unit = isMetric ? 'km' : 'nm';
                                return Row(
                                  children: [
                                    const Icon(Icons.straighten, size: 12, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${displayDistance.toStringAsFixed(1)} $unit',
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.navigation, size: 12, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${waypoint.bearingTo(flightPlan.waypoints[widget.waypointIndex + 1]).toStringAsFixed(0)}°',
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                    if (flightPlan.segments.length > widget.waypointIndex) ...[
                                      const SizedBox(width: 12),
                                      const Icon(Icons.timer, size: 12, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${flightPlan.segments[widget.waypointIndex].flightTime.toStringAsFixed(0)} min',
                                        style: const TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        );
      },
    );
  }

  IconData _getWaypointIcon(WaypointType type) {
    switch (type) {
      case WaypointType.airport:
        return Icons.local_airport;
      case WaypointType.navaid:
        return Icons.radio;
      case WaypointType.fix:
        return Icons.place;
      default:
        return Icons.location_pin;
    }
  }
}
