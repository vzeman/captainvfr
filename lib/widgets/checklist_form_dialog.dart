import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checklist.dart';
import '../models/checklist_item.dart';
import '../services/checklist_service.dart';
import '../services/aircraft_settings_service.dart';
import 'checklist_item_form_dialog.dart';

/// Dialog to add or edit a Checklist with its items.
class ChecklistFormDialog extends StatefulWidget {
  final Checklist? checklist;
  const ChecklistFormDialog({super.key, this.checklist});

  @override
  State<ChecklistFormDialog> createState() => _ChecklistFormDialogState();
}

class _ChecklistFormDialogState extends State<ChecklistFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedManufacturerId;
  String? _selectedModelId;
  final List<ChecklistItem> _items = [];

  @override
  void initState() {
    super.initState();
    if (widget.checklist != null) {
      final c = widget.checklist!;
      _nameController.text = c.name;
      _descriptionController.text = c.description ?? '';
      _selectedManufacturerId = c.manufacturerId;
      _selectedModelId = c.modelId;
      _items.addAll(c.items);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              title: Text(widget.checklist == null ? 'Add Checklist' : 'Edit Checklist'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a name' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          Consumer<AircraftSettingsService>(
                            builder: (context, svc, child) {
                              return DropdownButtonFormField<String>(
                                value: _selectedManufacturerId,
                                decoration: const InputDecoration(labelText: 'Manufacturer', border: OutlineInputBorder()),
                                items: svc.manufacturers
                                    .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _selectedManufacturerId = v;
                                    _selectedModelId = null;
                                  });
                                },
                                validator: (v) => v == null ? 'Please select manufacturer' : null,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Consumer<AircraftSettingsService>(
                            builder: (context, svc, child) {
                              final models = svc.models.where(
                                  (model) => _selectedManufacturerId != null && model.manufacturerId == _selectedManufacturerId);
                              return DropdownButtonFormField<String>(
                                value: _selectedModelId,
                                decoration: const InputDecoration(labelText: 'Model', border: OutlineInputBorder()),
                                items: models
                                    .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedModelId = v),
                                validator: (v) => v == null ? 'Please select model' : null,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Items', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.targetValue ?? ''),
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: idx > 0 ? () => setState(() { _items.removeAt(idx); _items.insert(idx - 1, item); }) : null,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  final edited = await showDialog<ChecklistItem>(
                                    context: context,
                                    builder: (_) => ChecklistItemFormDialog(item: item),
                                  );
                                  if (edited != null) setState(() => _items[idx] = edited);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => setState(() => _items.removeAt(idx)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward),
                                onPressed: idx < _items.length - 1
                                    ? () => setState(() { _items.removeAt(idx); _items.insert(idx + 1, item); })
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final newItem = await showDialog<ChecklistItem>(
                          context: context,
                          builder: (_) => const ChecklistItemFormDialog(),
                        );
                        if (newItem != null) setState(() => _items.add(newItem));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _saveChecklist,
                child: const Text('Save Checklist'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveChecklist() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedManufacturerId == null || _selectedModelId == null) return;
    final id = widget.checklist?.id ?? UniqueKey().toString();
    final checklist = Checklist(
      id: id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      manufacturerId: _selectedManufacturerId!,
      modelId: _selectedModelId!,
      items: List.from(_items),
    );
    Provider.of<ChecklistService>(context, listen: false).saveChecklist(checklist);
    Navigator.of(context).pop();
  }
}
