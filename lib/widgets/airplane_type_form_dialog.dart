import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/airplane_settings_service.dart';
import '../models/airplane_type.dart';
import '../models/manufacturer.dart';

class AirplaneTypeFormDialog extends StatefulWidget {
  final AirplaneType? airplaneType;
  final Manufacturer? manufacturer;

  const AirplaneTypeFormDialog({super.key, this.airplaneType, this.manufacturer});

  @override
  State<AirplaneTypeFormDialog> createState() => _AirplaneTypeFormDialogState();
}

class _AirplaneTypeFormDialogState extends State<AirplaneTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _engineCountController = TextEditingController();
  final _maxSeatsController = TextEditingController();
  final _typicalCruiseSpeedController = TextEditingController();
  final _typicalServiceCeilingController = TextEditingController();

  Manufacturer? _selectedManufacturer;
  AirplaneCategory _selectedCategory = AirplaneCategory.singleEngine;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedManufacturer = widget.manufacturer;
    if (widget.airplaneType != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final type = widget.airplaneType!;
    _nameController.text = type.name;
    _descriptionController.text = type.description ?? '';
    _engineCountController.text = type.engineCount.toString();
    _maxSeatsController.text = type.maxSeats.toString();
    _typicalCruiseSpeedController.text = type.typicalCruiseSpeed.toString();
    _typicalServiceCeilingController.text = type.typicalServiceCeiling.toString();
    _selectedCategory = type.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _engineCountController.dispose();
    _maxSeatsController.dispose();
    _typicalCruiseSpeedController.dispose();
    _typicalServiceCeilingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AirplaneSettingsService>(
      builder: (context, service, child) {
        return AlertDialog(
          title: Text(widget.airplaneType == null ? 'Add Airplane Type' : 'Edit Airplane Type'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Manufacturer Selection (if not pre-selected)
                    if (widget.manufacturer == null)
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
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a manufacturer';
                          }
                          return null;
                        },
                      ),

                    if (widget.manufacturer == null) const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Type Name *',
                        hintText: 'e.g., 172 Skyhawk',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a type name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<AirplaneCategory>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: AirplaneCategory.values.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (category) {
                        setState(() {
                          _selectedCategory = category!;
                          // Auto-set engine count based on category
                          switch (category) {
                            case AirplaneCategory.singleEngine:
                              _engineCountController.text = '1';
                              break;
                            case AirplaneCategory.multiEngine:
                              _engineCountController.text = '2';
                              break;
                            case AirplaneCategory.jet:
                              _engineCountController.text = '2';
                              break;
                            case AirplaneCategory.turboprop:
                              _engineCountController.text = '1';
                              break;
                            case AirplaneCategory.helicopter:
                              _engineCountController.text = '1';
                              break;
                            case AirplaneCategory.glider:
                              _engineCountController.text = '0';
                              break;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _engineCountController,
                            decoration: const InputDecoration(
                              labelText: 'Engine Count *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final count = int.tryParse(value);
                              if (count == null || count <= 0) {
                                return 'Invalid count';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxSeatsController,
                            decoration: const InputDecoration(
                              labelText: 'Max Seats',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final seats = int.tryParse(value);
                                if (seats == null || seats <= 0) {
                                  return 'Invalid number';
                                }
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
                            controller: _typicalCruiseSpeedController,
                            decoration: const InputDecoration(
                              labelText: 'Typical Cruise Speed (kts)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final speed = int.tryParse(value);
                                if (speed == null || speed <= 0) {
                                  return 'Invalid speed';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _typicalServiceCeilingController,
                            decoration: const InputDecoration(
                              labelText: 'Service Ceiling (ft)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final ceiling = int.tryParse(value);
                                if (ceiling == null || ceiling <= 0) {
                                  return 'Invalid ceiling';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Brief description of the airplane type',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
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
              onPressed: _isLoading ? null : _saveAirplaneType,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.airplaneType == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAirplaneType() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedManufacturer == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final service = Provider.of<AirplaneSettingsService>(context, listen: false);

      final airplaneType = AirplaneType(
        id: widget.airplaneType?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        manufacturerId: _selectedManufacturer!.id,
        category: _selectedCategory,
        engineCount: int.parse(_engineCountController.text),
        maxSeats: _maxSeatsController.text.isEmpty ? 2 : int.parse(_maxSeatsController.text),
        typicalCruiseSpeed: _typicalCruiseSpeedController.text.isEmpty ? 100.0 : double.parse(_typicalCruiseSpeedController.text),
        typicalServiceCeiling: _typicalServiceCeilingController.text.isEmpty ? 10000.0 : double.parse(_typicalServiceCeilingController.text),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        createdAt: widget.airplaneType?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.airplaneType == null) {
        await service.addAirplaneType(
          _nameController.text.trim(),
          _selectedManufacturer!.id,
          _selectedCategory,
          engineCount: int.parse(_engineCountController.text),
          maxSeats: _maxSeatsController.text.isEmpty ? 2 : int.parse(_maxSeatsController.text),
          typicalCruiseSpeed: _typicalCruiseSpeedController.text.isEmpty ? 100.0 : double.parse(_typicalCruiseSpeedController.text),
          typicalServiceCeiling: _typicalServiceCeilingController.text.isEmpty ? 10000.0 : double.parse(_typicalServiceCeilingController.text),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        );
      } else {
        await service.updateAirplaneType(airplaneType);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.airplaneType == null
                ? 'Airplane type "${airplaneType.name}" added successfully'
                : 'Airplane type "${airplaneType.name}" updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving airplane type: $e'),
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
