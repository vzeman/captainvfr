import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/aircraft.dart';
import '../models/manufacturer.dart';
import '../models/model.dart';
import '../utils/form_theme_helper.dart';

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
  
  // Additional performance data controllers
  final _takeoffGroundRoll50ftController = TextEditingController();
  final _takeoffOver50ftController = TextEditingController();
  final _landingGroundRoll50ftController = TextEditingController();
  final _landingOver50ftController = TextEditingController();
  final _stallSpeedCleanController = TextEditingController();
  final _stallSpeedLandingController = TextEditingController();
  final _serviceAboveCeilingController = TextEditingController();
  final _bestGlideSpeedController = TextEditingController();
  final _bestGlideRatioController = TextEditingController();
  final _vxController = TextEditingController();
  final _vyController = TextEditingController();
  final _vaController = TextEditingController();
  final _vnoController = TextEditingController();
  final _vneController = TextEditingController();
  final _emptyWeightController = TextEditingController();
  final _emptyWeightCGController = TextEditingController();

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
    
    // Populate additional performance fields
    if (aircraft.takeoffGroundRoll50ft != null) {
      _takeoffGroundRoll50ftController.text = aircraft.takeoffGroundRoll50ft.toString();
    }
    if (aircraft.takeoffOver50ft != null) {
      _takeoffOver50ftController.text = aircraft.takeoffOver50ft.toString();
    }
    if (aircraft.landingGroundRoll50ft != null) {
      _landingGroundRoll50ftController.text = aircraft.landingGroundRoll50ft.toString();
    }
    if (aircraft.landingOver50ft != null) {
      _landingOver50ftController.text = aircraft.landingOver50ft.toString();
    }
    if (aircraft.stallSpeedClean != null) {
      _stallSpeedCleanController.text = aircraft.stallSpeedClean.toString();
    }
    if (aircraft.stallSpeedLanding != null) {
      _stallSpeedLandingController.text = aircraft.stallSpeedLanding.toString();
    }
    if (aircraft.serviceAboveCeiling != null) {
      _serviceAboveCeilingController.text = aircraft.serviceAboveCeiling.toString();
    }
    if (aircraft.bestGlideSpeed != null) {
      _bestGlideSpeedController.text = aircraft.bestGlideSpeed.toString();
    }
    if (aircraft.bestGlideRatio != null) {
      _bestGlideRatioController.text = aircraft.bestGlideRatio.toString();
    }
    if (aircraft.vx != null) {
      _vxController.text = aircraft.vx.toString();
    }
    if (aircraft.vy != null) {
      _vyController.text = aircraft.vy.toString();
    }
    if (aircraft.va != null) {
      _vaController.text = aircraft.va.toString();
    }
    if (aircraft.vno != null) {
      _vnoController.text = aircraft.vno.toString();
    }
    if (aircraft.vne != null) {
      _vneController.text = aircraft.vne.toString();
    }
    if (aircraft.emptyWeight != null) {
      _emptyWeightController.text = aircraft.emptyWeight.toString();
    }
    if (aircraft.emptyWeightCG != null) {
      _emptyWeightCGController.text = aircraft.emptyWeightCG.toString();
    }

    // Find manufacturer and model from the service using IDs
    final service = Provider.of<AircraftSettingsService>(
      context,
      listen: false,
    );
    try {
      _selectedManufacturer = service.manufacturers.firstWhere(
        (m) => m.id == aircraft.manufacturerId,
      );
    } catch (e) {
      _selectedManufacturer = service.manufacturers.isNotEmpty
          ? service.manufacturers.first
          : null;
    }

    if (_selectedManufacturer != null) {
      final models = service.getModelsForManufacturer(
        _selectedManufacturer!.id,
      );
      try {
        _selectedModel = models.firstWhere((m) => m.id == aircraft.modelId);
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
    _takeoffGroundRoll50ftController.dispose();
    _takeoffOver50ftController.dispose();
    _landingGroundRoll50ftController.dispose();
    _landingOver50ftController.dispose();
    _stallSpeedCleanController.dispose();
    _stallSpeedLandingController.dispose();
    _serviceAboveCeilingController.dispose();
    _bestGlideSpeedController.dispose();
    _bestGlideRatioController.dispose();
    _vxController.dispose();
    _vyController.dispose();
    _vaController.dispose();
    _vnoController.dispose();
    _vneController.dispose();
    _emptyWeightController.dispose();
    _emptyWeightCGController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AircraftSettingsService>(
      builder: (context, service, child) {
        return FormThemeHelper.buildDialog(
          context: context,
          title: widget.aircraft == null ? 'Add Aircraft' : 'Edit Aircraft',
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: FormThemeHelper.getSectionDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic Information',
                            style: FormThemeHelper.sectionTitleStyle,
                          ),
                          const SizedBox(height: 16),
                          FormThemeHelper.buildFormField(
                            controller: _nameController,
                            labelText: 'Aircraft Name *',
                            hintText: 'e.g., My Cessna 172',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an aircraft name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          FormThemeHelper.buildFormField(
                            controller: _registrationController,
                            labelText: 'Registration',
                            hintText: 'e.g., N123AB',
                          ),
                          const SizedBox(height: 16),
                          // Manufacturer Selection
                          FormThemeHelper.buildDropdownField<Manufacturer>(
                            value: _selectedManufacturer,
                            labelText: 'Manufacturer *',
                            items: service.manufacturers.map((manufacturer) {
                              return DropdownMenuItem(
                                value: manufacturer,
                                child: Text(manufacturer.name, style: FormThemeHelper.inputTextStyle),
                              );
                            }).toList(),
                            onChanged: (manufacturer) {
                              setState(() {
                                _selectedManufacturer = manufacturer;
                                _selectedModel = null;
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
                          FormThemeHelper.buildDropdownField<Model>(
                            value: _selectedModel,
                            labelText: 'Model *',
                            items: _selectedManufacturer?.models.map((modelId) {
                              final model = Provider.of<AircraftSettingsService>(
                                context,
                                listen: false,
                              ).models.firstWhere((m) => m.id == modelId);
                              return DropdownMenuItem<Model>(
                                value: model,
                                child: Text(model.name, style: FormThemeHelper.inputTextStyle),
                              );
                            }).toList() ?? [],
                            onChanged: (model) {
                              setState(() {
                                _selectedModel = model;
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FormThemeHelper.buildSection(
                    title: 'Performance Specifications',
                    children: [

                      Row(
                        children: [
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _cruiseSpeedController,
                              labelText: 'Cruise Speed (kts) *',
                              keyboardType: TextInputType.number,
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
                            child: FormThemeHelper.buildFormField(
                              controller: _fuelConsumptionController,
                              labelText: 'Fuel Consumption (GPH) *',
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
                            child: FormThemeHelper.buildFormField(
                              controller: _maxAltitudeController,
                              labelText: 'Max Altitude (ft) *',
                              keyboardType: TextInputType.number,
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
                            child: FormThemeHelper.buildFormField(
                              controller: _fuelCapacityController,
                              labelText: 'Fuel Capacity (gal) *',
                              keyboardType: TextInputType.number,
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
                            child: FormThemeHelper.buildFormField(
                              controller: _maxClimbRateController,
                              labelText: 'Max Climb Rate (fpm) *',
                              keyboardType: TextInputType.number,
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
                            child: FormThemeHelper.buildFormField(
                              controller: _maxDescentRateController,
                              labelText: 'Max Descent Rate (fpm) *',
                              keyboardType: TextInputType.number,
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
                            child: FormThemeHelper.buildFormField(
                              controller: _maxTakeoffWeightController,
                              labelText: 'Max Takeoff Weight (lbs) *',
                              keyboardType: TextInputType.number,
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
                            child: FormThemeHelper.buildFormField(
                              controller: _maxLandingWeightController,
                              labelText: 'Max Landing Weight (lbs) *',
                              keyboardType: TextInputType.number,
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
                  const SizedBox(height: 16),
                  FormThemeHelper.buildSection(
                    title: 'Takeoff & Landing Performance',
                    children: [

                      Row(
                        children: [
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _takeoffGroundRoll50ftController,
                              labelText: 'Takeoff Ground Roll (ft)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _takeoffOver50ftController,
                              labelText: 'Takeoff Over 50ft (ft)',
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
                              controller: _landingGroundRoll50ftController,
                              labelText: 'Landing Ground Roll (ft)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _landingOver50ftController,
                              labelText: 'Landing Over 50ft (ft)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FormThemeHelper.buildSection(
                    title: 'V-Speeds',
                    children: [

                      Row(
                        children: [
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _stallSpeedCleanController,
                              labelText: 'Vs1 (Clean) (kts)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _stallSpeedLandingController,
                              labelText: 'Vs0 (Landing) (kts)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _vxController,
                              labelText: 'Vx (Best Angle) (kts)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _vyController,
                              labelText: 'Vy (Best Rate) (kts)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _vaController,
                              labelText: 'Va (Maneuvering) (kts)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _vnoController,
                              labelText: 'Vno (Max Structural) (kts)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FormThemeHelper.buildFormField(
                        controller: _vneController,
                        labelText: 'Vne (Never Exceed) (kts)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FormThemeHelper.buildSection(
                    title: 'Additional Performance Data',
                    children: [

                      Row(
                        children: [
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _serviceAboveCeilingController,
                              labelText: 'Service Ceiling (ft)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _bestGlideSpeedController,
                              labelText: 'Best Glide Speed (kts)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _bestGlideRatioController,
                              labelText: 'Best Glide Ratio',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormThemeHelper.buildFormField(
                              controller: _emptyWeightController,
                              labelText: 'Empty Weight (lbs)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FormThemeHelper.buildFormField(
                        controller: _emptyWeightCGController,
                        labelText: 'Empty Weight CG (inches from datum)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
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
              onPressed: _isLoading ? null : _saveAircraft,
              style: FormThemeHelper.getPrimaryButtonStyle(),
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
      final service = Provider.of<AircraftSettingsService>(
        context,
        listen: false,
      );

      final aircraft = Aircraft(
        id:
            widget.aircraft?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
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
        registration: _registrationController.text.trim().isEmpty
            ? null
            : _registrationController.text.trim(),
        manufacturer: _selectedManufacturer!.name,
        model: _selectedModel!.name,
        category: _selectedModel!.category, // Use category from model
        // New performance fields
        takeoffGroundRoll50ft: _takeoffGroundRoll50ftController.text.trim().isEmpty
            ? null
            : int.tryParse(_takeoffGroundRoll50ftController.text),
        takeoffOver50ft: _takeoffOver50ftController.text.trim().isEmpty
            ? null
            : int.tryParse(_takeoffOver50ftController.text),
        landingGroundRoll50ft: _landingGroundRoll50ftController.text.trim().isEmpty
            ? null
            : int.tryParse(_landingGroundRoll50ftController.text),
        landingOver50ft: _landingOver50ftController.text.trim().isEmpty
            ? null
            : int.tryParse(_landingOver50ftController.text),
        stallSpeedClean: _stallSpeedCleanController.text.trim().isEmpty
            ? null
            : double.tryParse(_stallSpeedCleanController.text),
        stallSpeedLanding: _stallSpeedLandingController.text.trim().isEmpty
            ? null
            : double.tryParse(_stallSpeedLandingController.text),
        serviceAboveCeiling: _serviceAboveCeilingController.text.trim().isEmpty
            ? null
            : int.tryParse(_serviceAboveCeilingController.text),
        bestGlideSpeed: _bestGlideSpeedController.text.trim().isEmpty
            ? null
            : double.tryParse(_bestGlideSpeedController.text),
        bestGlideRatio: _bestGlideRatioController.text.trim().isEmpty
            ? null
            : double.tryParse(_bestGlideRatioController.text),
        vx: _vxController.text.trim().isEmpty
            ? null
            : double.tryParse(_vxController.text),
        vy: _vyController.text.trim().isEmpty
            ? null
            : double.tryParse(_vyController.text),
        va: _vaController.text.trim().isEmpty
            ? null
            : double.tryParse(_vaController.text),
        vno: _vnoController.text.trim().isEmpty
            ? null
            : double.tryParse(_vnoController.text),
        vne: _vneController.text.trim().isEmpty
            ? null
            : double.tryParse(_vneController.text),
        emptyWeight: _emptyWeightController.text.trim().isEmpty
            ? null
            : int.tryParse(_emptyWeightController.text),
        emptyWeightCG: _emptyWeightCGController.text.trim().isEmpty
            ? null
            : double.tryParse(_emptyWeightCGController.text),
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
            content: Text(
              widget.aircraft == null
                  ? 'Aircraft "${aircraft.name}" added successfully'
                  : 'Aircraft "${aircraft.name}" updated successfully',
            ),
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
