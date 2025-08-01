import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/license.dart';
import '../services/license_service.dart';
import '../services/pilot_service.dart';
import '../widgets/license_photos_widget.dart';
import '../constants/app_theme.dart';
import '../constants/app_colors.dart';
import '../utils/form_theme_helper.dart';

class LicenseDetailScreen extends StatefulWidget {
  final License? license;

  const LicenseDetailScreen({super.key, this.license});

  @override
  State<LicenseDetailScreen> createState() => _LicenseDetailScreenState();
}

class _LicenseDetailScreenState extends State<LicenseDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _licenseNumberController;
  late DateTime _issueDate;
  late DateTime _expirationDate;
  bool _isSaving = false;
  String? _selectedPilotId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.license?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.license?.description ?? '',
    );
    _licenseNumberController = TextEditingController(
      text: widget.license?.licenseNumber ?? '',
    );
    _issueDate = widget.license?.issueDate ?? DateTime.now();
    _expirationDate =
        widget.license?.expirationDate ??
        DateTime.now().add(const Duration(days: 365));
    
    // Find the pilot who has this license
    if (widget.license != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pilotService = context.read<PilotService>();
        for (final pilot in pilotService.pilots) {
          if (pilot.licenseIds.contains(widget.license!.id)) {
            setState(() {
              _selectedPilotId = pilot.id;
            });
            break;
          }
        }
        // If no pilot has this license, default to current pilot
        if (_selectedPilotId == null && pilotService.currentPilot != null) {
          setState(() {
            _selectedPilotId = pilotService.currentPilot!.id;
          });
        }
      });
    } else {
      // For new licenses, default to current pilot
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pilotService = context.read<PilotService>();
        if (pilotService.currentPilot != null) {
          setState(() {
            _selectedPilotId = pilotService.currentPilot!.id;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.license != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.dialogBackgroundColor,
        title: Text(
          isEditing ? 'Edit License' : 'Add License',
          style: const TextStyle(color: AppColors.primaryTextColor),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryTextColor),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.primaryTextColor),
              decoration: FormThemeHelper.getInputDecoration(
                'License Name',
                hintText: 'e.g., PPL, CPL, IR, Medical Class 1',
              ).copyWith(
                prefixIcon: const Icon(Icons.card_membership, color: AppColors.primaryAccent),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a license name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: AppColors.primaryTextColor),
              decoration: FormThemeHelper.getInputDecoration(
                'Description',
                hintText: 'e.g., Private Pilot License - SEP(land)',
              ).copyWith(
                prefixIcon: const Icon(Icons.description, color: AppColors.primaryAccent),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _licenseNumberController,
              style: const TextStyle(color: AppColors.primaryTextColor),
              decoration: FormThemeHelper.getInputDecoration(
                'License Number (Optional)',
                hintText: 'e.g., UK.FCL.PPL.12345',
              ).copyWith(
                prefixIcon: const Icon(Icons.confirmation_number, color: AppColors.primaryAccent),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<PilotService>(
              builder: (context, pilotService, child) {
                final pilots = pilotService.pilots;
                
                if (pilots.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No pilots available. Please add a pilot first.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  );
                }
                
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Assign to Pilot',
                    prefixIcon: Icon(Icons.person),
                  ),
                  value: _selectedPilotId,
                  items: pilots.map((pilot) {
                    return DropdownMenuItem(
                      value: pilot.id,
                      child: Row(
                        children: [
                          Text(pilot.name),
                          if (pilot.id == pilotService.currentPilot?.id) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: AppTheme.defaultRadius,
                              ),
                              child: Text(
                                'Current',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPilotId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a pilot';
                    }
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            _buildDateField(
              context,
              label: 'Issue Date',
              value: _issueDate,
              icon: Icons.calendar_today,
              onChanged: (date) => setState(() => _issueDate = date),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            ),
            const SizedBox(height: 16),
            _buildDateField(
              context,
              label: 'Expiration Date',
              value: _expirationDate,
              icon: Icons.event_busy,
              onChanged: (date) => setState(() => _expirationDate = date),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            ),
            const SizedBox(height: 24),
            _buildExpirationPreview(),
            if (widget.license != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              LicensePhotosWidget(license: widget.license!),
              const Divider(),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveLicense,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Update' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required String label,
    required DateTime value,
    required IconData icon,
    required Function(DateTime) onChanged,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(_formatDate(value), style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildExpirationPreview() {
    final tempLicense = License(
      name: '',
      description: '',
      issueDate: _issueDate,
      expirationDate: _expirationDate,
    );

    Color statusColor;
    IconData statusIcon;
    if (tempLicense.isExpired) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (tempLicense.willExpireWithinDays(30)) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.defaultRadius,
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  tempLicense.expirationStatus,
                  style: TextStyle(color: statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _saveLicense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final licenseService = context.read<LicenseService>();
      final pilotService = context.read<PilotService>();

      String licenseId;
      
      if (widget.license != null) {
        // Update existing license
        final updatedLicense = widget.license!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          licenseNumber: _licenseNumberController.text.trim().isEmpty
              ? null
              : _licenseNumberController.text.trim(),
          issueDate: _issueDate,
          expirationDate: _expirationDate,
        );
        await licenseService.updateLicense(widget.license!.id, updatedLicense);
        licenseId = widget.license!.id;
      } else {
        // Create new license
        final newLicense = License(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          licenseNumber: _licenseNumberController.text.trim().isEmpty
              ? null
              : _licenseNumberController.text.trim(),
          issueDate: _issueDate,
          expirationDate: _expirationDate,
        );
        final savedLicense = await licenseService.addLicense(newLicense);
        licenseId = savedLicense.id;
      }
      
      // Update pilot assignment
      if (_selectedPilotId != null) {
        // First, remove license from all pilots
        for (final pilot in pilotService.pilots) {
          if (pilot.licenseIds.contains(licenseId)) {
            await pilotService.removeLicenseFromPilot(licenseId, pilot.id);
          }
        }
        
        // Then add to selected pilot
        await pilotService.addLicenseToPilot(licenseId, _selectedPilotId!);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.license != null
                  ? 'License updated successfully'
                  : 'License added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving license: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
