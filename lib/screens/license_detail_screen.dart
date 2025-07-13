import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/license.dart';
import '../services/license_service.dart';
import '../widgets/license_photos_widget.dart';

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
      appBar: AppBar(title: Text(isEditing ? 'Edit License' : 'Add License')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'License Name',
                hintText: 'e.g., PPL, CPL, IR, Medical Class 1',
                prefixIcon: Icon(Icons.card_membership),
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
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Private Pilot License - SEP(land)',
                prefixIcon: Icon(Icons.description),
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
              decoration: const InputDecoration(
                labelText: 'License Number (Optional)',
                hintText: 'e.g., UK.FCL.PPL.12345',
                prefixIcon: Icon(Icons.confirmation_number),
              ),
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
        borderRadius: BorderRadius.circular(8),
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
        await licenseService.addLicense(newLicense);
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
