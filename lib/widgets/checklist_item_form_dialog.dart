import 'package:flutter/material.dart';
import '../models/checklist_item.dart';

/// Dialog to add or edit a checklist item.
class ChecklistItemFormDialog extends StatefulWidget {
  final ChecklistItem? item;
  const ChecklistItemFormDialog({Key? key, this.item}) : super(key: key);

  @override
  State<ChecklistItemFormDialog> createState() => _ChecklistItemFormDialogState();
}

class _ChecklistItemFormDialogState extends State<ChecklistItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _descriptionController.text = widget.item!.description ?? '';
      _targetValueController.text = widget.item!.targetValue ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter item name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _targetValueController,
                    decoration: const InputDecoration(labelText: 'Target Value', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.item?.id ?? UniqueKey().toString();
    final newItem = ChecklistItem(
      id: id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      targetValue: _targetValueController.text.trim().isEmpty ? null : _targetValueController.text.trim(),
    );
    Navigator.of(context).pop(newItem);
  }
}
