import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../utils/form_theme_helper.dart';

/// Dialog for confirming cache clearing
class ClearCacheDialog {
  static Future<bool?> show({
    required BuildContext context,
    required String cacheName,
    bool isAllCaches = false,
  }) async {
    final content = isAllCaches
        ? 'Are you sure you want to clear all caches? This will delete all offline data including map tiles, aviation data, and weather information.'
        : 'Are you sure you want to clear the $cacheName cache? This data will be re-downloaded when needed.';

    return await showDialog<bool>(
      context: context,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: isAllCaches ? 'Clear All Caches' : 'Clear $cacheName Cache',
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            content,
            style: TextStyle(color: AppColors.primaryTextColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: FormThemeHelper.getSecondaryButtonStyle(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isAllCaches ? 'Clear All' : 'Clear'),
          ),
        ],
      ),
    );
  }
}