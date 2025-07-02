import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';

class FlightPlansScreen extends StatefulWidget {
  const FlightPlansScreen({super.key});

  @override
  State<FlightPlansScreen> createState() => _FlightPlansScreenState();
}

class _FlightPlansScreenState extends State<FlightPlansScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize flight plan service if not already done
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flightPlanService = Provider.of<FlightPlanService>(context, listen: false);
      flightPlanService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Plans'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewFlightPlanDialog(context),
          ),
        ],
      ),
      body: Consumer<FlightPlanService>(
        builder: (context, flightPlanService, child) {
          final flightPlans = flightPlanService.savedFlightPlans;

          if (flightPlans.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flight_takeoff,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No flight plans yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create your first flight plan to get started',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: flightPlans.length,
            itemBuilder: (context, index) {
              final flightPlan = flightPlans[index];
              return _buildFlightPlanCard(context, flightPlan, flightPlanService);
            },
          );
        },
      ),
    );
  }

  Widget _buildFlightPlanCard(BuildContext context, FlightPlan flightPlan, FlightPlanService flightPlanService) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.flight_takeoff, color: Colors.white),
        ),
        title: Text(
          flightPlan.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getFlightPlanSummary(flightPlan)),
            const SizedBox(height: 4),
            Text(
              'Created: ${_formatDate(flightPlan.createdAt)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            if (flightPlan.modifiedAt != null)
              Text(
                'Modified: ${_formatDate(flightPlan.modifiedAt!)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value, flightPlan, flightPlanService),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'load',
              child: Row(
                children: [
                  Icon(Icons.map, size: 20),
                  SizedBox(width: 8),
                  Text('Load to Map'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit Name'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'duplicate',
              child: Row(
                children: [
                  Icon(Icons.copy, size: 20),
                  SizedBox(width: 8),
                  Text('Duplicate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _loadFlightPlanAndNavigateBack(context, flightPlan, flightPlanService),
      ),
    );
  }

  String _getFlightPlanSummary(FlightPlan flightPlan) {
    final distance = flightPlan.totalDistance;
    final time = flightPlan.totalFlightTime;

    String summary = '${flightPlan.waypoints.length} waypoints, ';
    summary += '${distance.toStringAsFixed(1)} NM';

    if (time > 0) {
      final hours = (time / 60).floor();
      final minutes = (time % 60).round();
      summary += ', ${hours}h ${minutes}m';
    }

    return summary;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _handleMenuAction(BuildContext context, String action, FlightPlan flightPlan, FlightPlanService flightPlanService) {
    switch (action) {
      case 'load':
        _loadFlightPlanAndNavigateBack(context, flightPlan, flightPlanService);
        break;
      case 'edit':
        _showEditNameDialog(context, flightPlan, flightPlanService);
        break;
      case 'duplicate':
        _duplicateFlightPlan(flightPlan, flightPlanService);
        break;
      case 'delete':
        _showDeleteConfirmDialog(context, flightPlan, flightPlanService);
        break;
    }
  }

  void _loadFlightPlanAndNavigateBack(BuildContext context, FlightPlan flightPlan, FlightPlanService flightPlanService) {
    flightPlanService.loadFlightPlan(flightPlan.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded flight plan: ${flightPlan.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showNewFlightPlanDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Flight Plan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Flight Plan Name',
            hintText: 'Enter flight plan name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final flightPlanService = Provider.of<FlightPlanService>(context, listen: false);
              flightPlanService.startNewFlightPlan(name: controller.text.trim());
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to map
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, FlightPlan flightPlan, FlightPlanService flightPlanService) {
    final controller = TextEditingController(text: flightPlan.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Flight Plan Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Flight Plan Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                flightPlan.name = controller.text.trim();
                flightPlan.modifiedAt = DateTime.now();
                await flightPlanService.saveCurrentFlightPlan();
              }
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _duplicateFlightPlan(FlightPlan flightPlan, FlightPlanService flightPlanService) {
    flightPlanService.duplicateFlightPlan(flightPlan.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flight plan duplicated'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, FlightPlan flightPlan, FlightPlanService flightPlanService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flight Plan'),
        content: Text('Are you sure you want to delete "${flightPlan.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              flightPlanService.deleteFlightPlan(flightPlan.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Flight plan deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
