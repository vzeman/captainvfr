import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/flight_plan_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/checklist_service.dart';
import '../services/settings_service.dart';
import '../models/aircraft.dart';
import '../models/checklist.dart';
import 'waypoint_table_widget.dart';

class FlightPlanningPanel extends StatefulWidget {
  final bool? isExpanded;
  final Function(bool)? onExpandedChanged;
  final VoidCallback? onClose;
  
  const FlightPlanningPanel({
    super.key,
    this.isExpanded,
    this.onExpandedChanged,
    this.onClose,
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
  
  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flightPlanService = context.read<FlightPlanService>();
      final flightPlan = flightPlanService.currentFlightPlan;
      
      // Sync edit mode with planning mode
      if (flightPlanService.isPlanning != _isEditMode) {
        setState(() {
          _isEditMode = flightPlanService.isPlanning;
        });
      }
      
      // If planning mode is on but it shouldn't be (edit mode is off), turn it off
      if (flightPlanService.isPlanning && !_isEditMode) {
        flightPlanService.togglePlanningMode();
      }
      
      if (flightPlan != null) {
        _selectedAircraftId = flightPlan.aircraftId;
        if (flightPlan.cruiseSpeed != null) {
          _cruiseSpeedController.text = flightPlan.cruiseSpeed!.toStringAsFixed(0);
        }
      }
    });
  }
  
  @override
  void dispose() {
    _cruiseSpeedController.dispose();
    _autosaveTimer?.cancel();
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
        minHeight: _isExpanded ? 200 : 50,
        maxHeight: _isExpanded ? 600 : 50,
        minWidth: 300,
        maxWidth: maxWidth,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xB3000000), // Black with 0.7 opacity
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: const Color(0x7F448AFF), width: 1.0), // Blue accent with 0.5 opacity
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
  
  Widget _buildHeader(BuildContext context, FlightPlanService flightPlanService) {
    final flightPlan = flightPlanService.currentFlightPlan;
    final isPlanning = flightPlanService.isPlanning;
    
    return Container(
      decoration: BoxDecoration(
        color: _isEditMode ? const Color(0x33448AFF) : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          // Expand/Collapse button
          IconButton(
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF448AFF),
            ),
            onPressed: () => _toggleExpanded(!_isExpanded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          
          // Flight planning icon
          Icon(
            isPlanning || _isEditMode ? Icons.flight_takeoff : Icons.map,
            color: isPlanning || _isEditMode ? const Color(0xFF448AFF) : Colors.white70,
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
                  flightPlan?.name ?? (isPlanning ? 'Flight Planning' : 'No Flight Plan'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (flightPlan != null && flightPlan.waypoints.isNotEmpty)
                  Consumer<SettingsService>(
                    builder: (context, settings, child) {
                      final isMetric = settings.units == 'metric';
                      final distance = flightPlan.totalDistance;
                      final displayDistance = isMetric ? distance * 1.852 : distance;
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
                  'Edit Mode',
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
                size: 20,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
  
  Widget _buildExpandedView(BuildContext context, FlightPlanService flightPlanService) {
    final flightPlan = flightPlanService.currentFlightPlan;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aircraft selection and cruise speed
          _buildAircraftSection(flightPlanService),
          
          const SizedBox(height: 12),
          
          // Action buttons
          _buildActionButtons(flightPlanService),
          
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
                    onWaypointSelected: (index) {
                      setState(() {
                        _selectedWaypointIndex = index;
                      });
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
                    const Icon(Icons.airplanemode_active, size: 16, color: Color(0xFF448AFF)),
                    const SizedBox(width: 4),
                    const Text('Aircraft:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedAircraftId,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text('Select Aircraft', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        dropdownColor: const Color(0xE6000000),
                        underline: const SizedBox(),
                        onChanged: _isEditMode ? (String? aircraftId) {
                          setState(() {
                            _selectedAircraftId = aircraftId;
                          });
                          if (aircraftId != null) {
                            _updateAircraft(flightPlanService, aircraftService, aircraftId);
                          }
                        } : null,
                        items: aircrafts.map((aircraft) {
                          final model = aircraftService.models.firstWhere(
                            (m) => m.id == aircraft.modelId,
                            orElse: () => aircraftService.models.first,
                          );
                          final manufacturer = aircraftService.manufacturers.firstWhere(
                            (m) => m.id == model.manufacturerId,
                            orElse: () => aircraftService.manufacturers.first,
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
                    const Text('Speed:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _cruiseSpeedController,
                        enabled: _isEditMode,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '120',
                          hintStyle: const TextStyle(color: Colors.white30),
                          suffix: const Text('kts', style: TextStyle(fontSize: 10, color: Colors.white70)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          filled: true,
                          fillColor: const Color(0x1A448AFF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0x33448AFF)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0x33448AFF)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFF448AFF)),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0x1A666666)),
                          ),
                        ),
                        onChanged: (value) {
                          final speed = double.tryParse(value);
                          if (speed != null && speed > 0) {
                            flightPlanService.updateCruiseSpeed(speed);
                            // Implement autosave
                            _autosaveFlightPlan(flightPlanService);
                          }
                        },
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
  
  Widget _buildActionButtons(FlightPlanService flightPlanService) {
    final flightPlan = flightPlanService.currentFlightPlan;
    
    // Only show undo button when there are waypoints to remove
    if (!_isEditMode || flightPlan == null || flightPlan.waypoints.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      alignment: Alignment.center,
      child: _buildActionButton(
        icon: Icons.undo,
        label: 'Undo',
        onPressed: () => flightPlanService.removeLastWaypoint(),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: onPressed != null ? const Color(0x1A448AFF) : const Color(0x1A666666),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: onPressed != null ? const Color(0x33448AFF) : const Color(0x33666666),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: onPressed != null ? const Color(0xFF448AFF) : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: onPressed != null ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _updateAircraft(FlightPlanService flightPlanService, AircraftSettingsService aircraftService, String aircraftId) {
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
      double cruiseSpeed = aircraft.cruiseSpeed > 0 ? aircraft.cruiseSpeed.toDouble() : model.typicalCruiseSpeed.toDouble();
      if (cruiseSpeed > 0) {
        _cruiseSpeedController.text = cruiseSpeed.toStringAsFixed(0);
        flightPlanService.updateCruiseSpeed(cruiseSpeed);
      }
      
      // Check for available checklists
      _checkForChecklists(aircraft, model);
      
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
  
  void _checkForChecklists(Aircraft aircraft, dynamic model) async {
    final checklistService = context.read<ChecklistService>();
    final checklists = checklistService.getChecklistsForModel(model.id);
    
    if (checklists.isNotEmpty && mounted) {
      final selectedChecklist = await showDialog<Checklist>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xE6000000),
          title: const Text('Select Checklist', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Found ${checklists.length} checklist(s) for ${model.name}', 
                  style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: checklists.length,
                    itemBuilder: (context, index) {
                      final checklist = checklists[index];
                      return ListTile(
                        title: Text(checklist.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${checklist.items.length} items', 
                          style: const TextStyle(color: Colors.white70)),
                        onTap: () => Navigator.of(context).pop(checklist),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
      
      if (selectedChecklist != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected checklist: ${selectedChecklist.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}