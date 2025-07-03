import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/airplane_settings_service.dart';
import '../models/airplane.dart';
import '../models/manufacturer.dart';
import '../widgets/airplane_form_dialog.dart';
import '../widgets/manufacturer_form_dialog.dart';
import 'manufacturer_detail_screen.dart';

class AirplaneSettingsScreen extends StatefulWidget {
  const AirplaneSettingsScreen({super.key});

  @override
  State<AirplaneSettingsScreen> createState() => _AirplaneSettingsScreenState();
}

class _AirplaneSettingsScreenState extends State<AirplaneSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AirplaneSettingsService _airplaneService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _airplaneService = Provider.of<AirplaneSettingsService>(context, listen: false);
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
        title: const Text('Airplane Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.airplanemode_active), text: 'Airplanes'),
            Tab(icon: Icon(Icons.business), text: 'Manufacturers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAirplanesTab(),
          _buildManufacturersTab(),
        ],
      ),
    );
  }

  Widget _buildAirplanesTab() {
    return Consumer<AirplaneSettingsService>(
      builder: (context, service, child) {
        if (service.airplanes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.airplanemode_inactive, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No airplanes configured', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAirplaneForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Airplane'),
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
                      '${service.airplanes.length} airplane(s) configured',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAirplaneForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Airplane'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: service.airplanes.length,
                itemBuilder: (context, index) {
                  final airplane = service.airplanes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          airplane.name.isNotEmpty ? airplane.name[0].toUpperCase() : 'A',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(airplane.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getAirplaneDisplayText(airplane, service)),
                          Text('${airplane.category?.name ?? 'Unknown'} • ${airplane.cruiseSpeed} kts'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAirplaneForm(airplane: airplane);
                          } else if (value == 'delete') {
                            _confirmDeleteAirplane(airplane);
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
                      onTap: () => _showAirplaneDetails(airplane),
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
    return Consumer<AirplaneSettingsService>(
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
                      subtitle: Text('${manufacturer.airplaneTypes.length} types'),
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

  void _showAirplaneForm({Airplane? airplane}) {
    showDialog(
      context: context,
      builder: (context) => AirplaneFormDialog(airplane: airplane),
    );
  }

  void _showManufacturerForm({Manufacturer? manufacturer}) {
    showDialog(
      context: context,
      builder: (context) => ManufacturerFormDialog(manufacturer: manufacturer),
    );
  }

  void _showAirplaneDetails(Airplane airplane) {
    // Navigate to airplane details screen (to be implemented)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Airplane details for ${airplane.name} - Coming soon!')),
    );
  }

  void _confirmDeleteAirplane(Airplane airplane) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Airplane'),
        content: Text('Are you sure you want to delete "${airplane.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _airplaneService.deleteAirplane(airplane.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${airplane.name}"')),
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
        content: Text('Are you sure you want to delete "${manufacturer.name}"? This will also delete all associated airplane types.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _airplaneService.deleteManufacturer(manufacturer.id);
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

  String _getAirplaneDisplayText(Airplane airplane, AirplaneSettingsService service) {
    final manufacturer = service.manufacturers.firstWhere((m) => m.id == airplane.manufacturerId, orElse: () => Manufacturer.empty());
    return '${manufacturer.name} ${airplane.model}';
  }
}
