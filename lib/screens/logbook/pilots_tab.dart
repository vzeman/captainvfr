import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/pilot_service.dart';
import '../../services/license_service.dart';
import '../../models/pilot.dart';
import '../../models/endorsement.dart';
import '../../models/license.dart';
import '../../widgets/themed_dialog.dart';
import 'pilot_form.dart';
import '../licenses_screen.dart';
import '../license_detail_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';

class PilotsTab extends StatelessWidget {
  const PilotsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pilotService = context.watch<PilotService>();
    final pilots = pilotService.pilots;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: pilots.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add,
                    size: 64,
                    color: AppColors.secondaryTextColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pilots added yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add yourself as the first pilot',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryTextColor,
                    ),
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
        backgroundColor: AppColors.primaryAccent,
        foregroundColor: Colors.white,
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
      color: AppColors.sectionBackgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.defaultRadius,
        side: BorderSide(color: AppColors.sectionBorderColor),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        leading: CircleAvatar(
          backgroundColor: isCurrentPilot
              ? AppColors.primaryAccent
              : AppColors.sectionBorderColor,
          child: Icon(
            Icons.person,
            color: isCurrentPilot
                ? Colors.white
                : AppColors.secondaryTextColor,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                pilot.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTextColor,
                ),
              ),
            ),
            if (isCurrentPilot)
              Chip(
                label: const Text('Current'),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                backgroundColor: AppColors.primaryAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pilot.certificateNumber != null)
              Text(
                'Certificate: ${pilot.certificateNumber}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryTextColor,
                ),
              ),
            if (pilot.age != null) 
              Text(
                'Age: ${pilot.age} years',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryTextColor,
                ),
              ),
            Row(
              children: [
                Icon(
                  Icons.card_membership,
                  size: 16,
                  color: AppColors.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${licenses.length} licenses',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.verified,
                  size: 16,
                  color: AppColors.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${endorsements.length} endorsements',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          color: AppColors.dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.defaultRadius,
            side: BorderSide(color: AppColors.sectionBorderColor),
          ),
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
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, color: AppColors.primaryTextColor),
                title: Text('Edit', style: TextStyle(color: AppColors.primaryTextColor)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (!isCurrentPilot)
              PopupMenuItem(
                value: 'set_current',
                child: ListTile(
                  leading: Icon(Icons.star, color: AppColors.primaryTextColor),
                  title: Text('Set as Current', style: TextStyle(color: AppColors.primaryTextColor)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        children: [
          Container(
            color: AppColors.sectionBackgroundColor,
            child: Padding(
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTextColor,
                        ),
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
                        icon: Icon(Icons.add, color: AppColors.primaryAccent),
                        label: Text(
                          'Manage',
                          style: TextStyle(color: AppColors.primaryAccent),
                        ),
                      ),
                  ],
                ),
                  if (licenses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No licenses added',
                        style: TextStyle(
                          color: AppColors.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    )
                else
                  ...licenses.map((license) => _LicenseTile(license: license)),

                  Divider(
                    height: 32,
                    color: AppColors.sectionBorderColor,
                  ),

                  // Endorsements Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Endorsements',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _showAddEndorsementDialog(context, pilot.id);
                        },
                        icon: Icon(Icons.add, color: AppColors.primaryAccent),
                        label: Text(
                          'Add',
                          style: TextStyle(color: AppColors.primaryAccent),
                        ),
                      ),
                  ],
                ),
                  if (endorsements.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No endorsements added',
                        style: TextStyle(
                          color: AppColors.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    )
                else
                  ...endorsements.map((endorsement) => _EndorsementTile(
                        endorsement: endorsement,
                        pilotId: pilot.id,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
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
      title: Text(
        license.name,
        style: TextStyle(color: AppColors.primaryTextColor),
      ),
      subtitle: Text(
        license.expirationStatus,
        style: TextStyle(color: AppColors.secondaryTextColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (license.isExpired)
            Icon(Icons.error, color: Theme.of(context).colorScheme.error)
          else if (license.willExpireWithinDays(30))
            const Icon(Icons.warning, color: Colors.orange)
          else
            const Icon(Icons.check_circle, color: Colors.green),
          PopupMenuButton<String>(
            color: AppColors.dialogBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.defaultRadius,
              side: BorderSide(color: AppColors.sectionBorderColor),
            ),
            onSelected: (value) async {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LicenseDetailScreen(license: license),
                  ),
                );
              } else if (value == 'delete') {
                final confirmed = await ThemedDialog.showConfirmation(
                  context: context,
                  title: 'Delete License',
                  message: 'Are you sure you want to delete "${license.name}"?',
                  confirmText: 'Delete',
                  cancelText: 'Cancel',
                  destructive: true,
                );

                if (confirmed == true && context.mounted) {
                  await context
                      .read<LicenseService>()
                      .deleteLicense(license.id);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit', style: TextStyle(color: AppColors.primaryTextColor)),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
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
      title: Text(
        endorsement.title,
        style: TextStyle(color: AppColors.primaryTextColor),
      ),
      subtitle: Text(
        endorsement.expirationStatus,
        style: TextStyle(color: AppColors.secondaryTextColor),
      ),
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
            color: AppColors.dialogBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.defaultRadius,
              side: BorderSide(color: AppColors.sectionBorderColor),
            ),
            onSelected: (value) async {
              if (value == 'edit') {
                _showEditEndorsementDialog(context, endorsement, pilotId);
              } else if (value == 'delete') {
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
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit', style: TextStyle(color: AppColors.primaryTextColor)),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _showEditEndorsementDialog(BuildContext context, Endorsement endorsement, String pilotId) {
    ThemedDialog.show(
      context: context,
      title: 'Edit Endorsement',
      content: _EndorsementDialogContent(
        pilotId: pilotId,
        endorsement: endorsement,
      ),
      maxWidth: 500,
    );
  }
}

class _EndorsementDialogContent extends StatefulWidget {
  final String pilotId;
  final Endorsement? endorsement;

  const _EndorsementDialogContent({
    required this.pilotId,
    this.endorsement,
  });

  @override
  State<_EndorsementDialogContent> createState() => _EndorsementDialogContentState();
}

class _EndorsementDialogContentState extends State<_EndorsementDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _validFrom;
  DateTime? _validTo;

  @override
  void initState() {
    super.initState();
    if (widget.endorsement != null) {
      _titleController.text = widget.endorsement!.title;
      _descriptionController.text = widget.endorsement!.description;
      _validFrom = widget.endorsement!.validFrom;
      _validTo = widget.endorsement!.validTo;
    } else {
      _validFrom = DateTime.now();
    }
  }

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
            borderRadius: BorderRadius.all(Radius.circular(AppTheme.borderRadiusDefault)),
            borderSide: BorderSide(color: Color(0x7F448AFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppTheme.borderRadiusDefault)),
            borderSide: BorderSide(color: Color(0x7F448AFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppTheme.borderRadiusDefault)),
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
                borderRadius: AppTheme.defaultRadius,
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
                borderRadius: AppTheme.defaultRadius,
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
                  borderRadius: AppTheme.defaultRadius,
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
                      final pilotService = context.read<PilotService>();
                      
                      if (widget.endorsement != null) {
                        // Update existing endorsement
                        final updatedEndorsement = widget.endorsement!.copyWith(
                          title: _titleController.text,
                          description: _descriptionController.text,
                          validFrom: _validFrom,
                          validTo: _validTo,
                        );
                        await pilotService.updateEndorsement(updatedEndorsement);
                      } else {
                        // Add new endorsement
                        final endorsement = Endorsement(
                          title: _titleController.text,
                          description: _descriptionController.text,
                          validFrom: _validFrom,
                          validTo: _validTo,
                        );
                        await pilotService.addEndorsement(endorsement, widget.pilotId);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: Text(widget.endorsement != null ? 'Update' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}