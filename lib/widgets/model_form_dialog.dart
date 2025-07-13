import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/model.dart';
import '../models/manufacturer.dart';
import '../utils/form_theme_helper.dart';

class ModelFormDialog extends StatefulWidget {
  final Model? model;
  final Manufacturer? manufacturer;

  const ModelFormDialog({super.key, this.model, this.manufacturer});

  @override
  State<ModelFormDialog> createState() => _ModelFormDialogState();
}

class _ModelFormDialogState extends State<ModelFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _engineCountController = TextEditingController();
  final _maxSeatsController = TextEditingController();
  final _typicalCruiseSpeedController = TextEditingController();
  final _typicalServiceCeilingController = TextEditingController();
  final _fuelConsumptionController = TextEditingController();
  final _maximumClimbRateController = TextEditingController();
  final _maximumDescentRateController = TextEditingController();
  final _maxTakeoffWeightController = TextEditingController();
  final _maxLandingWeightController = TextEditingController();
  final _fuelCapacityController = TextEditingController();

  AircraftCategory _selectedCategory = AircraftCategory.singleEngine;
  String? _selectedManufacturerId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedManufacturerId = widget.manufacturer?.id;

    if (widget.model != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final type = widget.model!;
    _nameController.text = type.name;
    _descriptionController.text = type.description ?? '';
    _engineCountController.text = type.engineCount.toString();
    _maxSeatsController.text = type.maxSeats.toString();
    _typicalCruiseSpeedController.text = type.typicalCruiseSpeed.toString();
    _typicalServiceCeilingController.text = type.typicalServiceCeiling
        .toString();
    _fuelConsumptionController.text = type.fuelConsumption?.toString() ?? '';
    _maximumClimbRateController.text = type.maximumClimbRate?.toString() ?? '';
    _maximumDescentRateController.text =
        type.maximumDescentRate?.toString() ?? '';
    _maxTakeoffWeightController.text = type.maxTakeoffWeight?.toString() ?? '';
    _maxLandingWeightController.text = type.maxLandingWeight?.toString() ?? '';
    _fuelCapacityController.text = type.fuelCapacity?.toString() ?? '';
    _selectedCategory = type.category;
    _selectedManufacturerId = type.manufacturerId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _engineCountController.dispose();
    _maxSeatsController.dispose();
    _typicalCruiseSpeedController.dispose();
    _typicalServiceCeilingController.dispose();
    _fuelConsumptionController.dispose();
    _maximumClimbRateController.dispose();
    _maximumDescentRateController.dispose();
    _maxTakeoffWeightController.dispose();
    _maxLandingWeightController.dispose();
    _fuelCapacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormThemeHelper.buildDialog(
      context: context,
      title: widget.model == null ? 'Add Model' : 'Edit Model',
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormThemeHelper.buildSection(
                title: 'Basic Information',
                children: [
                FormThemeHelper.buildFormField(
                  controller: _nameController,
                  labelText: 'Model Name *',
                  hintText: 'e.g., C172, PA-28',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a model name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Consumer<AircraftSettingsService>(
                  builder: (context, service, child) {
                    return FormThemeHelper.buildDropdownField<String>(
                      value: _selectedManufacturerId,
                      labelText: 'Manufacturer *',
                      items: service.manufacturers.map((manufacturer) {
                        return DropdownMenuItem(
                          value: manufacturer.id,
                          child: Text(manufacturer.name, style: FormThemeHelper.inputTextStyle),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedManufacturerId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a manufacturer';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                FormThemeHelper.buildDropdownField<AircraftCategory>(
                  value: _selectedCategory,
                  labelText: 'Aircraft Category *',
                  items: AircraftCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_getCategoryDisplayName(category), style: FormThemeHelper.inputTextStyle),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FormThemeHelper.buildFormField(
                        controller: _engineCountController,
                        labelText: 'Engine Count *',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter engine count';
                          }
                          final count = int.tryParse(value);
                          if (count == null || count < 1) {
                            return 'Please enter a valid engine count';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FormThemeHelper.buildFormField(
                        controller: _maxSeatsController,
                        labelText: 'Maximum Seats *',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter maximum seats';
                          }
                          final seats = int.tryParse(value);
                          if (seats == null || seats < 1) {
                            return 'Please enter a valid seat count';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FormThemeHelper.buildFormField(
                        controller: _typicalCruiseSpeedController,
                        labelText: 'Typical Cruise Speed (kts) *',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter cruise speed';
                          }
                          final speed = int.tryParse(value);
                          if (speed == null || speed < 1) {
                            return 'Please enter a valid speed';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FormThemeHelper.buildFormField(
                        controller: _typicalServiceCeilingController,
                        labelText: 'Service Ceiling (ft) *',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter service ceiling';
                          }
                          final ceiling = int.tryParse(value);
                          if (ceiling == null || ceiling < 1) {
                            return 'Please enter a valid ceiling';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                FormThemeHelper.buildFormField(
                  controller: _descriptionController,
                  labelText: 'Description',
                  maxLines: 3,
                ),
              ],
              ),
              const SizedBox(height: 16),
              FormThemeHelper.buildSection(
                title: 'Optional Performance Data',
                children: [
                  FormThemeHelper.buildFormField(
                    controller: _fuelConsumptionController,
                    labelText: 'Fuel Consumption (gph)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FormThemeHelper.buildFormField(
                          controller: _maximumClimbRateController,
                          labelText: 'Max Climb Rate (fpm)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FormThemeHelper.buildFormField(
                          controller: _maximumDescentRateController,
                          labelText: 'Max Descent Rate (fpm)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FormThemeHelper.buildFormField(
                          controller: _maxTakeoffWeightController,
                          labelText: 'Max Takeoff Weight (lbs)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FormThemeHelper.buildFormField(
                          controller: _maxLandingWeightController,
                          labelText: 'Max Landing Weight (lbs)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FormThemeHelper.buildFormField(
                    controller: _fuelCapacityController,
                    labelText: 'Fuel Capacity (gallons)',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
          ],
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: FormThemeHelper.getSecondaryButtonStyle(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveModel,
          style: FormThemeHelper.getPrimaryButtonStyle(),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.model == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _saveModel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = Provider.of<AircraftSettingsService>(
        context,
        listen: false,
      );

      if (widget.model == null) {
        // Adding a new model - use the method with individual parameters
        await service.addModel(
          _nameController.text.trim(),
          _selectedManufacturerId!,
          _selectedCategory,
          engineCount: int.parse(_engineCountController.text),
          maxSeats: int.parse(_maxSeatsController.text),
          typicalCruiseSpeed: int.parse(_typicalCruiseSpeedController.text),
          typicalServiceCeiling: int.parse(
            _typicalServiceCeilingController.text,
          ),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          fuelConsumption: _fuelConsumptionController.text.trim().isEmpty
              ? null
              : double.tryParse(_fuelConsumptionController.text),
          maximumClimbRate: _maximumClimbRateController.text.trim().isEmpty
              ? null
              : int.tryParse(_maximumClimbRateController.text),
          maximumDescentRate: _maximumDescentRateController.text.trim().isEmpty
              ? null
              : int.tryParse(_maximumDescentRateController.text),
          maxTakeoffWeight: _maxTakeoffWeightController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxTakeoffWeightController.text),
          maxLandingWeight: _maxLandingWeightController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxLandingWeightController.text),
          fuelCapacity: _fuelCapacityController.text.trim().isEmpty
              ? null
              : int.tryParse(_fuelCapacityController.text),
        );
      } else {
        // Updating existing model - create Model object
        final model = Model(
          id: widget.model!.id,
          name: _nameController.text.trim(),
          manufacturerId: _selectedManufacturerId!,
          category: _selectedCategory,
          engineCount: int.parse(_engineCountController.text),
          maxSeats: int.parse(_maxSeatsController.text),
          typicalCruiseSpeed: int.parse(_typicalCruiseSpeedController.text),
          typicalServiceCeiling: int.parse(
            _typicalServiceCeilingController.text,
          ),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          createdAt: widget.model!.createdAt,
          updatedAt: DateTime.now(),
          fuelConsumption: _fuelConsumptionController.text.trim().isEmpty
              ? null
              : double.tryParse(_fuelConsumptionController.text),
          maximumClimbRate: _maximumClimbRateController.text.trim().isEmpty
              ? null
              : int.tryParse(_maximumClimbRateController.text),
          maximumDescentRate: _maximumDescentRateController.text.trim().isEmpty
              ? null
              : int.tryParse(_maximumDescentRateController.text),
          maxTakeoffWeight: _maxTakeoffWeightController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxTakeoffWeightController.text),
          maxLandingWeight: _maxLandingWeightController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxLandingWeightController.text),
          fuelCapacity: _fuelCapacityController.text.trim().isEmpty
              ? null
              : int.tryParse(_fuelCapacityController.text),
        );

        await service.updateModel(model);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.model == null
                  ? 'Model added successfully'
                  : 'Model updated successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving model: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
