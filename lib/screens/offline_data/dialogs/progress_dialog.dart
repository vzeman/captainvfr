import 'package:flutter/material.dart';
import '../../../utils/form_theme_helper.dart';

/// Progress dialog for long-running operations
class ProgressDialog {
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    String? subtitle,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FormThemeHelper.buildDialog(
          context: context,
          title: title,
          content: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(color: FormThemeHelper.primaryTextColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: FormThemeHelper.secondaryTextColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static void hide(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}