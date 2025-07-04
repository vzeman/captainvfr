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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'import':
                  await _importChecklists();
                  break;
                case 'export_all':
                  await _exportAllChecklists();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20),
                    SizedBox(width: 8),
                    Text('Import Checklists'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_all',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, size: 20),
                    SizedBox(width: 8),
                    Text('Export All Checklists'),
                  ],
                ),
              ),
            ],
          ),
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
                                icon: const Icon(Icons.file_upload),
                                tooltip: 'Export',
                                onPressed: () => _exportChecklist(c),
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
  
  Future<void> _importChecklists() async {
    try {
      final service = context.read<ChecklistService>();
      final result = await service.importChecklists();
      
      if (!mounted) return;
      
      String message;
      if (result.imported > 0 && result.skipped == 0 && !result.hasErrors) {
        message = 'Successfully imported ${result.imported} checklist(s)';
      } else {
        message = 'Import completed:\n';
        if (result.imported > 0) message += '${result.imported} imported\n';
        if (result.skipped > 0) message += '${result.skipped} skipped (already exist)\n';
        if (result.hasErrors) message += '${result.errors.length} failed';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing checklists: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _exportAllChecklists() async {
    try {
      final service = context.read<ChecklistService>();
      if (service.checklists.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No checklists to export')),
        );
        return;
      }
      
      await service.exportChecklists(service.checklists);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${service.checklists.length} checklist(s)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting checklists: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _exportChecklist(Checklist checklist) async {
    try {
      final service = context.read<ChecklistService>();
      await service.exportChecklist(checklist);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist exported')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting checklist: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
