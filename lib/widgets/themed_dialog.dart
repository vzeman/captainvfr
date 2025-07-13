import 'package:flutter/material.dart';

/// A custom dialog widget that matches the flight data panel style
/// with dark background, rounded corners, and blue accent border
class ThemedDialog extends StatelessWidget {
  final String? title;
  final Widget content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final bool scrollable;
  final double? maxWidth;
  final double? maxHeight;

  const ThemedDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.contentPadding,
    this.scrollable = true,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final dialogContent = Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? 400,
        maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF0000000), // Black with 0.94 opacity
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: const Color(0x7F448AFF), // Blue accent with 0.5 opacity
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 12.0),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0x33448AFF), // Blue accent with 0.2 opacity
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
          Flexible(
            child: scrollable
                ? SingleChildScrollView(
                    padding: contentPadding ?? const EdgeInsets.all(16.0),
                    child: content,
                  )
                : Padding(
                    padding: contentPadding ?? const EdgeInsets.all(16.0),
                    child: content,
                  ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0x33448AFF), // Blue accent with 0.2 opacity
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!.map((action) {
                  if (action is TextButton) {
                    // Override text button style to match theme
                    return TextButton(
                      onPressed: action.onPressed,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF448AFF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: action.child!,
                    );
                  } else if (action is ElevatedButton) {
                    // Override elevated button style to match theme
                    return ElevatedButton(
                      onPressed: action.onPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF448AFF),
                        foregroundColor: Colors.white,
                      ),
                      child: action.child!,
                    );
                  }
                  return action;
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      child: dialogContent,
    );
  }

  /// Shows a themed dialog with the flight panel styling
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required Widget content,
    List<Widget>? actions,
    bool barrierDismissible = true,
    EdgeInsetsGeometry? contentPadding,
    bool scrollable = true,
    double? maxWidth,
    double? maxHeight,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return ThemedDialog(
          title: title,
          content: content,
          actions: actions,
          contentPadding: contentPadding,
          scrollable: scrollable,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );
      },
    );
  }

  /// Shows a simple confirmation dialog with consistent styling
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool destructive = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// Extension method to apply themed styling to existing form fields
extension ThemedFormField on Widget {
  Widget withThemedStyle() {
    if (this is TextFormField) {
      return Theme(
        data: ThemeData.dark().copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0x1A448AFF), // Blue accent with 0.1 opacity
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
            labelStyle: TextStyle(color: Colors.white70),
            hintStyle: TextStyle(color: Colors.white30),
          ),
        ),
        child: this,
      );
    }
    return this;
  }
}
