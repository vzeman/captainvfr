import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/aircraft.dart';
import '../models/model.dart';
import '../models/manufacturer.dart';
import '../widgets/aircraft_form_dialog.dart';
import '../widgets/manufacturer_form_dialog.dart';
import 'aircraft_detail_screen.dart';
import 'manufacturer_detail_screen.dart';
import '../utils/form_theme_helper.dart';

class AircraftSettingsScreen extends StatefulWidget {
  const AircraftSettingsScreen({super.key});

  @override
  State<AircraftSettingsScreen> createState() => _AircraftSettingsScreenState();
}

class _AircraftSettingsScreenState extends State<AircraftSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AircraftSettingsService _aircraftService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _aircraftService = Provider.of<AircraftSettingsService>(
      context,
      listen: false,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Aircraft Settings',
          style: TextStyle(color: FormThemeHelper.primaryTextColor),
        ),
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        foregroundColor: FormThemeHelper.primaryTextColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FormThemeHelper.primaryAccent,
          labelColor: FormThemeHelper.primaryTextColor,
          unselectedLabelColor: FormThemeHelper.secondaryTextColor,
          tabs: const [
            Tab(icon: Icon(Icons.airplanemode_active), text: 'Aircraft'),
            Tab(icon: Icon(Icons.business), text: 'Manufacturers'),
          ],
        ),
      ),
      backgroundColor: FormThemeHelper.backgroundColor,
      body: TabBarView(
        controller: _tabController,
        children: [_buildAircraftTab(), _buildManufacturersTab()],
      ),
    );
  }

  Widget _buildAircraftTab() {
    return Consumer<AircraftSettingsService>(
      builder: (context, service, child) {
        if (service.aircrafts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.airplanemode_inactive,
                  size: 64,
                  color: Colors.white54,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No aircraft configured',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAircraftForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Aircraft'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF448AFF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${service.aircrafts.length} aircraft configured',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAircraftForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Aircraft'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF448AFF),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: service.aircrafts.length,
                itemBuilder: (context, index) {
                  final aircraft = service.aircrafts[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1A448AFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x7F448AFF)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF448AFF),
                        child: Text(
                          aircraft.name.isNotEmpty
                              ? aircraft.name[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        aircraft.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getAircraftDisplayText(aircraft, service),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            '${_getCategoryDisplayName(aircraft.category)} • ${aircraft.cruiseSpeed} kts',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        iconColor: Colors.white70,
                        color: const Color(0xE6000000),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAircraftForm(aircraft: aircraft);
                          } else if (value == 'delete') {
                            _confirmDeleteAircraft(aircraft);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20, color: Colors.white70),
                                SizedBox(width: 8),
                                Text(
                                  'Edit',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showAircraftDetails(aircraft),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManufacturersTab() {
    return Consumer<AircraftSettingsService>(
      builder: (context, service, child) {
        if (service.manufacturers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.business,
                  size: 64,
                  color: FormThemeHelper.primaryAccent.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No manufacturers configured',
                  style: TextStyle(
                    fontSize: 18,
                    color: FormThemeHelper.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showManufacturerForm(),
                  style: FormThemeHelper.getPrimaryButtonStyle(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Manufacturer'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${service.manufacturers.length} manufacturer(s) configured',
                      style: TextStyle(
                        fontSize: 16,
                        color: FormThemeHelper.primaryTextColor,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showManufacturerForm(),
                    style: FormThemeHelper.getPrimaryButtonStyle(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Manufacturer'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: service.manufacturers.length,
                itemBuilder: (context, index) {
                  final manufacturer = service.manufacturers[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: FormThemeHelper.sectionBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FormThemeHelper.sectionBorderColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: FormThemeHelper.primaryAccent,
                        child: Text(
                          manufacturer.name.isNotEmpty
                              ? manufacturer.name[0].toUpperCase()
                              : 'M',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        manufacturer.name,
                        style: TextStyle(
                          color: FormThemeHelper.primaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${manufacturer.models.length} models',
                        style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: FormThemeHelper.primaryTextColor,
                        ),
                        color: FormThemeHelper.dialogBackgroundColor,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showManufacturerForm(manufacturer: manufacturer);
                          } else if (value == 'delete') {
                            _confirmDeleteManufacturer(manufacturer);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20, color: FormThemeHelper.primaryTextColor),
                                const SizedBox(width: 8),
                                Text('Edit', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showManufacturerDetails(manufacturer),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAircraftForm({Aircraft? aircraft}) {
    showDialog(
      context: context,
      builder: (context) => AircraftFormDialog(aircraft: aircraft),
    );
  }

  void _showManufacturerForm({Manufacturer? manufacturer}) {
    showDialog(
      context: context,
      builder: (context) => ManufacturerFormDialog(manufacturer: manufacturer),
    );
  }

  void _showAircraftDetails(Aircraft aircraft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AircraftDetailScreen(aircraft: aircraft),
      ),
    );
  }

  void _confirmDeleteAircraft(Aircraft aircraft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Aircraft'),
        content: Text('Are you sure you want to delete "${aircraft.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _aircraftService.deleteAircraft(aircraft.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${aircraft.name}"')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteManufacturer(Manufacturer manufacturer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Manufacturer'),
        content: Text(
          'Are you sure you want to delete "${manufacturer.name}"? This will also delete all associated models.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _aircraftService.deleteManufacturer(manufacturer.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${manufacturer.name}"')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showManufacturerDetails(Manufacturer manufacturer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ManufacturerDetailScreen(manufacturer: manufacturer),
      ),
    );
  }

  String _getAircraftDisplayText(
    Aircraft aircraft,
    AircraftSettingsService service,
  ) {
    final manufacturer = service.manufacturers.firstWhere(
      (m) => m.id == aircraft.manufacturerId,
      orElse: () => Manufacturer.empty(),
    );
    return '${manufacturer.name} ${aircraft.model}';
  }

  String _getCategoryDisplayName(AircraftCategory? category) {
    if (category == null) return 'Unknown';
    switch (category) {
      case AircraftCategory.singleEngine:
        return 'Single Engine';
      case AircraftCategory.multiEngine:
        return 'Multi Engine';
      case AircraftCategory.jet:
        return 'Jet';
      case AircraftCategory.helicopter:
        return 'Helicopter';
      case AircraftCategory.glider:
        return 'Glider';
      case AircraftCategory.turboprop:
        return 'Turboprop';
    }
  }
}
