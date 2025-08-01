import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/flight_plan_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/settings_service.dart';
import 'waypoint_table_widget.dart';
import '../constants/app_theme.dart';

class FlightPlanningPanel extends StatefulWidget {
  final bool? isExpanded;
  final Function(bool)? onExpandedChanged;
  final VoidCallback? onClose;
  final Function(int)? onWaypointFocus;

  const FlightPlanningPanel({
    super.key,
    this.isExpanded,
    this.onExpandedChanged,
    this.onClose,
    this.onWaypointFocus,
  });

  @override
  State<FlightPlanningPanel> createState() => _FlightPlanningPanelState();
}

class _FlightPlanningPanelState extends State<FlightPlanningPanel> {
  late bool _isExpanded;
  bool _isEditMode = false;
  final TextEditingController _cruiseSpeedController = TextEditingController();
  String? _selectedAircraftId;
  int? _selectedWaypointIndex;
  Timer? _autosaveTimer;
  Timer? _cruiseSpeedDebouncer;
  bool _isWaypointTableExpanded = false; // Track waypoint table expanded state - default collapsed
  
  static const String _waypointTableExpandedKey = 'waypoint_table_expanded';

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded ?? true;
    _loadWaypointTableState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flightPlanService = context.read<FlightPlanService>();
      final aircraftService = context.read<AircraftSettingsService>();
      final flightPlan = flightPlanService.currentFlightPlan;

      // Sync edit mode with planning mode - only sync if planning mode is true
      // This prevents turning off planning mode when the panel is first opened
      if (flightPlanService.isPlanning &&
          flightPlanService.isPlanning != _isEditMode) {
        setState(() {
          _isEditMode = flightPlanService.isPlanning;
        });
      }

      if (flightPlan != null) {
        _selectedAircraftId = flightPlan.aircraftId;
        if (flightPlan.cruiseSpeed != null) {
          _cruiseSpeedController.text = flightPlan.cruiseSpeed!.toStringAsFixed(
            0,
          );
        }
      }

