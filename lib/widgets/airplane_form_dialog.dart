import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/airplane_settings_service.dart';
import '../models/airplane.dart';
import '../models/manufacturer.dart';
import '../models/airplane_type.dart';

class AirplaneFormDialog extends StatefulWidget {
  final Airplane? airplane;

  const AirplaneFormDialog({super.key, this.airplane});

  @override
  State<AirplaneFormDialog> createState() => _AirplaneFormDialogState();
}

class _AirplaneFormDialogState extends State<AirplaneFormDialog> {
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
  AirplaneType? _selectedType;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.airplane != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final airplane = widget.airplane!;
    _nameController.text = airplane.name;
    _registrationController.text = airplane.registration ?? '';
    _cruiseSpeedController.text = airplane.cruiseSpeed.toString();
    _fuelConsumptionController.text = airplane.fuelConsumption.toString();
    _maxAltitudeController.text = airplane.maximumAltitude.toString();
    _maxClimbRateController.text = airplane.maximumClimbRate.toString();
    _maxDescentRateController.text = airplane.maximumDescentRate.toString();
    _maxTakeoffWeightController.text = airplane.maxTakeoffWeight.toString();
    _maxLandingWeightController.text = airplane.maxLandingWeight.toString();
    _fuelCapacityController.text = airplane.fuelCapacity.toString();

    // Find manufacturer and type from the service using IDs
    final service = Provider.of<AirplaneSettingsService>(context, listen: false);
    try {
      _selectedManufacturer = service.manufacturers.firstWhere(
        (m) => m.id == airplane.manufacturerId,
      );
    } catch (e) {
      _selectedManufacturer = service.manufacturers.isNotEmpty ? service.manufacturers.first : null;
    }

    if (_selectedManufacturer != null) {
      final airplaneTypes = service.getAirplaneTypesForManufacturer(_selectedManufacturer!.id);
      try {
        _selectedType = airplaneTypes.firstWhere(
          (t) => t.id == airplane.airplaneTypeId,
        );
      } catch (e) {
        _selectedType = airplaneTypes.isNotEmpty ? airplaneTypes.first : null;
      }
    }
  }

  void _copyPerformanceFromType(AirplaneType type) {
    // Copy performance specifications from airplane type if they exist
    if (type.typicalCruiseSpeed > 0) {
      _cruiseSpeedController.text = type.typicalCruiseSpeed.toString();
    }
    if (type.typicalServiceCeiling > 0) {
      _maxAltitudeController.text = type.typicalServiceCeiling.toString();
    }
    if (type.fuelConsumption != null && type.fuelConsumption! > 0) {
      _fuelConsumptionController.text = type.fuelConsumption.toString();
    }
    if (type.maximumClimbRate != null && type.maximumClimbRate! > 0) {
      _maxClimbRateController.text = type.maximumClimbRate.toString();
    }
    if (type.maximumDescentRate != null && type.maximumDescentRate! > 0) {
      _maxDescentRateController.text = type.maximumDescentRate.toString();
    }
    if (type.maxTakeoffWeight != null && type.maxTakeoffWeight! > 0) {
      _maxTakeoffWeightController.text = type.maxTakeoffWeight.toString();
    }
    if (type.maxLandingWeight != null && type.maxLandingWeight! > 0) {
      _maxLandingWeightController.text = type.maxLandingWeight.toString();
    }
    if (type.fuelCapacity != null && type.fuelCapacity! > 0) {
      _fuelCapacityController.text = type.fuelCapacity.toString();
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
    return Consumer<AirplaneSettingsService>(
      builder: (context, service, child) {
        return AlertDialog(
          title: Text(widget.airplane == null ? 'Add Airplane' : 'Edit Airplane'),
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
                        labelText: 'Airplane Name *',
                        hintText: 'e.g., My Cessna 172',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an airplane name';
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
                          _selectedType = null; // Reset type selection
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

                    // Airplane Type Selection
                    DropdownButtonFormField<AirplaneType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Airplane Type *',
                        border: OutlineInputBorder(),
                      ),
                      items: _selectedManufacturer?.airplaneTypes.map((typeId) {
                        final type = Provider.of<AirplaneSettingsService>(context, listen: false)
                            .airplaneTypes.firstWhere((t) => t.id == typeId);
                        return DropdownMenuItem<AirplaneType>(
                          value: type,
                          child: Text(type.name),
                        );
                      }).toList() ?? [],
                      onChanged: (type) {
                        setState(() {
                          _selectedType = type;
                          // Auto-set performance specifications based on type
                          if (type != null) {
                            _copyPerformanceFromType(type);
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select an airplane type';
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final capacity = double.tryParse(value);
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
              onPressed: _isLoading ? null : _saveAirplane,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.airplane == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAirplane() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedManufacturer == null || _selectedType == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = Provider.of<AirplaneSettingsService>(context, listen: false);

      final airplane = Airplane(
        id: widget.airplane?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        manufacturerId: _selectedManufacturer!.id,
        airplaneTypeId: _selectedType!.id,
        cruiseSpeed: double.parse(_cruiseSpeedController.text),
        fuelConsumption: double.parse(_fuelConsumptionController.text),
        maximumAltitude: double.parse(_maxAltitudeController.text),
        maximumClimbRate: double.parse(_maxClimbRateController.text),
        maximumDescentRate: double.parse(_maxDescentRateController.text),
        maxTakeoffWeight: double.parse(_maxTakeoffWeightController.text),
        maxLandingWeight: double.parse(_maxLandingWeightController.text),
        fuelCapacity: double.parse(_fuelCapacityController.text),
        createdAt: widget.airplane?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        registration: _registrationController.text.trim().isEmpty ? null : _registrationController.text.trim(),
        manufacturer: _selectedManufacturer!.name,
        model: _selectedType!.name,
        category: _selectedType!.category, // Use category from airplane type
      );

      if (widget.airplane == null) {
        await service.addAirplane(airplane);
      } else {
        await service.updateAirplane(airplane);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.airplane == null
                ? 'Airplane "${airplane.name}" added successfully'
                : 'Airplane "${airplane.name}" updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving airplane: $e'),
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
