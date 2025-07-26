import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pilot.dart';
import '../../services/pilot_service.dart';

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
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Pilot' : 'Add Pilot'),
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
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'John Doe',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter pilot name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date of Birth'),
                subtitle: Text(
                  _birthdate != null
                      ? '${_birthdate!.day}/${_birthdate!.month}/${_birthdate!.year}'
                      : 'Not set',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_birthdate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _birthdate = null;
                          });
                        },
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _birthdate ?? DateTime(1990),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _birthdate = date;
                    });
                  }
                },
              ),

              const SizedBox(height: 24),

              // Contact Information
              Text(
                'Contact Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'pilot@example.com',
                  prefixIcon: Icon(Icons.email),
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
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '+1 234 567 8900',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 24),

              // Certificate Information
              Text(
                'Certificate Information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _certificateNumberController,
                decoration: const InputDecoration(
                  labelText: 'Certificate Number',
                  hintText: '123456789',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),

              const SizedBox(height: 24),

              // Settings
              Text(
                'Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Set as Current Pilot'),
                subtitle: const Text(
                  'This pilot will be selected by default for new entries',
                ),
                value: _isCurrentUser,
                onChanged: (value) {
                  setState(() {
                    _isCurrentUser = value;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePilot,
                  child: Text(isEditing ? 'Update Pilot' : 'Add Pilot'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}