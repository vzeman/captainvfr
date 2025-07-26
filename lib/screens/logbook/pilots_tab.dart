import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/pilot_service.dart';
import '../../models/pilot.dart';
import '../../models/endorsement.dart';
import '../../models/license.dart';
import 'pilot_form.dart';
import '../licenses_screen.dart';

class PilotsTab extends StatelessWidget {
  const PilotsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pilotService = context.watch<PilotService>();
    final pilots = pilotService.pilots;

    return Scaffold(
      body: pilots.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pilots added yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add yourself as the first pilot',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: pilots.length,
              itemBuilder: (context, index) {
                final pilot = pilots[index];
                return _PilotTile(pilot: pilot);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PilotForm(),
            ),
          );
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _PilotTile extends StatelessWidget {
  final Pilot pilot;

  const _PilotTile({required this.pilot});

  @override
  Widget build(BuildContext context) {
    final pilotService = context.watch<PilotService>();
    final endorsements = pilotService.getEndorsementsForPilot(pilot.id);
    final licenses = pilotService.getLicensesForPilot(pilot.id);
    final isCurrentPilot = pilotService.currentPilot?.id == pilot.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isCurrentPilot
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.person,
            color: isCurrentPilot
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                pilot.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (isCurrentPilot)
              Chip(
                label: const Text('Current'),
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pilot.certificateNumber != null)
              Text('Certificate: ${pilot.certificateNumber}'),
            if (pilot.age != null) Text('Age: ${pilot.age} years'),
            Row(
              children: [
                Icon(
                  Icons.card_membership,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text('${licenses.length} licenses'),
                const SizedBox(width: 16),
                Icon(
                  Icons.verified,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text('${endorsements.length} endorsements'),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PilotForm(pilot: pilot),
                  ),
                );
                break;
              case 'set_current':
                await pilotService.setCurrentPilot(pilot.id);
                break;
              case 'delete':
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Pilot'),
                    content: Text(
                      'Are you sure you want to delete ${pilot.name}? This will also delete all associated licenses and endorsements.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  try {
                    await pilotService.deletePilot(pilot.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                }
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (!isCurrentPilot)
              const PopupMenuItem(
                value: 'set_current',
                child: ListTile(
                  leading: Icon(Icons.star),
                  title: Text('Set as Current'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Licenses Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Licenses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LicensesScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Manage'),
                    ),
                  ],
                ),
                if (licenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No licenses added'),
                  )
                else
                  ...licenses.map((license) => _LicenseTile(license: license)),

                const Divider(height: 32),

                // Endorsements Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Endorsements',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () {
                        _showAddEndorsementDialog(context, pilot.id);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (endorsements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No endorsements added'),
                  )
                else
                  ...endorsements.map((endorsement) => _EndorsementTile(
                        endorsement: endorsement,
                        pilotId: pilot.id,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEndorsementDialog(BuildContext context, String pilotId) {
    showDialog(
      context: context,
      builder: (context) => _EndorsementDialog(pilotId: pilotId),
    );
  }
}

class _LicenseTile extends StatelessWidget {
  final License license;

  const _LicenseTile({required this.license});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(license.name),
      subtitle: Text(license.expirationStatus),
      trailing: license.isExpired
          ? Icon(Icons.error, color: Theme.of(context).colorScheme.error)
          : license.willExpireWithinDays(30)
              ? const Icon(Icons.warning, color: Colors.orange)
              : const Icon(Icons.check_circle, color: Colors.green),
    );
  }
}

class _EndorsementTile extends StatelessWidget {
  final Endorsement endorsement;
  final String pilotId;

  const _EndorsementTile({
    required this.endorsement,
    required this.pilotId,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(endorsement.title),
      subtitle: Text(endorsement.expirationStatus),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (endorsement.isExpired)
            Icon(Icons.error, color: Theme.of(context).colorScheme.error)
          else if (endorsement.willExpireWithinDays(30))
            const Icon(Icons.warning, color: Colors.orange)
          else
            const Icon(Icons.check_circle, color: Colors.green),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Endorsement'),
                    content: Text(
                      'Are you sure you want to delete "${endorsement.title}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  await context
                      .read<PilotService>()
                      .deleteEndorsement(endorsement.id);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EndorsementDialog extends StatefulWidget {
  final String pilotId;

  const _EndorsementDialog({required this.pilotId});

  @override
  State<_EndorsementDialog> createState() => _EndorsementDialogState();
}

class _EndorsementDialogState extends State<_EndorsementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _validFrom = DateTime.now();
  DateTime? _validTo;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Endorsement'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Complex Aircraft',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Additional details',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Valid From'),
                subtitle: Text(
                  '${_validFrom.day}/${_validFrom.month}/${_validFrom.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _validFrom,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _validFrom = date;
                    });
                  }
                },
              ),
              SwitchListTile(
                title: const Text('Has Expiration'),
                value: _validTo != null,
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _validTo = DateTime.now().add(const Duration(days: 365));
                    } else {
                      _validTo = null;
                    }
                  });
                },
              ),
              if (_validTo != null)
                ListTile(
                  title: const Text('Valid To'),
                  subtitle: Text(
                    '${_validTo!.day}/${_validTo!.month}/${_validTo!.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _validTo!,
                      firstDate: _validFrom,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) {
                      setState(() {
                        _validTo = date;
                      });
                    }
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final endorsement = Endorsement(
                title: _titleController.text,
                description: _descriptionController.text,
                validFrom: _validFrom,
                validTo: _validTo,
              );

              await context
                  .read<PilotService>()
                  .addEndorsement(endorsement, widget.pilotId);

              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}