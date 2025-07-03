import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/model.dart';
import '../models/manufacturer.dart';

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
    _typicalServiceCeilingController.text = type.typicalServiceCeiling.toString();
    _fuelConsumptionController.text = type.fuelConsumption?.toString() ?? '';
    _maximumClimbRateController.text = type.maximumClimbRate?.toString() ?? '';
    _maximumDescentRateController.text = type.maximumDescentRate?.toString() ?? '';
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
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppBar(
              title: Text(widget.model == null ? 'Add Model' : 'Edit Model'),
              centerTitle: true,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Model Name',
                          hintText: 'e.g., C172, PA-28',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a model name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Manufacturer dropdown
                      Consumer<AircraftSettingsService>(
                        builder: (context, service, child) {
                          return DropdownButtonFormField<String>(
                            value: _selectedManufacturerId,
                            decoration: const InputDecoration(
                              labelText: 'Manufacturer',
                              border: OutlineInputBorder(),
                            ),
                            items: service.manufacturers.map((manufacturer) {
                              return DropdownMenuItem(
                                value: manufacturer.id,
                                child: Text(manufacturer.name),
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

                      // Category dropdown
                      DropdownButtonFormField<AircraftCategory>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Aircraft Category',
                          border: OutlineInputBorder(),
                        ),
                        items: AircraftCategory.values.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(_getCategoryDisplayName(category)),
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

                      // Engine Count
                      TextFormField(
                        controller: _engineCountController,
                        decoration: const InputDecoration(
                          labelText: 'Engine Count',
                          border: OutlineInputBorder(),
                        ),
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
                      const SizedBox(height: 16),

                      // Max Seats
                      TextFormField(
                        controller: _maxSeatsController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Seats',
                          border: OutlineInputBorder(),
                        ),
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
                      const SizedBox(height: 16),

                      // Typical Cruise Speed
                      TextFormField(
                        controller: _typicalCruiseSpeedController,
                        decoration: const InputDecoration(
                          labelText: 'Typical Cruise Speed (knots)',
                          border: OutlineInputBorder(),
                        ),
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
                      const SizedBox(height: 16),

                      // Typical Service Ceiling
                      TextFormField(
                        controller: _typicalServiceCeilingController,
                        decoration: const InputDecoration(
                          labelText: 'Typical Service Ceiling (feet)',
                          border: OutlineInputBorder(),
                        ),
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
                      const SizedBox(height: 16),

                      // Optional fields header
                      const Text(
                        'Optional Performance Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Fuel Consumption
                      TextFormField(
                        controller: _fuelConsumptionController,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Consumption (gph)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),

                      // Maximum Climb Rate
                      TextFormField(
                        controller: _maximumClimbRateController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Climb Rate (fpm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Maximum Descent Rate
                      TextFormField(
                        controller: _maximumDescentRateController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Descent Rate (fpm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Max Takeoff Weight
                      TextFormField(
                        controller: _maxTakeoffWeightController,
                        decoration: const InputDecoration(
                          labelText: 'Max Takeoff Weight (lbs)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Max Landing Weight
                      TextFormField(
                        controller: _maxLandingWeightController,
                        decoration: const InputDecoration(
                          labelText: 'Max Landing Weight (lbs)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Fuel Capacity
                      TextFormField(
                        controller: _fuelCapacityController,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Capacity (gallons)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveModel,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(widget.model == null ? 'Add' : 'Save'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveModel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = Provider.of<AircraftSettingsService>(context, listen: false);

      if (widget.model == null) {
        // Adding a new model - use the method with individual parameters
        await service.addModel(
          _nameController.text.trim(),
          _selectedManufacturerId!,
          _selectedCategory,
          engineCount: int.parse(_engineCountController.text),
          maxSeats: int.parse(_maxSeatsController.text),
          typicalCruiseSpeed: int.parse(_typicalCruiseSpeedController.text),
          typicalServiceCeiling: int.parse(_typicalServiceCeilingController.text),
          description: _descriptionController.text.trim().isEmpty
              ? null : _descriptionController.text.trim(),
          fuelConsumption: _fuelConsumptionController.text.trim().isEmpty
              ? null : double.tryParse(_fuelConsumptionController.text),
          maximumClimbRate: _maximumClimbRateController.text.trim().isEmpty
              ? null : int.tryParse(_maximumClimbRateController.text),
          maximumDescentRate: _maximumDescentRateController.text.trim().isEmpty
              ? null : int.tryParse(_maximumDescentRateController.text),
          maxTakeoffWeight: _maxTakeoffWeightController.text.trim().isEmpty
              ? null : int.tryParse(_maxTakeoffWeightController.text),
          maxLandingWeight: _maxLandingWeightController.text.trim().isEmpty
              ? null : int.tryParse(_maxLandingWeightController.text),
          fuelCapacity: _fuelCapacityController.text.trim().isEmpty
              ? null : int.tryParse(_fuelCapacityController.text),
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
          typicalServiceCeiling: int.parse(_typicalServiceCeilingController.text),
          description: _descriptionController.text.trim().isEmpty
              ? null : _descriptionController.text.trim(),
          createdAt: widget.model!.createdAt,
          updatedAt: DateTime.now(),
          fuelConsumption: _fuelConsumptionController.text.trim().isEmpty
              ? null : double.tryParse(_fuelConsumptionController.text),
          maximumClimbRate: _maximumClimbRateController.text.trim().isEmpty
              ? null : int.tryParse(_maximumClimbRateController.text),
          maximumDescentRate: _maximumDescentRateController.text.trim().isEmpty
              ? null : int.tryParse(_maximumDescentRateController.text),
          maxTakeoffWeight: _maxTakeoffWeightController.text.trim().isEmpty
              ? null : int.tryParse(_maxTakeoffWeightController.text),
          maxLandingWeight: _maxLandingWeightController.text.trim().isEmpty
              ? null : int.tryParse(_maxLandingWeightController.text),
          fuelCapacity: _fuelCapacityController.text.trim().isEmpty
              ? null : int.tryParse(_fuelCapacityController.text),
        );

        await service.updateModel(model);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.model == null
                ? 'Model added successfully'
                : 'Model updated successfully'),
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
