import 'package:flutter/material.dart';
import '../../../constants/app_theme.dart';

/// Dialog shown when user wants to stop flight tracking
class StopTrackingDialog extends StatelessWidget {
  const StopTrackingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.dialogRadius,
      ),
      title: const Text('Stop Flight Tracking?'),
      content: const Text(
        'Do you want to stop recording your flight?',
      ),
      actions: [
        // Continue tracking button (Green)
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.buttonRadius,
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(false); // Don't stop tracking
          },
          child: const Text(
            'Continue tracking',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        // Stop button (Red)
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.buttonRadius,
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(true); // Stop tracking
          },
          child: const Text(
            'Stop',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.all(16),
    );
  }
  
  /// Show the dialog and return whether to stop tracking
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext context) {
        return const StopTrackingDialog();
      },
    );
  }
}