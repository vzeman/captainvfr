import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/manufacturer.dart';
import '../models/model.dart';
import '../widgets/manufacturer_form_dialog.dart';
import '../widgets/model_form_dialog.dart';
import '../utils/form_theme_helper.dart';

class ManufacturerDetailScreen extends StatelessWidget {
  final Manufacturer manufacturer;

  const ManufacturerDetailScreen({super.key, required this.manufacturer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FormThemeHelper.backgroundColor,
      appBar: AppBar(
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        title: Text(
          manufacturer.name,
          style: const TextStyle(color: FormThemeHelper.primaryTextColor),
        ),
        foregroundColor: FormThemeHelper.primaryTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showManufacturerForm(context),
          ),
        ],
      ),
      body: Consumer<AircraftSettingsService>(
        builder: (context, service, child) {
          // Get the latest manufacturer data
          final currentManufacturer = service.manufacturers.firstWhere(
            (m) => m.id == manufacturer.id,
            orElse: () => manufacturer,
          );

          // Get models for this manufacturer
          final manufacturerModels = service.models
              .where((model) => currentManufacturer.models.contains(model.id))
              .toList();

          return Column(
            children: [
              // Manufacturer Info Section
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FormThemeHelper.sectionBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FormThemeHelper.sectionBorderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: FormThemeHelper.primaryAccent,
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
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: FormThemeHelper.primaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (currentManufacturer.description?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 16),
                        Text(
                          currentManufacturer.description ?? '',
                          style: TextStyle(
                            color: FormThemeHelper.secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.category,
                            color: FormThemeHelper.primaryAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${manufacturerModels.length} model(s)',
                            style: TextStyle(
                              color: FormThemeHelper.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Models Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Models',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: FormThemeHelper.primaryTextColor,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showModelForm(context, currentManufacturer),
                      style: FormThemeHelper.getPrimaryButtonStyle(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Model'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Models List
              Expanded(
                child: manufacturerModels.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 64,
                              color: FormThemeHelper.primaryAccent.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No models yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: FormThemeHelper.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add the first model for ${currentManufacturer.name}',
                              style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _showModelForm(context, currentManufacturer),
                              style: FormThemeHelper.getPrimaryButtonStyle(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Model'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: manufacturerModels.length,
                        itemBuilder: (context, index) {
                          final model = manufacturerModels[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: FormThemeHelper.sectionBackgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: FormThemeHelper.sectionBorderColor),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: FormThemeHelper.primaryAccent.withValues(alpha: 0.2),
                                child: Text(
                                  model.name.isNotEmpty
                                      ? model.name[0].toUpperCase()
                                      : 'M',
                                  style: TextStyle(
                                    color: FormThemeHelper.primaryAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                model.name,
                                style: TextStyle(
                                  color: FormThemeHelper.primaryTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Category: ${_getCategoryDisplayName(model.category)}',
                                    style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                                  ),
                                  Text(
                                    '${model.engineCount} engine(s)',
                                    style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: FormThemeHelper.primaryTextColor,
                                ),
                                color: FormThemeHelper.dialogBackgroundColor,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showModelForm(
                                      context,
                                      currentManufacturer,
                                      model: model,
                                    );
                                  } else if (value == 'delete') {
                                    _confirmDeleteModel(
                                      context,
                                      model,
                                      currentManufacturer,
                                    );
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
                                        Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
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

  void _showModelForm(
    BuildContext context,
    Manufacturer manufacturer, {
    Model? model,
  }) {
    showDialog(
      context: context,
      builder: (context) =>
          ModelFormDialog(model: model, manufacturer: manufacturer),
    );
  }

  void _confirmDeleteModel(
    BuildContext context,
    Model model,
    Manufacturer manufacturer,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete "${model.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final service = Provider.of<AircraftSettingsService>(
                context,
                listen: false,
              );
              service.deleteModel(model.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${model.name}"')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getCategoryDisplayName(AircraftCategory category) {
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
