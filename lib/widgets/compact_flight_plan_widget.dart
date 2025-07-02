import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/flight_plan_service.dart';

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
}