      // Auto-select aircraft if not already selected
      if (_selectedAircraftId == null && aircraftService.aircrafts.isNotEmpty) {
        final aircrafts = aircraftService.aircrafts;

        // Try to use the currently selected aircraft in aircraft service
        if (aircraftService.selectedAircraft != null) {
          setState(() {
            _selectedAircraftId = aircraftService.selectedAircraft!.id;
          });
          _updateAircraft(
            flightPlanService,
            aircraftService,
            aircraftService.selectedAircraft!.id,
          );
        } else if (aircrafts.length == 1) {
          // Only one aircraft - auto-select it
          setState(() {
            _selectedAircraftId = aircrafts.first.id;
          });
          _updateAircraft(
            flightPlanService,
            aircraftService,
            aircrafts.first.id,
          );
        }
        // Note: When multiple aircraft exist and none is selected, let user choose
        // had an aircraftId field in the future
      }
    });
  }

  @override
  void dispose() {
    _cruiseSpeedController.dispose();
    _autosaveTimer?.cancel();
    _cruiseSpeedDebouncer?.cancel();
    super.dispose();
  }

  void _toggleExpanded(bool expanded) {
    setState(() {
      _isExpanded = expanded;
    });
    widget.onExpandedChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final flightPlanService = Provider.of<FlightPlanService>(context);

    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    // Responsive margins and width
    final horizontalMargin = isPhone ? 8.0 : 16.0;
    final maxWidth = isPhone ? double.infinity : (isTablet ? 600.0 : 800.0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: 16.0,
      ),
      constraints: BoxConstraints(
        minHeight: _isExpanded ? 200 : 60,
        maxHeight: _isExpanded ? 600 : 60,
        minWidth: 300,
        maxWidth: maxWidth,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE6000000), // Black with 0.9 opacity (less transparent)
            borderRadius: AppTheme.largeRadius,
            border: Border.all(
              color: const Color(0x7F448AFF),
              width: 1.0,
            ), // Blue accent with 0.5 opacity
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with edit mode toggle
              _buildHeader(context, flightPlanService),
              if (_isExpanded)
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 550, // Leave some space for header
                    ),
                    child: _buildExpandedView(context, flightPlanService),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    FlightPlanService flightPlanService,
  ) {
    final flightPlan = flightPlanService.currentFlightPlan;
    final isPlanning = flightPlanService.isPlanning;

    return Container(
      decoration: BoxDecoration(
        color: _isEditMode ? const Color(0x33448AFF) : Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusLarge)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: _isExpanded ? 8.0 : 4.0,
      ),
      child: Row(
        children: [
          // Expand/Collapse button
          IconButton(
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF448AFF),
              size: _isExpanded ? 24 : 20,
            ),
            onPressed: () => _toggleExpanded(!_isExpanded),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: _isExpanded ? 32 : 28,
              minHeight: _isExpanded ? 32 : 28,
            ),
          ),

          // Flight planning icon
          Icon(
            isPlanning || _isEditMode ? Icons.flight_takeoff : Icons.map,
            color: isPlanning || _isEditMode
                ? const Color(0xFF448AFF)
                : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 8),

          // Title and stats
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flightPlan?.name ??
                      (isPlanning ? 'Flight Planning' : 'No Flight Plan'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _isExpanded ? 14 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isExpanded &&
                    flightPlan != null &&
                    flightPlan.waypoints.isNotEmpty)
                  Consumer<SettingsService>(
                    builder: (context, settings, child) {
                      final isMetric = settings.units == 'metric';
                      final distance = flightPlan.totalDistance;
                      final displayDistance = isMetric
                          ? distance * 1.852
                          : distance;
                      final unit = isMetric ? 'km' : 'nm';
                      return Text(
                        '${flightPlan.waypoints.length} waypoints • ${displayDistance.toStringAsFixed(0)} $unit',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
              ],
            ),
          ),

          // Edit mode toggle slider
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  'Edit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _isEditMode,
                    onChanged: (value) {
                      setState(() {
                        _isEditMode = value;
                      });
                      if (value && !flightPlanService.isPlanning) {
                        flightPlanService.togglePlanningMode();
                      } else if (!value && flightPlanService.isPlanning) {
                        flightPlanService.togglePlanningMode();
                      }
                    },
                    activeColor: const Color(0xFF448AFF),
                    activeTrackColor: const Color(0x66448AFF),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),

          // Close button
          if (widget.onClose != null)
            IconButton(
              icon: Icon(
                Icons.close,
                size: _isExpanded ? 20 : 18,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: _isExpanded ? 32 : 28,
                minHeight: _isExpanded ? 32 : 28,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    FlightPlanService flightPlanService,
  ) {
    final flightPlan = flightPlanService.currentFlightPlan;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aircraft selection and cruise speed
          _buildAircraftSection(flightPlanService),

          // Edit mode hint
          if (_isEditMode)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1A448AFF),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(color: const Color(0x33448AFF)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Click on the map to add waypoints • Click green + icons on flight path to insert waypoints',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Waypoint table
          if (flightPlan != null && flightPlan.waypoints.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              child: Consumer<AircraftSettingsService>(
                builder: (context, aircraftService, child) {
                  final selectedAircraft = _selectedAircraftId != null
                      ? aircraftService.aircrafts.firstWhere(
                          (a) => a.id == _selectedAircraftId,
                          orElse: () => aircraftService.aircrafts.first,
                        )
                      : null;
                  return WaypointTableWidget(
                    flightPlan: flightPlan,
                    selectedAircraft: selectedAircraft,
                    selectedWaypointIndex: _selectedWaypointIndex,
                    isExpanded: _isWaypointTableExpanded,
                    onExpandedChanged: (expanded) {
                      setState(() {
                        _isWaypointTableExpanded = expanded;
                      });
                      _saveWaypointTableState(expanded);
                    },
                    onWaypointSelected: (index) {
                      setState(() {
                        _selectedWaypointIndex = index;
                      });
                      // Focus map on selected waypoint
                      widget.onWaypointFocus?.call(index);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAircraftSection(FlightPlanService flightPlanService) {
    return Consumer<AircraftSettingsService>(
      builder: (context, aircraftService, child) {
        final aircrafts = aircraftService.aircrafts;

        // If no aircraft defined, only show cruise speed input
        if (aircrafts.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x1A448AFF),
              border: Border.all(color: const Color(0x33448AFF)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed, size: 16, color: Color(0xFF448AFF)),
                const SizedBox(width: 4),
                const Text(
                  'Cruise Speed:',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _cruiseSpeedController,
                    enabled: _isEditMode,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '120',
                      hintStyle: const TextStyle(color: Colors.white30),
                      suffix: const Text(
                        'kts',
                        style: TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      filled: true,
                      fillColor: const Color(0x1A448AFF),
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.mediumRadius,
                        borderSide: const BorderSide(color: Color(0x33448AFF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppTheme.mediumRadius,
                        borderSide: const BorderSide(color: Color(0x33448AFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppTheme.mediumRadius,
                        borderSide: const BorderSide(color: Color(0xFF448AFF)),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: AppTheme.mediumRadius,
                        borderSide: const BorderSide(color: Color(0x1A666666)),
                      ),
                    ),
                    onChanged: (value) => _onCruiseSpeedChanged(value, flightPlanService),
                  ),
                ),
              ],
            ),
          );
        }

        // Show full aircraft section when aircraft are available
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x1A448AFF),
            border: Border.all(color: const Color(0x33448AFF)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Aircraft selection
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Icon(
                      Icons.airplanemode_active,
                      size: 16,
                      color: Color(0xFF448AFF),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Aircraft:',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedAircraftId,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text(
                          'Select Aircraft',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        dropdownColor: const Color(0xE6000000),
                        underline: const SizedBox(),
                        onChanged: (String? aircraftId) {
                          setState(() {
                            _selectedAircraftId = aircraftId;
                          });
                          if (aircraftId != null) {
                            _updateAircraft(
                              flightPlanService,
                              aircraftService,
                              aircraftId,
                            );
                          }
                        },
                        items: aircrafts.map((aircraft) {
                          final model = aircraftService.models.firstWhere(
                            (m) => m.id == aircraft.modelId,
                            orElse: () => aircraftService.models.first,
                          );
                          final manufacturer = aircraftService.manufacturers
                              .firstWhere(
                                (m) => m.id == model.manufacturerId,
                                orElse: () =>
                                    aircraftService.manufacturers.first,
                              );

                          return DropdownMenuItem<String>(
                            value: aircraft.id,
                            child: Text(
                              '${aircraft.registration} - ${manufacturer.name} ${model.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Cruise speed input
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Icon(Icons.speed, size: 16, color: Color(0xFF448AFF)),
                    const SizedBox(width: 4),
                    const Text(
                      'Speed:',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _cruiseSpeedController,
                        enabled: _isEditMode,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: '120',
                          hintStyle: const TextStyle(color: Colors.white30),
                          suffix: const Text(
                            'kts',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          filled: true,
                          fillColor: const Color(0x1A448AFF),
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.mediumRadius,
                            borderSide: const BorderSide(
                              color: Color(0x33448AFF),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppTheme.mediumRadius,
                            borderSide: const BorderSide(
                              color: Color(0x33448AFF),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppTheme.mediumRadius,
                            borderSide: const BorderSide(
                              color: Color(0xFF448AFF),
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: AppTheme.mediumRadius,
                            borderSide: const BorderSide(
                              color: Color(0x1A666666),
                            ),
                          ),
                        ),
                        onChanged: (value) => _onCruiseSpeedChanged(value, flightPlanService),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateAircraft(
    FlightPlanService flightPlanService,
    AircraftSettingsService aircraftService,
    String aircraftId,
  ) {
    final aircraft = aircraftService.aircrafts.firstWhere(
      (a) => a.id == aircraftId,
      orElse: () => aircraftService.aircrafts.first,
    );

    final model = aircraftService.models.firstWhere(
      (m) => m.id == aircraft.modelId,
      orElse: () => aircraftService.models.first,
    );

    // Update flight plan with aircraft
    if (flightPlanService.currentFlightPlan != null) {
      flightPlanService.currentFlightPlan!.aircraftId = aircraftId;

      // Update cruise speed from aircraft/model if available
      double cruiseSpeed = aircraft.cruiseSpeed > 0
          ? aircraft.cruiseSpeed.toDouble()
          : model.typicalCruiseSpeed.toDouble();
      if (cruiseSpeed > 0) {
        _cruiseSpeedController.text = cruiseSpeed.toStringAsFixed(0);
        flightPlanService.updateCruiseSpeed(cruiseSpeed);
      }

      // Checklist selection removed - user can access checklists manually if needed

      // Autosave
      _autosaveFlightPlan(flightPlanService);
    }
  }

  void _autosaveFlightPlan(FlightPlanService flightPlanService) {
    // Cancel any existing timer
    _autosaveTimer?.cancel();

    // Set a new timer to save after 1 second of inactivity
    _autosaveTimer = Timer(const Duration(seconds: 1), () {
      if (flightPlanService.currentFlightPlan != null) {
        flightPlanService.saveCurrentFlightPlan();
      }
    });
  }

  void _onCruiseSpeedChanged(String value, FlightPlanService flightPlanService) {
    // Cancel any existing debouncer
    _cruiseSpeedDebouncer?.cancel();
    
    // Only update after user stops typing for 500ms
    _cruiseSpeedDebouncer = Timer(const Duration(milliseconds: 500), () {
      final speed = double.tryParse(value);
      if (speed != null && speed > 0) {
        flightPlanService.updateCruiseSpeed(speed);
        _autosaveFlightPlan(flightPlanService);
      }
    });
  }

  Future<void> _loadWaypointTableState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isExpanded = prefs.getBool(_waypointTableExpandedKey) ?? false;
      if (mounted) {
        setState(() {
          _isWaypointTableExpanded = isExpanded;
        });
      }
    } catch (e) {
      // Keep default state if loading fails
    }
  }

  Future<void> _saveWaypointTableState(bool isExpanded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_waypointTableExpandedKey, isExpanded);
    } catch (e) {
      // Ignore save errors
    }
  }

}
