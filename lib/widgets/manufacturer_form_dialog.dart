import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/manufacturer.dart';
import '../utils/form_theme_helper.dart';

class ManufacturerFormDialog extends StatefulWidget {
  final Manufacturer? manufacturer;

  const ManufacturerFormDialog({super.key, this.manufacturer});

  @override
  State<ManufacturerFormDialog> createState() => _ManufacturerFormDialogState();
}

class _ManufacturerFormDialogState extends State<ManufacturerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.manufacturer != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final manufacturer = widget.manufacturer!;
    _nameController.text = manufacturer.name;
    _websiteController.text = manufacturer.website ?? '';
    _descriptionController.text = manufacturer.description ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormThemeHelper.buildDialog(
      context: context,
      title: widget.manufacturer == null ? 'Add Manufacturer' : 'Edit Manufacturer',
      width: MediaQuery.of(context).size.width * 0.8,
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormThemeHelper.buildFormField(
                controller: _nameController,
                labelText: 'Manufacturer Name *',
                hintText: 'e.g., Cessna Aircraft Company',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a manufacturer name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FormThemeHelper.buildFormField(
                controller: _websiteController,
                labelText: 'Website',
                hintText: 'e.g., https://www.cessna.com',
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final uri = Uri.tryParse(value);
                    if (uri == null || (!uri.scheme.startsWith('http'))) {
                      return 'Please enter a valid URL';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FormThemeHelper.buildFormField(
                controller: _descriptionController,
                labelText: 'Description',
                hintText: 'Brief description of the manufacturer',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: FormThemeHelper.getSecondaryButtonStyle(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveManufacturer,
          style: FormThemeHelper.getPrimaryButtonStyle(),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.manufacturer == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _saveManufacturer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = Provider.of<AircraftSettingsService>(
        context,
        listen: false,
      );

      final manufacturer = Manufacturer(
        id:
            widget.manufacturer?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        models: widget.manufacturer?.models ?? [],
        createdAt: widget.manufacturer?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.manufacturer == null) {
        await service.addManufacturer(
          _nameController.text.trim(),
          website: _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
        );
      } else {
        await service.updateManufacturer(manufacturer);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.manufacturer == null
                  ? 'Manufacturer "${manufacturer.name}" added successfully'
                  : 'Manufacturer "${manufacturer.name}" updated successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving manufacturer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
