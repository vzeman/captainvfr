import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/airplane_settings_service.dart';
import '../models/manufacturer.dart';
import '../models/airplane_type.dart';
import '../widgets/manufacturer_form_dialog.dart';
import '../widgets/airplane_type_form_dialog.dart';

class ManufacturerDetailScreen extends StatelessWidget {
  final Manufacturer manufacturer;

  const ManufacturerDetailScreen({
    super.key,
    required this.manufacturer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(manufacturer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showManufacturerForm(context),
          ),
        ],
      ),
      body: Consumer<AirplaneSettingsService>(
        builder: (context, service, child) {
          // Get the latest manufacturer data
          final currentManufacturer = service.manufacturers
              .firstWhere((m) => m.id == manufacturer.id, orElse: () => manufacturer);

          // Get airplane types for this manufacturer
          final manufacturerTypes = service.airplaneTypes
              .where((type) => currentManufacturer.airplaneTypes.contains(type.id))
              .toList();

          return Column(
            children: [
              // Manufacturer Info Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            radius: 30,
                            child: Text(
                              currentManufacturer.name.isNotEmpty
                                  ? currentManufacturer.name[0].toUpperCase()
                                  : 'M',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentManufacturer.name,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentManufacturer.country ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (currentManufacturer.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        Text(
                          currentManufacturer.description ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.category, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${manufacturerTypes.length} airplane type(s)',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Airplane Types Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Airplane Types',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAirplaneTypeForm(context, currentManufacturer),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Type'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Airplane Types List
              Expanded(
                child: manufacturerTypes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No airplane types yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add the first airplane type for ${currentManufacturer.name}',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAirplaneTypeForm(context, currentManufacturer),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Type'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: manufacturerTypes.length,
                        itemBuilder: (context, index) {
                          final type = manufacturerTypes[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  type.name.isNotEmpty ? type.name[0].toUpperCase() : 'T',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(type.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Category: ${type.category.name}'),
                                  Text('${type.engineCount} engine(s)'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showAirplaneTypeForm(context, currentManufacturer, type: type);
                                  } else if (value == 'delete') {
                                    _confirmDeleteAirplaneType(context, type, currentManufacturer);
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
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showManufacturerForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ManufacturerFormDialog(manufacturer: manufacturer),
    );
  }

  void _showAirplaneTypeForm(BuildContext context, Manufacturer manufacturer, {AirplaneType? type}) {
    showDialog(
      context: context,
      builder: (context) => AirplaneTypeFormDialog(
        airplaneType: type,
        manufacturer: manufacturer,
      ),
    );
  }

  void _confirmDeleteAirplaneType(BuildContext context, AirplaneType type, Manufacturer manufacturer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Airplane Type'),
        content: Text('Are you sure you want to delete "${type.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final service = Provider.of<AirplaneSettingsService>(context, listen: false);
              service.deleteAirplaneType(type.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${type.name}"')),
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
