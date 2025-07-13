import 'package:flutter/material.dart';
import '../models/checklist_item.dart';
import '../utils/form_theme_helper.dart';

/// Dialog to add or edit a checklist item.
class ChecklistItemFormDialog extends StatefulWidget {
  final ChecklistItem? item;
  const ChecklistItemFormDialog({super.key, this.item});

  @override
  State<ChecklistItemFormDialog> createState() =>
      _ChecklistItemFormDialogState();
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
    return FormThemeHelper.buildDialog(
      context: context,
      title: widget.item == null ? 'Add Item' : 'Edit Item',
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormThemeHelper.buildFormField(
                controller: _nameController,
                labelText: 'Name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FormThemeHelper.buildFormField(
                controller: _descriptionController,
                labelText: 'Description',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              FormThemeHelper.buildFormField(
                controller: _targetValueController,
                labelText: 'Target Value',
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
          onPressed: _save,
          style: FormThemeHelper.getPrimaryButtonStyle(),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.item?.id ?? UniqueKey().toString();
    final newItem = ChecklistItem(
      id: id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      targetValue: _targetValueController.text.trim().isEmpty
          ? null
          : _targetValueController.text.trim(),
    );
    Navigator.of(context).pop(newItem);
  }
}
