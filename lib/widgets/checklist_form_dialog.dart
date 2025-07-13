import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checklist.dart';
import '../models/checklist_item.dart';
import '../services/checklist_service.dart';
import '../services/aircraft_settings_service.dart';
import '../utils/form_theme_helper.dart';
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
    return FormThemeHelper.buildDialog(
      context: context,
      title: widget.checklist == null ? 'Add Checklist' : 'Edit Checklist',
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormThemeHelper.buildFormField(
                controller: _nameController,
                labelText: 'Name',
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 16),
              FormThemeHelper.buildFormField(
                controller: _descriptionController,
                labelText: 'Description',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Consumer<AircraftSettingsService>(
                builder: (context, svc, child) {
                  return FormThemeHelper.buildDropdownField<String>(
                    value: _selectedManufacturerId,
                    labelText: 'Manufacturer',
                    items: svc.manufacturers
                        .map((m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(m.name),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedManufacturerId = v;
                        _selectedModelId = null;
                      });
                    },
                    validator: (v) => v == null
                        ? 'Please select manufacturer'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              Consumer<AircraftSettingsService>(
                builder: (context, svc, child) {
                  final models = svc.models.where(
                    (model) =>
                        _selectedManufacturerId != null &&
                        model.manufacturerId ==
                            _selectedManufacturerId,
                  );
                  return FormThemeHelper.buildDropdownField<String>(
                    value: _selectedModelId,
                    labelText: 'Model',
                    items: models
                        .map((m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(m.name),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedModelId = v),
                    validator: (v) =>
                        v == null ? 'Please select model' : null,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Items',
                style: FormThemeHelper.sectionTitleStyle,
              ),
              const SizedBox(height: 8),
              ..._items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: FormThemeHelper.sectionBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: FormThemeHelper.sectionBorderColor),
                  ),
                  child: ListTile(
                          title: Text(
                            item.name,
                            style: TextStyle(color: FormThemeHelper.primaryTextColor),
                          ),
                          subtitle: Text(
                            item.targetValue ?? '',
                            style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                          ),
                          leading: IconButton(
                            icon: Icon(Icons.arrow_upward, color: FormThemeHelper.secondaryTextColor),
                            onPressed: idx > 0
                                ? () => setState(() {
                                    _items.removeAt(idx);
                                    _items.insert(idx - 1, item);
                                  })
                                : null,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: FormThemeHelper.secondaryTextColor),
                                onPressed: () async {
                                  final edited =
                                      await showDialog<ChecklistItem>(
                                        context: context,
                                        builder: (_) =>
                                            ChecklistItemFormDialog(item: item),
                                      );
                                  if (edited != null) {
                                    setState(() => _items[idx] = edited);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    setState(() => _items.removeAt(idx)),
                              ),
                              IconButton(
                                icon: Icon(Icons.arrow_downward, color: FormThemeHelper.secondaryTextColor),
                                onPressed: idx < _items.length - 1
                                    ? () => setState(() {
                                        _items.removeAt(idx);
                                        _items.insert(idx + 1, item);
                                      })
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
                  if (newItem != null) {
                    setState(() => _items.add(newItem));
                  }
                },
                style: FormThemeHelper.getOutlinedButtonStyle(),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FormThemeHelper.getSecondaryButtonStyle(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChecklist,
          style: FormThemeHelper.getPrimaryButtonStyle(),
          child: const Text('Save Checklist'),
        ),
      ],
    );
  }

  void _saveChecklist() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedManufacturerId == null || _selectedModelId == null) return;
    final id = widget.checklist?.id ?? UniqueKey().toString();
    final checklist = Checklist(
      id: id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      manufacturerId: _selectedManufacturerId!,
      modelId: _selectedModelId!,
      items: List.from(_items),
    );
    Provider.of<ChecklistService>(
      context,
      listen: false,
    ).saveChecklist(checklist);
    Navigator.of(context).pop();
  }

}
