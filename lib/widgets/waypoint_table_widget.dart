import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../models/aircraft.dart';
import '../services/flight_plan_service.dart';
import 'waypoint_editor_dialog.dart';

class WaypointTableWidget extends StatefulWidget {
  final FlightPlan? flightPlan;
  final Aircraft? selectedAircraft;
  final int? selectedWaypointIndex;
  final Function(int)? onWaypointSelected;

  const WaypointTableWidget({
    super.key,
    this.flightPlan,
    this.selectedAircraft,
    this.selectedWaypointIndex,
    this.onWaypointSelected,
  });

  @override
  State<WaypointTableWidget> createState() => _WaypointTableWidgetState();
}

class _WaypointTableWidgetState extends State<WaypointTableWidget> 
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Controllers for inline editing
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _altitudeControllers = {};
  final Map<String, FocusNode> _nameFocusNodes = {};
  final Map<String, FocusNode> _altitudeFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _altitudeControllers.values) {
      controller.dispose();
    }
    for (final node in _nameFocusNodes.values) {
      node.dispose();
    }
    for (final node in _altitudeFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  TextEditingController _getNameController(Waypoint waypoint) {
    if (!_nameControllers.containsKey(waypoint.id)) {
      _nameControllers[waypoint.id] = TextEditingController(
        text: waypoint.name ?? '',
      );
    }
    return _nameControllers[waypoint.id]!;
  }

  TextEditingController _getAltitudeController(Waypoint waypoint) {
    if (!_altitudeControllers.containsKey(waypoint.id)) {
      _altitudeControllers[waypoint.id] = TextEditingController(
        text: waypoint.altitude.toStringAsFixed(0),
      );
    }
    return _altitudeControllers[waypoint.id]!;
  }

  FocusNode _getNameFocusNode(String waypointId) {
    if (!_nameFocusNodes.containsKey(waypointId)) {
      _nameFocusNodes[waypointId] = FocusNode();
    }
    return _nameFocusNodes[waypointId]!;
  }

  FocusNode _getAltitudeFocusNode(String waypointId) {
    if (!_altitudeFocusNodes.containsKey(waypointId)) {
      _altitudeFocusNodes[waypointId] = FocusNode();
    }
    return _altitudeFocusNodes[waypointId]!;
  }

  void _updateWaypointName(int index, String name) {
    final flightPlanService = Provider.of<FlightPlanService>(
      context,
      listen: false,
    );
    flightPlanService.updateWaypointName(
      index,
      name.isNotEmpty ? name : null,
    );
  }

  void _updateWaypointAltitude(int index, String altitudeText) {
    final altitude = double.tryParse(altitudeText);
    if (altitude != null) {
      final flightPlanService = Provider.of<FlightPlanService>(
        context,
        listen: false,
      );
      flightPlanService.updateWaypointAltitude(index, altitude);
    }
  }

  String _formatDistance(double distance) {
    return distance.toStringAsFixed(1);
  }

  String _formatTime(double minutes) {
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)}m';
    } else {
      final hours = (minutes / 60).floor();
      final mins = (minutes % 60).round();
      return '${hours}h ${mins}m';
    }
  }

  String _formatFuel(double gallons) {
    return gallons.toStringAsFixed(1);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waypoints = widget.flightPlan?.waypoints ?? [];
    final cruiseSpeed = widget.flightPlan?.cruiseSpeed ?? 
                       widget.selectedAircraft?.cruiseSpeed.toDouble();
    final fuelConsumption = widget.selectedAircraft?.fuelConsumption;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: _isExpanded ? Radius.zero : Radius.circular(12),
                  bottomRight: _isExpanded ? Radius.zero : Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: _isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Waypoints (${waypoints.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (waypoints.isNotEmpty && cruiseSpeed != null)
                    Text(
                      'Total: ${_formatDistance(widget.flightPlan!.totalDistance)} nm, '
                      '${_formatTime(widget.flightPlan!.totalFlightTime)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          
          // Table Content
          SizeTransition(
            sizeFactor: _animation,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: waypoints.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No waypoints added yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) {
                        final flightPlanService = Provider.of<FlightPlanService>(
                          context,
                          listen: false,
                        );
                        flightPlanService.reorderWaypoints(oldIndex, newIndex);
                      },
                      itemCount: waypoints.length,
                      itemBuilder: (context, index) {
                        final waypoint = waypoints[index];
                        final isSelected = widget.selectedWaypointIndex == index;
                        
                        // Calculate segment data
                        double? distanceFromPrevious;
                        double? timeFromPrevious;
                        double? fuelFromPrevious;
                        
                        if (index > 0) {
                          distanceFromPrevious = waypoints[index - 1].distanceTo(waypoint);
                          if (cruiseSpeed != null && cruiseSpeed > 0) {
                            timeFromPrevious = (distanceFromPrevious / cruiseSpeed) * 60;
                            if (fuelConsumption != null && fuelConsumption > 0) {
                              fuelFromPrevious = (timeFromPrevious / 60) * fuelConsumption;
                            }
                          }
                        }
                        
                        return ReorderableDragStartListener(
                          key: ValueKey(waypoint.id),
                          index: index,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                                  : null,
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: InkWell(
                              onTap: () => widget.onWaypointSelected?.call(index),
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => WaypointEditorDialog(
                                    waypointIndex: index,
                                    waypoint: waypoint,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    // Drag Handle
                                    Icon(
                                      Icons.drag_handle,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Waypoint Number
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _getWaypointTypeColor(waypoint.type)
                                            .withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _getWaypointTypeColor(waypoint.type),
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: _getWaypointTypeColor(waypoint.type),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Name (Editable)
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _getNameController(waypoint),
                                        focusNode: _getNameFocusNode(waypoint.id),
                                        decoration: InputDecoration(
                                          hintText: 'WP${index + 1}',
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        ),
                                        style: theme.textTheme.bodyMedium,
                                        onSubmitted: (value) => 
                                            _updateWaypointName(index, value),
                                        onEditingComplete: () {
                                          _updateWaypointName(
                                            index,
                                            _getNameController(waypoint).text,
                                          );
                                        },
                                      ),
                                    ),
                                    
                                    // Altitude (Editable)
                                    SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: _getAltitudeController(waypoint),
                                        focusNode: _getAltitudeFocusNode(waypoint.id),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        decoration: InputDecoration(
                                          suffixText: 'ft',
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        ),
                                        style: theme.textTheme.bodyMedium,
                                        textAlign: TextAlign.right,
                                        onSubmitted: (value) => 
                                            _updateWaypointAltitude(index, value),
                                        onEditingComplete: () {
                                          _updateWaypointAltitude(
                                            index,
                                            _getAltitudeController(waypoint).text,
                                          );
                                        },
                                      ),
                                    ),
                                    
                                    // Distance
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        distanceFromPrevious != null
                                            ? '${_formatDistance(distanceFromPrevious)} nm'
                                            : '-',
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    
                                    // Time
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        timeFromPrevious != null
                                            ? _formatTime(timeFromPrevious)
                                            : '-',
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    
                                    // Fuel
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        fuelFromPrevious != null
                                            ? '${_formatFuel(fuelFromPrevious)} gal'
                                            : '-',
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    
                                    // More Options
                                    IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      iconSize: 20,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => WaypointEditorDialog(
                                            waypointIndex: index,
                                            waypoint: waypoint,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}