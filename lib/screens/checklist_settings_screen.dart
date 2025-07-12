import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/checklist_service.dart';
import '../services/aircraft_settings_service.dart';
import '../models/checklist.dart';
import '../widgets/checklist_form_dialog.dart';
import '../widgets/checklist_run_dialog.dart';

/// Screen to view and manage checklists.
class ChecklistSettingsScreen extends StatefulWidget {
  const ChecklistSettingsScreen({super.key});

  @override
  State<ChecklistSettingsScreen> createState() => _ChecklistSettingsScreenState();
}

class _ChecklistSettingsScreenState extends State<ChecklistSettingsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Checklist',
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer2<ChecklistService, AircraftSettingsService>(
                builder: (context, checklistSvc, aircraftSvc, child) {
                  final query = _searchController.text.toLowerCase();
                  final lists = checklistSvc.checklists.where((c) {
                    final m = aircraftSvc.manufacturers.firstWhere((m) => m.id == c.manufacturerId);
                    final mdl = aircraftSvc.models.firstWhere((md) => md.id == c.modelId);
                    return c.name.toLowerCase().contains(query) ||
                        m.name.toLowerCase().contains(query) ||
                        mdl.name.toLowerCase().contains(query);
                  }).toList();
                  if (lists.isEmpty) {
                    return const Center(child: Text('No matching checklists'));
                  }
                  return ListView.builder(
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      final c = lists[index];
                      final mfr = aircraftSvc.manufacturers.firstWhere((m) => m.id == c.manufacturerId);
                      final mdl = aircraftSvc.models.firstWhere((md) => md.id == c.modelId);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(c.name),
                          subtitle: Text('${mfr.name} • ${mdl.name}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
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
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit',
                                onPressed: () => _openForm(checklist: c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<ChecklistService>(context, listen: false).deleteChecklist(id);
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
