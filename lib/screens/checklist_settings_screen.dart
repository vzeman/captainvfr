import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/checklist_service.dart';
import '../services/aircraft_settings_service.dart';
import '../models/checklist.dart';
import '../widgets/checklist_form_dialog.dart';
import '../widgets/checklist_run_dialog.dart';
import '../utils/form_theme_helper.dart';

/// Screen to view and manage checklists.
class ChecklistSettingsScreen extends StatefulWidget {
  const ChecklistSettingsScreen({super.key});

  @override
  State<ChecklistSettingsScreen> createState() =>
      _ChecklistSettingsScreenState();
}

class _ChecklistSettingsScreenState extends State<ChecklistSettingsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchQuery(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checklists',
          style: TextStyle(color: FormThemeHelper.primaryTextColor),
        ),
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        foregroundColor: FormThemeHelper.primaryTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Checklist',
            onPressed: () => _openForm(),
          ),
        ],
      ),
      backgroundColor: FormThemeHelper.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search field outside of Consumer to prevent focus loss
            _SearchField(
              controller: _searchController,
              onChanged: _updateSearchQuery,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer2<ChecklistService, AircraftSettingsService>(
                builder: (context, checklistSvc, aircraftSvc, child) {
                  final query = _searchQuery;
                  final lists = checklistSvc.checklists.where((c) {
                    final m = aircraftSvc.manufacturers.firstWhere(
                      (m) => m.id == c.manufacturerId,
                    );
                    final mdl = aircraftSvc.models.firstWhere(
                      (md) => md.id == c.modelId,
                    );
                    return c.name.toLowerCase().contains(query) ||
                        m.name.toLowerCase().contains(query) ||
                        mdl.name.toLowerCase().contains(query);
                  }).toList();
                  if (lists.isEmpty) {
                    return Center(
                      child: Text(
                        'No matching checklists',
                        style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      final c = lists[index];
                      final mfr = aircraftSvc.manufacturers.firstWhere(
                        (m) => m.id == c.manufacturerId,
                      );
                      final mdl = aircraftSvc.models.firstWhere(
                        (md) => md.id == c.modelId,
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: FormThemeHelper.sectionBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FormThemeHelper.sectionBorderColor),
                        ),
                        child: ListTile(
                          title: Text(
                            c.name,
                            style: TextStyle(
                              color: FormThemeHelper.primaryTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${mfr.name} • ${mdl.name}',
                            style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.play_arrow,
                                  color: FormThemeHelper.primaryAccent,
                                ),
                                tooltip: 'Start',
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => ChecklistRunDialog(
                                    checklist: c,
                                    aircraftName: null,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: FormThemeHelper.secondaryTextColor,
                                ),
                                tooltip: 'Edit',
                                onPressed: () => _openForm(checklist: c),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(c.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openForm({Checklist? checklist}) {
    showDialog(
      context: context,
      builder: (_) => ChecklistFormDialog(checklist: checklist),
    );
  }

  void _confirmDelete(String id) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Checklist'),
        content: const Text('Are you sure you want to delete this checklist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ChecklistService>(
                context,
                listen: false,
              ).deleteChecklist(id);
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Separate stateful widget for search field to maintain focus
class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      style: FormThemeHelper.inputTextStyle,
      decoration: FormThemeHelper.getInputDecoration('Search')
          .copyWith(prefixIcon: Icon(Icons.search, color: FormThemeHelper.secondaryTextColor)),
      onChanged: widget.onChanged,
    );
  }
}
