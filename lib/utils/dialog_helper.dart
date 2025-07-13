import 'package:flutter/material.dart';
import '../widgets/themed_dialog.dart';

/// Helper class to convert existing dialogs to themed dialogs
class DialogHelper {
  /// Shows a themed alert dialog that replaces the standard AlertDialog
  static Future<T?> showAlertDialog<T>({
    required BuildContext context,
    String? title,
    Widget? content,
    List<Widget>? actions,
    bool barrierDismissible = true,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return ThemedDialog.show<T>(
      context: context,
      title: title,
      content: content ?? const SizedBox.shrink(),
      actions: actions,
      barrierDismissible: barrierDismissible,
      contentPadding: contentPadding,
    );
  }

  /// Shows a themed input dialog for entering text
  static Future<String?> showInputDialog({
    required BuildContext context,
    required String title,
    String? initialValue,
    String? hintText,
    String? labelText,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return ThemedDialog.show<String>(
      context: context,
      title: title,
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            labelText: labelText,
            filled: true,
            fillColor: const Color(0x1A448AFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0x7F448AFF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0x7F448AFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF448AFF), width: 2),
            ),
            hintStyle: const TextStyle(color: Colors.white30),
            labelStyle: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () {
            if (validator != null && formKey.currentState != null) {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text);
              }
            } else {
              Navigator.of(context).pop(controller.text);
            }
          },
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// Shows a themed selection dialog with a list of options
  static Future<T?> showSelectionDialog<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required String Function(T) itemBuilder,
    Widget Function(T)? leadingBuilder,
    Widget Function(T)? trailingBuilder,
    T? selectedItem,
    String? emptyMessage,
    String cancelText = 'Cancel',
  }) {
    return ThemedDialog.show<T>(
      context: context,
      title: title,
      content: items.isEmpty
          ? Text(
              emptyMessage ?? 'No items available',
              style: const TextStyle(color: Colors.white70),
            )
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item == selectedItem;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0x1A448AFF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0x7F448AFF)
                            : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      leading: leadingBuilder?.call(item),
                      title: Text(
                        itemBuilder(item),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF448AFF),
                            )
                          : trailingBuilder?.call(item),
                      onTap: () => Navigator.of(context).pop(item),
                    ),
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelText),
        ),
      ],
    );
  }

  /// Shows a themed loading dialog with a spinner
  static Future<void> showLoadingDialog({
    required BuildContext context,
    String? message,
  }) {
    return ThemedDialog.show(
      context: context,
      barrierDismissible: false,
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF448AFF)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              message ?? 'Loading...',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
