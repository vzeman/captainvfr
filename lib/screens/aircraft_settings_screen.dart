import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/aircraft.dart';
import '../models/model.dart';
import '../models/manufacturer.dart';
import '../widgets/aircraft_form_dialog.dart';
import '../widgets/manufacturer_form_dialog.dart';
import 'manufacturer_detail_screen.dart';

class AircraftSettingsScreen extends StatefulWidget {
  const AircraftSettingsScreen({super.key});

  @override
  State<AircraftSettingsScreen> createState() => _AircraftSettingsScreenState();
}

class _AircraftSettingsScreenState extends State<AircraftSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AircraftSettingsService _aircraftService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _aircraftService = Provider.of<AircraftSettingsService>(context, listen: false);
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
        title: const Text('Aircraft Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.airplanemode_active), text: 'Aircraft'),
            Tab(icon: Icon(Icons.business), text: 'Manufacturers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAircraftTab(),
          _buildManufacturersTab(),
        ],
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
                const Icon(Icons.airplanemode_inactive, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No aircraft configured', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAircraftForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Aircraft'),
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAircraftForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Aircraft'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: service.aircrafts.length,
                itemBuilder: (context, index) {
                  final aircraft = service.aircrafts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          aircraft.name.isNotEmpty ? aircraft.name[0].toUpperCase() : 'A',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(aircraft.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getAircraftDisplayText(aircraft, service)),
                          Text('${_getCategoryDisplayName(aircraft.category)} • ${aircraft.cruiseSpeed} kts'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
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
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
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
                const Icon(Icons.business, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No manufacturers configured', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showManufacturerForm(),
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showManufacturerForm(),
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
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          manufacturer.name.isNotEmpty ? manufacturer.name[0].toUpperCase() : 'M',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(manufacturer.name),
                      subtitle: Text('${manufacturer.models.length} models'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showManufacturerForm(manufacturer: manufacturer);
                          } else if (value == 'delete') {
                            _confirmDeleteManufacturer(manufacturer);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Edit'),
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
    // Navigate to aircraft details screen (to be implemented)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aircraft details for ${aircraft.name} - Coming soon!')),
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
        content: Text('Are you sure you want to delete "${manufacturer.name}"? This will also delete all associated models.'),
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
        builder: (context) => ManufacturerDetailScreen(manufacturer: manufacturer),
      ),
    );
  }

  String _getAircraftDisplayText(Aircraft aircraft, AircraftSettingsService service) {
    final manufacturer = service.manufacturers.firstWhere((m) => m.id == aircraft.manufacturerId, orElse: () => Manufacturer.empty());
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
