import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';
import '../utils/form_theme_helper.dart';

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
      final flightPlanService = Provider.of<FlightPlanService>(
        context,
        listen: false,
      );
      flightPlanService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Flight Plans',
          style: TextStyle(color: FormThemeHelper.primaryTextColor),
        ),
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        foregroundColor: FormThemeHelper.primaryTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewFlightPlanDialog(context),
          ),
        ],
      ),
      backgroundColor: FormThemeHelper.backgroundColor,
      body: Consumer<FlightPlanService>(
        builder: (context, flightPlanService, child) {
          final flightPlans = flightPlanService.savedFlightPlans;

          if (flightPlans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flight_takeoff, size: 64, color: FormThemeHelper.secondaryTextColor),
                  const SizedBox(height: 16),
                  Text(
                    'No flight plans yet',
                    style: TextStyle(fontSize: 18, color: FormThemeHelper.secondaryTextColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first flight plan to get started',
                    style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: flightPlans.length,
            itemBuilder: (context, index) {
              final flightPlan = flightPlans[index];
              return _buildFlightPlanCard(
                context,
                flightPlan,
                flightPlanService,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFlightPlanCard(
    BuildContext context,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: FormThemeHelper.sectionBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FormThemeHelper.sectionBorderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _loadFlightPlanAndNavigateBack(
          context,
          flightPlan,
          flightPlanService,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: FormThemeHelper.primaryAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.flight_takeoff, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flightPlan.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: FormThemeHelper.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getFlightPlanSummary(flightPlan),
                      style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${_formatDate(flightPlan.createdAt)}',
                      style: TextStyle(color: FormThemeHelper.secondaryTextColor, fontSize: 12),
                    ),
                    if (flightPlan.modifiedAt != null)
                      Text(
                        'Modified: ${_formatDate(flightPlan.modifiedAt!)}',
                        style: TextStyle(color: FormThemeHelper.secondaryTextColor, fontSize: 12),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: FormThemeHelper.dialogBackgroundColor,
                icon: Icon(Icons.more_vert, color: FormThemeHelper.secondaryTextColor),
                onSelected: (value) =>
                    _handleMenuAction(context, value, flightPlan, flightPlanService),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'load',
                    child: Row(
                      children: [
                        Icon(Icons.map, size: 20, color: FormThemeHelper.primaryTextColor),
                        const SizedBox(width: 8),
                        Text('Load to Map', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20, color: FormThemeHelper.primaryTextColor),
                        const SizedBox(width: 8),
                        Text('Edit Name', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 20, color: FormThemeHelper.primaryTextColor),
                        const SizedBox(width: 8),
                        Text('Duplicate', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
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
            ],
          ),
        ),
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

  void _handleMenuAction(
    BuildContext context,
    String action,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
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

  void _loadFlightPlanAndNavigateBack(
    BuildContext context,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
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
    // Generate default name with random number
    final randomNum = DateTime.now().millisecondsSinceEpoch % 1000;
    final defaultName = 'Flight Plan $randomNum';
    final controller = TextEditingController(text: defaultName);

    // Select all text when dialog opens
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    showDialog(
      context: context,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: 'New Flight Plan',
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: FormThemeHelper.buildFormField(
            controller: controller,
            labelText: 'Flight Plan Name',
            hintText: 'Enter flight plan name',
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
              flightPlanService.startNewFlightPlan(
                name: controller.text.trim(),
              );
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to map
            },
            style: FormThemeHelper.getPrimaryButtonStyle(),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(
    BuildContext context,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    final controller = TextEditingController(text: flightPlan.name);
    showDialog(
      context: context,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: 'Edit Flight Plan Name',
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: FormThemeHelper.buildFormField(
            controller: controller,
            labelText: 'Flight Plan Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FormThemeHelper.getSecondaryButtonStyle(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
            style: FormThemeHelper.getPrimaryButtonStyle(),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _duplicateFlightPlan(
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    flightPlanService.duplicateFlightPlan(flightPlan.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flight plan duplicated'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    showDialog(
      context: context,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: 'Delete Flight Plan',
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Are you sure you want to delete "${flightPlan.name}"?',
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
              flightPlanService.deleteFlightPlan(flightPlan.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Flight plan deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}