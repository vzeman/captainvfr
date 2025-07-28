import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pilot.dart';
import '../../services/pilot_service.dart';
import '../../constants/app_colors.dart';

class PilotForm extends StatefulWidget {
  final Pilot? pilot;

  const PilotForm({super.key, this.pilot});

  @override
  State<PilotForm> createState() => _PilotFormState();
}

class _PilotFormState extends State<PilotForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _certificateNumberController;
  DateTime? _birthdate;
  bool _isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pilot?.name ?? '');
    _emailController = TextEditingController(text: widget.pilot?.email ?? '');
    _phoneController = TextEditingController(text: widget.pilot?.phone ?? '');
    _certificateNumberController = TextEditingController(
      text: widget.pilot?.certificateNumber ?? '',
    );
    _birthdate = widget.pilot?.birthdate;
    _isCurrentUser = widget.pilot?.isCurrentUser ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _certificateNumberController.dispose();
    super.dispose();
  }

  Future<void> _savePilot() async {
    if (_formKey.currentState!.validate()) {
      final pilotService = context.read<PilotService>();

      if (widget.pilot == null) {
        // Create new pilot
        final pilot = Pilot(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          certificateNumber: _certificateNumberController.text.trim().isEmpty
              ? null
              : _certificateNumberController.text.trim(),
          birthdate: _birthdate,
          isCurrentUser: _isCurrentUser,
        );
        await pilotService.addPilot(pilot);
      } else {
        // Update existing pilot
        final updatedPilot = widget.pilot!.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          certificateNumber: _certificateNumberController.text.trim().isEmpty
              ? null
              : _certificateNumberController.text.trim(),
          birthdate: _birthdate,
          isCurrentUser: _isCurrentUser,
        );
        await pilotService.updatePilot(updatedPilot);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.pilot != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          isEditing ? 'Edit Pilot' : 'Add Pilot',
          style: TextStyle(color: AppColors.primaryTextColor),
        ),
        iconTheme: IconThemeData(color: AppColors.primaryTextColor),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information
              Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: AppColors.primaryTextColor),
                decoration: InputDecoration(
                  labelText: 'Name *',
                  hintText: 'John Doe',
                  prefixIcon: Icon(Icons.person, color: AppColors.secondaryTextColor),
                  labelStyle: TextStyle(color: AppColors.secondaryTextColor),
                  hintStyle: TextStyle(color: AppColors.secondaryTextColor.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.sectionBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryAccent, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.sectionBackgroundColor,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter pilot name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.sectionBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.sectionBorderColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(
                    'Date of Birth',
                    style: TextStyle(color: AppColors.primaryTextColor),
                  ),
                  subtitle: Text(
                    _birthdate != null
                        ? '${_birthdate!.day}/${_birthdate!.month}/${_birthdate!.year}'
                        : 'Not set',
                    style: TextStyle(color: AppColors.secondaryTextColor),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_birthdate != null)
                        IconButton(
                          icon: Icon(Icons.clear, color: AppColors.secondaryTextColor),
                          onPressed: () {
                            setState(() {
                              _birthdate = null;
                            });
                          },
                        ),
                      Icon(Icons.calendar_today, color: AppColors.secondaryTextColor),
                    ],
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _birthdate ?? DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.dark(),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() {
                        _birthdate = date;
                      });
                    }
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Contact Information
              Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                style: TextStyle(color: AppColors.primaryTextColor),
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'pilot@example.com',
                  prefixIcon: Icon(Icons.email, color: AppColors.secondaryTextColor),
                  labelStyle: TextStyle(color: AppColors.secondaryTextColor),
                  hintStyle: TextStyle(color: AppColors.secondaryTextColor.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.sectionBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryAccent, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.sectionBackgroundColor,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                style: TextStyle(color: AppColors.primaryTextColor),
                decoration: InputDecoration(
                  labelText: 'Phone',
                  hintText: '+1 234 567 8900',
                  prefixIcon: Icon(Icons.phone, color: AppColors.secondaryTextColor),
                  labelStyle: TextStyle(color: AppColors.secondaryTextColor),
                  hintStyle: TextStyle(color: AppColors.secondaryTextColor.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.sectionBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryAccent, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.sectionBackgroundColor,
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 24),

              // Certificate Information
              Text(
                'Certificate Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _certificateNumberController,
                style: TextStyle(color: AppColors.primaryTextColor),
                decoration: InputDecoration(
                  labelText: 'Certificate Number',
                  hintText: '123456789',
                  prefixIcon: Icon(Icons.badge, color: AppColors.secondaryTextColor),
                  labelStyle: TextStyle(color: AppColors.secondaryTextColor),
                  hintStyle: TextStyle(color: AppColors.secondaryTextColor.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.sectionBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryAccent, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.sectionBackgroundColor,
                ),
              ),

              const SizedBox(height: 24),

              // Settings
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.sectionBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.sectionBorderColor),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Set as Current Pilot',
                    style: TextStyle(color: AppColors.primaryTextColor),
                  ),
                  subtitle: Text(
                    'This pilot will be selected by default for new entries',
                    style: TextStyle(color: AppColors.secondaryTextColor),
                  ),
                  value: _isCurrentUser,
                  activeColor: AppColors.primaryAccent,
                  onChanged: (value) {
                    setState(() {
                      _isCurrentUser = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePilot,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Update Pilot' : 'Add Pilot',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}