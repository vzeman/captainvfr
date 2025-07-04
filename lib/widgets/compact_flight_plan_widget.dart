import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/flight_plan_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/checklist_service.dart';
import '../models/aircraft.dart';
import '../models/checklist.dart';
import 'waypoint_table_widget.dart';

class CompactFlightPlanWidget extends StatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;

  const CompactFlightPlanWidget({
    super.key,
    required this.isVisible,
    required this.onClose,
  });

  @override
  State<CompactFlightPlanWidget> createState() => _CompactFlightPlanWidgetState();
}

class _CompactFlightPlanWidgetState extends State<CompactFlightPlanWidget> {
  final TextEditingController _cruiseSpeedController = TextEditingController();
  String? _selectedAircraftId;
  bool _isFlightPlanVisible = true;
  int? _selectedWaypointIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flightPlan = context.read<FlightPlanService>().currentFlightPlan;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Consumer<FlightPlanService>(
      builder: (context, flightPlanService, child) {
        final flightPlan = flightPlanService.currentFlightPlan;
        final isPlanning = flightPlanService.isPlanning;
        
        // Sync selected aircraft when flight plan changes
        if (flightPlan != null && flightPlan.aircraftId != _selectedAircraftId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedAircraftId = flightPlan.aircraftId;
              if (flightPlan.cruiseSpeed != null) {
                _cruiseSpeedController.text = flightPlan.cruiseSpeed!.toStringAsFixed(0);
              }
            });
          });
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 16,
          right: 16,
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactHeader(flightPlanService),
                if (flightPlan != null || isPlanning)
                  _buildCompactContent(flightPlanService),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactHeader(FlightPlanService flightPlanService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: flightPlanService.isPlanning ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(
            flightPlanService.isPlanning ? Icons.flight_takeoff : Icons.map,
            color: flightPlanService.isPlanning ? Colors.blue : Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              flightPlanService.isPlanning
                ? 'Flight Planning Active'
                : flightPlanService.currentFlightPlan?.name ?? 'No Flight Plan',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: flightPlanService.isPlanning ? Colors.blue : Colors.grey[700],
              ),
            ),
          ),
          if (flightPlanService.isPlanning)
            Text(
              'Tap map to add waypoints',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactContent(FlightPlanService flightPlanService) {
    final flightPlan = flightPlanService.currentFlightPlan;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick stats row
          if (flightPlan != null && flightPlan.waypoints.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickStat('Waypoints', '${flightPlan.waypoints.length}', Icons.location_on),
                  _buildQuickStat('Distance', '${flightPlan.totalDistance.toStringAsFixed(0)} nm', Icons.straighten),
                  if (flightPlan.cruiseSpeed != null && flightPlan.cruiseSpeed! > 0)
                    _buildQuickStat('Time', '${flightPlan.totalFlightTime.toStringAsFixed(0)} min', Icons.access_time),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Aircraft selection and cruise speed row
          Consumer<AircraftSettingsService>(
            builder: (context, aircraftService, child) {
              final aircrafts = aircraftService.aircrafts;
              
              return Column(
                children: [
                  // Aircraft selection
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.airplanemode_active, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        const Text('Aircraft:', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _selectedAircraftId,
                            isExpanded: true,
                            isDense: true,
                            hint: const Text('Select Aircraft', style: TextStyle(fontSize: 12)),
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            underline: const SizedBox(),
                            onChanged: (String? aircraftId) {
                              setState(() {
                                _selectedAircraftId = aircraftId;
                              });
                              if (aircraftId != null) {
                                _updateAircraft(flightPlanService, aircraftService, aircraftId);
                              }
                            },
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
                  const SizedBox(height: 8),
                  // Action buttons row
                  Row(
                    children: [
                      // Cruise speed input
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            const Icon(Icons.speed, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            const Text('Speed:', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextField(
                                controller: _cruiseSpeedController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: '120',
                                  suffix: Text('kts', style: TextStyle(fontSize: 10)),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  border: OutlineInputBorder(),
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
                      ),

                      const SizedBox(width: 8),

                      // Action buttons
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCompactButton(
                              icon: Icons.save,
                              label: 'Save',
                              onPressed: flightPlan != null ? () => _saveFlightPlan(flightPlanService) : null,
                            ),
                            _buildCompactButton(
                              icon: _isFlightPlanVisible ? Icons.visibility_off : Icons.visibility,
                              label: _isFlightPlanVisible ? 'Hide' : 'Show',
                              onPressed: () => _toggleFlightPlanVisibility(flightPlanService),
                            ),
                            _buildCompactButton(
                              icon: Icons.clear_all,
                              label: 'Clear',
                              onPressed: () => _clearFlightPlan(flightPlanService),
                            ),
                            if (flightPlanService.isPlanning)
                              _buildCompactButton(
                                icon: Icons.undo,
                                label: 'Undo',
                                onPressed: flightPlan != null && flightPlan.waypoints.isNotEmpty
                                  ? () => flightPlanService.removeLastWaypoint()
                                  : null,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          
          // Waypoint table (collapsible)
          if (flightPlan != null && flightPlan.waypoints.isNotEmpty)
            Consumer<AircraftSettingsService>(
              builder: (context, aircraftService, child) {
                final selectedAircraft = _selectedAircraftId != null
                    ? aircraftService.aircrafts.firstWhere(
                        (a) => a.id == _selectedAircraftId,
                        orElse: () => aircraftService.aircrafts.first,
                      )
                    : null;
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: WaypointTableWidget(
                    flightPlan: flightPlan,
                    selectedAircraft: selectedAircraft,
                    selectedWaypointIndex: _selectedWaypointIndex,
                    onWaypointSelected: (index) {
                      setState(() {
                        _selectedWaypointIndex = index;
                      });
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.blue),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: onPressed != null ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: onPressed != null ? Colors.blue.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: onPressed != null ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: onPressed != null ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveFlightPlan(FlightPlanService flightPlanService) async {
    final flightPlan = flightPlanService.currentFlightPlan;
    if (flightPlan == null) return;

    try {
      // Show name input dialog
      final name = await _showNameInputDialog();
      if (name != null && name.isNotEmpty) {
        flightPlan.name = name;
        await flightPlanService.saveCurrentFlightPlan(customName: name);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Flight plan "$name" saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving flight plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearFlightPlan(FlightPlanService flightPlanService) {
    flightPlanService.clearFlightPlan();
    _cruiseSpeedController.clear();
    setState(() {
      _selectedWaypointIndex = null;
    });
  }
  
  void _toggleFlightPlanVisibility(FlightPlanService flightPlanService) {
    setState(() {
      _isFlightPlanVisible = !_isFlightPlanVisible;
    });
    flightPlanService.toggleFlightPlanVisibility();
  }

  Future<String?> _showNameInputDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Flight Plan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Flight Plan Name',
            hintText: 'Enter a name for your flight plan',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
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
    }
  }
  
  void _checkForChecklists(Aircraft aircraft, dynamic model) async {
    final checklistService = context.read<ChecklistService>();
    final checklists = checklistService.getChecklistsForModel(model.id);
    
    if (checklists.isNotEmpty && mounted) {
      // Show checklist selection dialog
      final selectedChecklist = await showDialog<Checklist>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Checklist'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Found ${checklists.length} checklist(s) for ${model.name}'),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: checklists.length,
                    itemBuilder: (context, index) {
                      final checklist = checklists[index];
                      return ListTile(
                        title: Text(checklist.name),
                        subtitle: Text('${checklist.items.length} items'),
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
              child: const Text('Skip'),
            ),
          ],
        ),
      );
      
      if (selectedChecklist != null && mounted) {
        // Store selected checklist for later use
        // For now, just show a message
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