import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/aircraft.dart';
import '../models/manufacturer.dart';
import '../models/model.dart';

class AircraftFormDialog extends StatefulWidget {
  final Aircraft? aircraft;

  const AircraftFormDialog({super.key, this.aircraft});

  @override
  State<AircraftFormDialog> createState() => _AircraftFormDialogState();
}

class _AircraftFormDialogState extends State<AircraftFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _registrationController = TextEditingController();
  final _cruiseSpeedController = TextEditingController();
  final _fuelConsumptionController = TextEditingController();
  final _maxAltitudeController = TextEditingController();
  final _maxClimbRateController = TextEditingController();
  final _maxDescentRateController = TextEditingController();
  final _maxTakeoffWeightController = TextEditingController();
  final _maxLandingWeightController = TextEditingController();
  final _fuelCapacityController = TextEditingController();

  Manufacturer? _selectedManufacturer;
  Model? _selectedModel;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.aircraft != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final aircraft = widget.aircraft!;
    _nameController.text = aircraft.name;
    _registrationController.text = aircraft.registration ?? '';
    _cruiseSpeedController.text = aircraft.cruiseSpeed.toString();
    _fuelConsumptionController.text = aircraft.fuelConsumption.toString();
    _maxAltitudeController.text = aircraft.maximumAltitude.toString();
    _maxClimbRateController.text = aircraft.maximumClimbRate.toString();
    _maxDescentRateController.text = aircraft.maximumDescentRate.toString();
    _maxTakeoffWeightController.text = aircraft.maxTakeoffWeight.toString();
    _maxLandingWeightController.text = aircraft.maxLandingWeight.toString();
    _fuelCapacityController.text = aircraft.fuelCapacity.toString();

    // Find manufacturer and model from the service using IDs
    final service = Provider.of<AircraftSettingsService>(context, listen: false);
    try {
      _selectedManufacturer = service.manufacturers.firstWhere(
        (m) => m.id == aircraft.manufacturerId,
      );
    } catch (e) {
      _selectedManufacturer = service.manufacturers.isNotEmpty ? service.manufacturers.first : null;
    }

    if (_selectedManufacturer != null) {
      final models = service.getModelsForManufacturer(_selectedManufacturer!.id);
      try {
        _selectedModel = models.firstWhere(
          (m) => m.id == aircraft.modelId,
        );
      } catch (e) {
        _selectedModel = models.isNotEmpty ? models.first : null;
      }
    }
  }

  void _copyPerformanceFromModel(Model model) {
    // Copy performance specifications from model if they exist
    if (model.typicalCruiseSpeed > 0) {
      _cruiseSpeedController.text = model.typicalCruiseSpeed.toString();
    }
    if (model.typicalServiceCeiling > 0) {
      _maxAltitudeController.text = model.typicalServiceCeiling.toString();
    }
    if (model.fuelConsumption != null && model.fuelConsumption! > 0) {
      _fuelConsumptionController.text = model.fuelConsumption.toString();
    }
    if (model.maximumClimbRate != null && model.maximumClimbRate! > 0) {
      _maxClimbRateController.text = model.maximumClimbRate.toString();
    }
    if (model.maximumDescentRate != null && model.maximumDescentRate! > 0) {
      _maxDescentRateController.text = model.maximumDescentRate.toString();
    }
    if (model.maxTakeoffWeight != null && model.maxTakeoffWeight! > 0) {
      _maxTakeoffWeightController.text = model.maxTakeoffWeight.toString();
    }
    if (model.maxLandingWeight != null && model.maxLandingWeight! > 0) {
      _maxLandingWeightController.text = model.maxLandingWeight.toString();
    }
    if (model.fuelCapacity != null && model.fuelCapacity! > 0) {
      _fuelCapacityController.text = model.fuelCapacity.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _cruiseSpeedController.dispose();
    _fuelConsumptionController.dispose();
    _maxAltitudeController.dispose();
    _maxClimbRateController.dispose();
    _maxDescentRateController.dispose();
    _maxTakeoffWeightController.dispose();
    _maxLandingWeightController.dispose();
    _fuelCapacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AircraftSettingsService>(
      builder: (context, service, child) {
        return AlertDialog(
          title: Text(widget.aircraft == null ? 'Add Aircraft' : 'Edit Aircraft'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Basic Information Section
                    const Text(
                      'Basic Information',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Aircraft Name *',
                        hintText: 'e.g., My Cessna 172',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an aircraft name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _registrationController,
                      decoration: const InputDecoration(
                        labelText: 'Registration',
                        hintText: 'e.g., N123AB',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Manufacturer Selection
                    DropdownButtonFormField<Manufacturer>(
                      value: _selectedManufacturer,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer *',
                        border: OutlineInputBorder(),
                      ),
                      items: service.manufacturers.map((manufacturer) {
                        return DropdownMenuItem(
                          value: manufacturer,
                          child: Text(manufacturer.name),
                        );
                      }).toList(),
                      onChanged: (manufacturer) {
                        setState(() {
                          _selectedManufacturer = manufacturer;
                          _selectedModel = null; // Reset model selection
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a manufacturer';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Model Selection
                    DropdownButtonFormField<Model>(
                      value: _selectedModel,
                      decoration: const InputDecoration(
                        labelText: 'Model *',
                        border: OutlineInputBorder(),
                      ),
                      items: _selectedManufacturer?.models.map((modelId) {
                        final model = Provider.of<AircraftSettingsService>(context, listen: false)
                            .models.firstWhere((m) => m.id == modelId);
                        return DropdownMenuItem<Model>(
                          value: model,
                          child: Text(model.name),
                        );
                      }).toList() ?? [],
                      onChanged: (model) {
                        setState(() {
                          _selectedModel = model;
                          // Auto-set performance specifications based on model
                          if (model != null) {
                            _copyPerformanceFromModel(model);
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a model';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Performance Section
                    const Text(
                      'Performance Specifications',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cruiseSpeedController,
                            decoration: const InputDecoration(
                              labelText: 'Cruise Speed (kts) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final speed = int.tryParse(value);
                              if (speed == null || speed <= 0) {
                                return 'Invalid speed';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _fuelConsumptionController,
                            decoration: const InputDecoration(
                              labelText: 'Fuel Consumption (GPH) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final consumption = double.tryParse(value);
                              if (consumption == null || consumption <= 0) {
                                return 'Invalid consumption';
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
                          child: TextFormField(
                            controller: _maxAltitudeController,
                            decoration: const InputDecoration(
                              labelText: 'Max Altitude (ft) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final altitude = int.tryParse(value);
                              if (altitude == null || altitude <= 0) {
                                return 'Invalid altitude';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _fuelCapacityController,
                            decoration: const InputDecoration(
                              labelText: 'Fuel Capacity (gal) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final capacity = int.tryParse(value);
                              if (capacity == null || capacity <= 0) {
                                return 'Invalid capacity';
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
                          child: TextFormField(
                            controller: _maxClimbRateController,
                            decoration: const InputDecoration(
                              labelText: 'Max Climb Rate (fpm) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final rate = int.tryParse(value);
                              if (rate == null || rate <= 0) {
                                return 'Invalid rate';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxDescentRateController,
                            decoration: const InputDecoration(
                              labelText: 'Max Descent Rate (fpm) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final rate = int.tryParse(value);
                              if (rate == null || rate <= 0) {
                                return 'Invalid rate';
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
                          child: TextFormField(
                            controller: _maxTakeoffWeightController,
                            decoration: const InputDecoration(
                              labelText: 'Max Takeoff Weight (lbs) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final weight = int.tryParse(value);
                              if (weight == null || weight <= 0) {
                                return 'Invalid weight';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxLandingWeightController,
                            decoration: const InputDecoration(
                              labelText: 'Max Landing Weight (lbs) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final weight = int.tryParse(value);
                              if (weight == null || weight <= 0) {
                                return 'Invalid weight';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveAircraft,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.aircraft == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAircraft() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedManufacturer == null || _selectedModel == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = Provider.of<AircraftSettingsService>(context, listen: false);

      final aircraft = Aircraft(
        id: widget.aircraft?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        manufacturerId: _selectedManufacturer!.id,
        modelId: _selectedModel!.id,
        cruiseSpeed: int.parse(_cruiseSpeedController.text),
        fuelConsumption: double.parse(_fuelConsumptionController.text),
        maximumAltitude: int.parse(_maxAltitudeController.text),
        maximumClimbRate: int.parse(_maxClimbRateController.text),
        maximumDescentRate: int.parse(_maxDescentRateController.text),
        maxTakeoffWeight: int.parse(_maxTakeoffWeightController.text),
        maxLandingWeight: int.parse(_maxLandingWeightController.text),
        fuelCapacity: int.parse(_fuelCapacityController.text),
        createdAt: widget.aircraft?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        registration: _registrationController.text.trim().isEmpty ? null : _registrationController.text.trim(),
        manufacturer: _selectedManufacturer!.name,
        model: _selectedModel!.name,
        category: _selectedModel!.category, // Use category from model
      );

      if (widget.aircraft == null) {
        await service.addAircraft(aircraft);
      } else {
        await service.updateAircraft(aircraft);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.aircraft == null
                ? 'Aircraft "${aircraft.name}" added successfully'
                : 'Aircraft "${aircraft.name}" updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving aircraft: $e'),
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
