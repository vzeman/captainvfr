import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

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
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    // Responsive sizing based on orientation and screen size
    final responsiveMaxWidth = maxWidth ?? (isLandscape ? 
      (screenSize.width * 0.5).clamp(400.0, 600.0) : 
      (screenSize.width * 0.9).clamp(300.0, 400.0));
    
    final responsiveMaxHeight = maxHeight ?? (isLandscape ? 
      screenSize.height * 0.9 : 
      screenSize.height * 0.8);
    
    final dialogContent = Container(
      constraints: BoxConstraints(
        maxWidth: responsiveMaxWidth,
        maxHeight: responsiveMaxHeight,
      ),
      decoration: BoxDecoration(
        color: AppColors.dialogBackgroundColor,
        borderRadius: AppTheme.dialogRadius,
        border: Border.all(
          color: AppColors.primaryAccentDim,
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
                    color: AppColors.primaryAccentFaint,
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
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.primaryTextColor,
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
                    color: AppColors.primaryAccentFaint,
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
                        foregroundColor: AppColors.primaryAccent,
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
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: AppColors.primaryTextColor,
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
      shadowColor: Colors.black.withValues(alpha: AppColors.mediumOpacity),
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
      barrierColor: Colors.black.withValues(alpha: 0.87),
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
      content: Text(message, style: TextStyle(color: AppColors.labelTextColor)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorColor,
                  foregroundColor: AppColors.primaryTextColor,
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
            fillColor: AppColors.primaryAccentVeryFaint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppTheme.formFieldBorderRadius)),
              borderSide: BorderSide(color: AppColors.primaryAccentDim),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppTheme.formFieldBorderRadius)),
              borderSide: BorderSide(color: AppColors.primaryAccentDim),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppTheme.formFieldBorderRadius)),
              borderSide: BorderSide(color: AppColors.primaryAccent, width: 2.0),
            ),
            labelStyle: TextStyle(color: AppColors.labelTextColor),
            hintStyle: TextStyle(color: AppColors.tertiaryTextColor),
          ),
        ),
        child: this,
      );
    }
    return this;
  }
}
