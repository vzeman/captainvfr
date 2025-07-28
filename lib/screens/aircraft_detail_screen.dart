import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/aircraft.dart';
import '../services/checklist_service.dart';
import '../widgets/checklist_run_dialog.dart';
import '../widgets/aircraft_photos_widget.dart';
import '../widgets/aircraft_documents_widget.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// Detail screen for a specific aircraft, providing tabs for checklists and flight history.
class AircraftDetailScreen extends StatelessWidget {
  /// The aircraft to display details for.
  final Aircraft aircraft;

  const AircraftDetailScreen({super.key, required this.aircraft});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.dialogBackgroundColor,
          title: Text(
            aircraft.name,
            style: const TextStyle(color: AppColors.primaryTextColor),
          ),
          iconTheme: const IconThemeData(color: AppColors.primaryTextColor),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primaryAccent,
            labelColor: AppColors.primaryAccent,
            unselectedLabelColor: AppColors.secondaryTextColor,
            tabs: const [
              Tab(icon: Icon(Icons.info), text: 'Info'),
              Tab(icon: Icon(Icons.photo_library), text: 'Photos'),
              Tab(icon: Icon(Icons.folder), text: 'Documents'),
              Tab(icon: Icon(Icons.list), text: 'Checklists'),
              Tab(icon: Icon(Icons.flight), text: 'Flights'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Info tab
            _buildInfoTab(context),
            // Photos tab
            AircraftPhotosWidget(aircraft: aircraft),
            // Documents tab
            AircraftDocumentsWidget(aircraft: aircraft),
            Consumer<ChecklistService>(
              builder: (context, service, _) {
                final items = service.checklists.where((c) {
                  return c.manufacturerId == aircraft.manufacturerId &&
                      c.modelId == aircraft.modelId;
                }).toList();
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No checklists available for this aircraft',
                      style: TextStyle(color: AppColors.tertiaryTextColor),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final checklist = items[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      color: AppColors.sectionBackgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.defaultRadius,
                        side: BorderSide(color: AppColors.sectionBorderColor),
                      ),
                      child: ListTile(
                        title: Text(
                          checklist.name,
                          style: const TextStyle(color: AppColors.primaryTextColor),
                        ),
                        subtitle: checklist.description != null
                            ? Text(
                                checklist.description!,
                                style: TextStyle(color: AppColors.secondaryTextColor),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow, color: AppColors.primaryAccent),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ChecklistRunDialog(
                                checklist: checklist,
                                aircraftName: aircraft.name,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Center(
              child: Text(
                'Flight history coming soon',
                style: TextStyle(color: AppColors.tertiaryTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.sectionBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.defaultRadius,
              side: BorderSide(color: AppColors.sectionBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aircraft Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Registration', aircraft.registration ?? 'N/A'),
                  _buildInfoRow(
                    'Call Sign',
                    aircraft.callSign ?? aircraft.name,
                  ),
                  _buildInfoRow('Manufacturer', aircraft.manufacturer ?? 'N/A'),
                  _buildInfoRow('Model', aircraft.model ?? 'N/A'),
                  _buildInfoRow('Category', aircraft.category?.name ?? 'N/A'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.sectionBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.defaultRadius,
              side: BorderSide(color: AppColors.sectionBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Cruise Speed',
                    '${aircraft.cruiseSpeed} knots',
                  ),
                  _buildInfoRow(
                    'Fuel Consumption',
                    '${aircraft.fuelConsumption} gal/hr',
                  ),
                  _buildInfoRow(
                    'Maximum Altitude',
                    '${aircraft.maximumAltitude} ft',
                  ),
                  _buildInfoRow(
                    'Max Climb Rate',
                    '${aircraft.maximumClimbRate} ft/min',
                  ),
                  _buildInfoRow(
                    'Max Descent Rate',
                    '${aircraft.maximumDescentRate} ft/min',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.sectionBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.defaultRadius,
              side: BorderSide(color: AppColors.sectionBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weight & Fuel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'Max Takeoff Weight',
                    '${aircraft.maxTakeoffWeight} lbs',
                  ),
                  _buildInfoRow(
                    'Max Landing Weight',
                    '${aircraft.maxLandingWeight} lbs',
                  ),
                  _buildInfoRow(
                    'Fuel Capacity',
                    '${aircraft.fuelCapacity} gal',
                  ),
                ],
              ),
            ),
          ),
          if (aircraft.description != null &&
              aircraft.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.sectionBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: AppTheme.defaultRadius,
                side: BorderSide(color: AppColors.sectionBorderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      aircraft.description!,
                      style: TextStyle(color: AppColors.secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
