import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../models/aircraft.dart';
import '../services/flight_plan_service.dart';
import '../services/settings_service.dart';
import 'waypoint_editor_dialog.dart';
import '../constants/app_theme.dart';

class WaypointTableWidget extends StatefulWidget {
  final FlightPlan? flightPlan;
  final Aircraft? selectedAircraft;
  final int? selectedWaypointIndex;
  final Function(int)? onWaypointSelected;
  final bool isExpanded;
  final Function(bool)? onExpandedChanged;

  const WaypointTableWidget({
    super.key,
    this.flightPlan,
    this.selectedAircraft,
    this.selectedWaypointIndex,
    this.onWaypointSelected,
    this.isExpanded = true,
    this.onExpandedChanged,
  });

  @override
  State<WaypointTableWidget> createState() => _WaypointTableWidgetState();
}

class _WaypointTableWidgetState extends State<WaypointTableWidget>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
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
    _isExpanded = widget.isExpanded;
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
    widget.onExpandedChanged?.call(_isExpanded);
  }

  TextEditingController _getNameController(Waypoint waypoint) {
    if (!_nameControllers.containsKey(waypoint.id)) {
      _nameControllers[waypoint.id] = TextEditingController(
        text: waypoint.name ?? '',
      );
    } else {
      // Update controller text if waypoint name has changed
      final controller = _nameControllers[waypoint.id]!;
      if (controller.text != (waypoint.name ?? '')) {
        controller.text = waypoint.name ?? '';
      }
    }
    return _nameControllers[waypoint.id]!;
  }

  TextEditingController _getAltitudeController(
    Waypoint waypoint,
    bool isMetric,
  ) {
    final key =
        '${waypoint.id}_$isMetric'; // Include units in key to refresh when changed
    if (!_altitudeControllers.containsKey(key)) {
      // Remove old controller with different units if exists
      _altitudeControllers.removeWhere(
        (k, v) => k.startsWith('${waypoint.id}_'),
      );

      // Convert altitude to display units
      final displayAltitude = isMetric
          ? waypoint.altitude *
                0.3048 // Convert feet to meters
          : waypoint.altitude;
      _altitudeControllers[key] = TextEditingController(
        text: displayAltitude.toStringAsFixed(0),
      );
    }
    return _altitudeControllers[key]!;
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
    flightPlanService.updateWaypointName(index, name.isNotEmpty ? name : null);
  }

  void _updateWaypointAltitude(int index, String altitudeText, bool isMetric) {
    var altitude = double.tryParse(altitudeText);
    if (altitude != null) {
      // Convert to feet for storage if metric
      if (isMetric) {
        altitude = altitude / 0.3048; // Convert meters to feet
      }
      final flightPlanService = Provider.of<FlightPlanService>(
        context,
        listen: false,
      );
      flightPlanService.updateWaypointAltitude(index, altitude);
    }
  }

  String _formatDistance(double distance, bool isMetric) {
    final displayDistance = isMetric
        ? distance * 1.852
        : distance; // Convert nm to km if metric
    return displayDistance.toStringAsFixed(1);
  }

  String _getDistanceUnit(bool isMetric) {
    return isMetric ? 'km' : 'nm';
  }

  String _getAltitudeUnit(bool isMetric) {
    return isMetric ? 'm' : 'ft';
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

  String _formatFuel(double gallons, bool isMetric) {
    final displayFuel = isMetric
        ? gallons * 3.78541
        : gallons; // Convert gallons to liters if metric
    return displayFuel.toStringAsFixed(1);
  }

  String _getFuelUnit(bool isMetric) {
    return isMetric ? 'L' : 'gal';
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
    final waypoints = widget.flightPlan?.waypoints ?? [];
    final cruiseSpeed =
        widget.flightPlan?.cruiseSpeed ??
        widget.selectedAircraft?.cruiseSpeed.toDouble();
    final fuelConsumption = widget.selectedAircraft?.fuelConsumption;

    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';

        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0x1A448AFF), // Light blue background
            borderRadius: AppTheme.largeRadius,
            border: Border.all(color: const Color(0x33448AFF)),
          ),
          child: Column(
            children: [
              // Header
              InkWell(
                onTap: _toggleExpanded,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33448AFF), // Darker blue for header
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.borderRadiusLarge),
                      topRight: Radius.circular(AppTheme.borderRadiusLarge),
                      bottomLeft: _isExpanded
                          ? Radius.zero
                          : Radius.circular(AppTheme.borderRadiusLarge),
                      bottomRight: _isExpanded
                          ? Radius.zero
                          : Radius.circular(AppTheme.borderRadiusLarge),
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Waypoints (${waypoints.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (waypoints.isNotEmpty && cruiseSpeed != null)
                        Expanded(
                          child: Text(
                            'Total: ${_formatDistance(widget.flightPlan!.totalDistance, isMetric)} ${_getDistanceUnit(isMetric)}, '
                            '${_formatTime(widget.flightPlan!.totalFlightTime)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      if (waypoints.isEmpty || cruiseSpeed == null)
                        const Spacer(),
                      // Undo button - only show in edit mode when there are waypoints
                      if (waypoints.isNotEmpty)
                        Consumer<FlightPlanService>(
                          builder: (context, flightPlanService, child) {
                            return flightPlanService.isPlanning
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.undo,
                                        color: Color(0xFF448AFF),
                                        size: 20,
                                      ),
                                      onPressed: () => flightPlanService
                                          .removeLastWaypoint(),
                                      tooltip: 'Remove last waypoint',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Table Content
              SizeTransition(
                sizeFactor: _animation,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(AppTheme.borderRadiusLarge),
                      bottomRight: Radius.circular(AppTheme.borderRadiusLarge),
                    ),
                  ),
                  child: waypoints.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No waypoints added yet',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : Container(
                          constraints: BoxConstraints(
                            maxHeight: 400, // Limit height to enable scrolling
                          ),
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorder: (oldIndex, newIndex) {
                              final flightPlanService =
                                  Provider.of<FlightPlanService>(
                                    context,
                                    listen: false,
                                  );
                              flightPlanService.reorderWaypoints(
                                oldIndex,
                                newIndex,
                              );
                            },
                            itemCount: waypoints.length,
                            itemBuilder: (context, index) {
                              final waypoint = waypoints[index];
                              final isSelected =
                                  widget.selectedWaypointIndex == index;

                              // Calculate segment data
                              double? distanceFromPrevious;
                              double? timeFromPrevious;
                              double? fuelFromPrevious;
                              double? headingFromPrevious;

                              if (index > 0) {
                                distanceFromPrevious = waypoints[index - 1]
                                    .distanceTo(waypoint);
                                headingFromPrevious = waypoints[index - 1]
                                    .bearingTo(waypoint);
                                if (cruiseSpeed != null && cruiseSpeed > 0) {
                                  timeFromPrevious =
                                      (distanceFromPrevious / cruiseSpeed) * 60;
                                  if (fuelConsumption != null &&
                                      fuelConsumption > 0) {
                                    fuelFromPrevious =
                                        (timeFromPrevious / 60) *
                                        fuelConsumption;
                                  }
                                }
                              }

                              return Container(
                                key: ValueKey(waypoint.id),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0x33448AFF)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: const Color(0x33448AFF),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () =>
                                      widget.onWaypointSelected?.call(index),
                                  onLongPress: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          WaypointEditorDialog(
                                            waypointIndex: index,
                                            waypoint: waypoint,
                                          ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Drag Handle
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: ReorderableDragStartListener(
                                            index: index,
                                            child: const Icon(
                                              Icons.drag_handle,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Waypoint Number
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: _getWaypointTypeColor(
                                                waypoint.type,
                                              ).withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _getWaypointTypeColor(
                                                  waypoint.type,
                                                ),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: _getWaypointTypeColor(
                                                    waypoint.type,
                                                  ),
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Main content in column
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // First row: Name and Altitude
                                              Row(
                                                children: [
                                                  // Name (Editable only in planning mode)
                                                  Expanded(
                                                    child: Consumer<FlightPlanService>(
                                                      builder: (context, flightPlanService, child) {
                                                        final isPlanning = flightPlanService.isPlanning;
                                                        return isPlanning
                                                            ? TextField(
                                                                controller:
                                                                    _getNameController(
                                                                      waypoint,
                                                                    ),
                                                                focusNode:
                                                                    _getNameFocusNode(
                                                                      waypoint.id,
                                                                    ),
                                                                decoration: InputDecoration(
                                                                  hintText:
                                                                      'WP${index + 1}',
                                                                  hintStyle:
                                                                      const TextStyle(
                                                                        color: Colors
                                                                            .white30,
                                                                      ),
                                                                  border:
                                                                      InputBorder.none,
                                                                  isDense: true,
                                                                  contentPadding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal: 8,
                                                                        vertical: 2,
                                                                      ),
                                                                ),
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight.w500,
                                                                ),
                                                                onSubmitted: (value) =>
                                                                    _updateWaypointName(
                                                                      index,
                                                                      value,
                                                                    ),
                                                                onEditingComplete: () {
                                                                  _updateWaypointName(
                                                                    index,
                                                                    _getNameController(
                                                                      waypoint,
                                                                    ).text,
                                                                  );
                                                                },
                                                              )
                                                            : InkWell(
                                                                onTap: () {
                                                                  // Just focus the waypoint on map
                                                                  widget.onWaypointSelected?.call(index);
                                                                },
                                                                child: Container(
                                                                  padding: const EdgeInsets.symmetric(
                                                                    horizontal: 8,
                                                                    vertical: 8,  // Increased from 2 for better touch target
                                                                  ),
                                                                  child: Text(
                                                                    waypoint.name ?? 'WP${index + 1}',
                                                                    style: const TextStyle(
                                                                      color: Colors.white,
                                                                      fontSize: 12,
                                                                      fontWeight: FontWeight.w500,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Altitude (Editable only in planning mode)
                                                  SizedBox(
                                                    width: 80,
                                                    child: Consumer<FlightPlanService>(
                                                      builder: (context, flightPlanService, child) {
                                                        final isPlanning = flightPlanService.isPlanning;
                                                        return isPlanning
                                                            ? TextField(
                                                                controller:
                                                                    _getAltitudeController(
                                                                      waypoint,
                                                                      isMetric,
                                                                    ),
                                                                focusNode:
                                                                    _getAltitudeFocusNode(
                                                                      waypoint.id,
                                                                    ),
                                                                keyboardType:
                                                                    TextInputType.number,
                                                                inputFormatters: [
                                                                  FilteringTextInputFormatter
                                                                      .digitsOnly,
                                                                ],
                                                                decoration: InputDecoration(
                                                                  suffixText:
                                                                      _getAltitudeUnit(
                                                                        isMetric,
                                                                      ),
                                                                  suffixStyle:
                                                                      const TextStyle(
                                                                        color: Colors
                                                                            .white70,
                                                                        fontSize: 12,
                                                                      ),
                                                                  border:
                                                                      InputBorder.none,
                                                                  isDense: true,
                                                                  contentPadding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal: 8,
                                                                        vertical: 2,
                                                                      ),
                                                                ),
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 12,
                                                                ),
                                                                textAlign:
                                                                    TextAlign.right,
                                                                onSubmitted: (value) =>
                                                                    _updateWaypointAltitude(
                                                                      index,
                                                                      value,
                                                                      isMetric,
                                                          ),
                                                                onEditingComplete: () {
                                                                  _updateWaypointAltitude(
                                                                    index,
                                                                    _getAltitudeController(
                                                                      waypoint,
                                                                      isMetric,
                                                                    ).text,
                                                                    isMetric,
                                                                  );
                                                                },
                                                              )
                                                            : Container(
                                                                padding: const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 8,  // Increased from 2 for better touch target
                                                                ),
                                                                alignment: Alignment.centerRight,
                                                                child: Text(
                                                                  '${_getAltitudeController(waypoint, isMetric).text} ${_getAltitudeUnit(isMetric)}',
                                                                  style: const TextStyle(
                                                                    color: Colors.white,
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                              );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // Second row: Computed values (only if available)
                                              if (distanceFromPrevious !=
                                                      null ||
                                                  timeFromPrevious != null ||
                                                  fuelFromPrevious != null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      // Distance
                                                      if (distanceFromPrevious !=
                                                          null) ...[
                                                        Text(
                                                          '${_formatDistance(distanceFromPrevious, isMetric)} ${_getDistanceUnit(isMetric)}',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white60,
                                                                fontSize: 10,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                      ],
                                                      // Heading
                                                      if (headingFromPrevious !=
                                                          null) ...[
                                                        Text(
                                                          '${headingFromPrevious.toStringAsFixed(0)}°',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white60,
                                                                fontSize: 10,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                      ],
                                                      // Time
                                                      if (timeFromPrevious !=
                                                              null &&
                                                          cruiseSpeed !=
                                                              null) ...[
                                                        Text(
                                                          _formatTime(
                                                            timeFromPrevious,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white60,
                                                                fontSize: 10,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                      ],
                                                      // Fuel
                                                      if (fuelFromPrevious !=
                                                              null &&
                                                          fuelConsumption !=
                                                              null) ...[
                                                        Text(
                                                          '${_formatFuel(fuelFromPrevious, isMetric)} ${_getFuelUnit(isMetric)}',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white60,
                                                                fontSize: 10,
                                                              ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // More Options
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.more_vert,
                                              color: Colors.white70,
                                            ),
                                            iconSize: 20,
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    WaypointEditorDialog(
                                                      waypointIndex: index,
                                                      waypoint: waypoint,
                                                    ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
