import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/pilot_service.dart';
import '../../models/pilot.dart';
import '../../models/endorsement.dart';
import '../../models/license.dart';
import '../../widgets/themed_dialog.dart';
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

class _PilotTile extends StatefulWidget {
  final Pilot pilot;

  const _PilotTile({required this.pilot});

  @override
  State<_PilotTile> createState() => _PilotTileState();
}

class _PilotTileState extends State<_PilotTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final pilot = widget.pilot;
    final pilotService = context.watch<PilotService>();
    final endorsements = pilotService.getEndorsementsForPilot(pilot.id);
    final licenses = pilotService.getLicensesForPilot(pilot.id);
    final isCurrentPilot = pilotService.currentPilot?.id == pilot.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
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
                const Spacer(),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                final confirmed = await ThemedDialog.showConfirmation(
                  context: context,
                  title: 'Delete Pilot',
                  message: 'Are you sure you want to delete ${pilot.name}? This will also delete all associated licenses and endorsements.',
                  confirmText: 'Delete',
                  cancelText: 'Cancel',
                  destructive: true,
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
    ThemedDialog.show(
      context: context,
      title: 'Add Endorsement',
      content: _EndorsementDialogContent(pilotId: pilotId),
      maxWidth: 500,
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
                final confirmed = await ThemedDialog.showConfirmation(
                  context: context,
                  title: 'Delete Endorsement',
                  message: 'Are you sure you want to delete "${endorsement.title}"?',
                  confirmText: 'Delete',
                  cancelText: 'Cancel',
                  destructive: true,
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

class _EndorsementDialogContent extends StatefulWidget {
  final String pilotId;

  const _EndorsementDialogContent({required this.pilotId});

  @override
  State<_EndorsementDialogContent> createState() => _EndorsementDialogContentState();
}

class _EndorsementDialogContentState extends State<_EndorsementDialogContent> {
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
    return Theme(
      data: ThemeData.dark().copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0x1A448AFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Color(0x7F448AFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Color(0x7F448AFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Color(0xFF448AFF), width: 2.0),
          ),
          labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
          hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 13, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 12, color: Colors.white),
          bodySmall: TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Complex Aircraft',
                prefixIcon: Icon(Icons.card_membership, size: 18),
              ),
              style: const TextStyle(fontSize: 12),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Additional details',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.description, size: 18),
              ),
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0x1A448AFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x7F448AFF)),
              ),
              child: ListTile(
                dense: true,
                title: const Text('Valid From', style: TextStyle(fontSize: 12)),
                subtitle: Text(
                  '${_validFrom.day}/${_validFrom.month}/${_validFrom.year}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.calendar_today, size: 18),
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
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0x1A448AFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x7F448AFF)),
              ),
              child: SwitchListTile(
                dense: true,
                title: const Text('Has Expiration', style: TextStyle(fontSize: 12)),
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
            ),
            if (_validTo != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x1A448AFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x7F448AFF)),
                ),
                child: ListTile(
                  dense: true,
                  title: const Text('Valid To', style: TextStyle(fontSize: 12)),
                  subtitle: Text(
                    '${_validTo!.day}/${_validTo!.month}/${_validTo!.year}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.calendar_today, size: 18),
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
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
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
            ),
          ],
        ),
      ),
    );
  }
}