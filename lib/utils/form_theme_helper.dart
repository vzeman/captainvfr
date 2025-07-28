import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

/// Helper class providing consistent form styling across the application
class FormThemeHelper {

  /// Standard input decoration for form fields
  static InputDecoration getInputDecoration(String labelText, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(color: AppColors.labelTextColor),
      hintStyle: TextStyle(color: AppColors.tertiaryTextColor),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primaryAccent),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primaryAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.errorColor, width: 2),
      ),
      filled: true,
      fillColor: AppColors.fillColorFaint,
    );
  }

  /// Standard text style for form fields
  static const TextStyle inputTextStyle = TextStyle(
    color: AppColors.primaryTextColor,
    fontSize: 16,
  );

  /// Section container decoration
  static BoxDecoration getSectionDecoration() {
    return BoxDecoration(
      color: AppColors.sectionBackgroundColor,
      borderRadius: AppTheme.sectionRadius,
      border: Border.all(color: AppColors.sectionBorderColor),
    );
  }

  /// Section title text style
  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryTextColor,
  );

  /// Standard button style for primary actions
  static ButtonStyle getPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryAccent,
      foregroundColor: AppColors.primaryTextColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.buttonRadius,
      ),
    );
  }

  /// Standard button style for secondary actions
  static ButtonStyle getSecondaryButtonStyle() {
    return TextButton.styleFrom(
      foregroundColor: AppColors.primaryTextColor, // Use white for better contrast
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );
  }

  /// Standard button style for outlined buttons
  static ButtonStyle getOutlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryAccent,
      side: const BorderSide(color: AppColors.primaryAccent),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.buttonRadius,
      ),
    );
  }

  /// Standard AppBar theme
  static AppBarTheme getAppBarTheme() {
    return const AppBarTheme(
      backgroundColor: AppColors.dialogBackgroundColor,
      foregroundColor: AppColors.primaryTextColor,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.primaryTextColor,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Helper method to build a standard form field
  static Widget buildFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      style: inputTextStyle,
      decoration: getInputDecoration(labelText, hintText: hintText),
      maxLines: maxLines,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
    );
  }

  /// Helper method to build a standard dropdown field
  static Widget buildDropdownField<T>({
    required T? value,
    required String labelText,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      style: inputTextStyle,
      dropdownColor: AppColors.dialogBackgroundColor,
      decoration: getInputDecoration(labelText),
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
    );
  }

  /// Helper method to build a section container
  static Widget buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: getSectionDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: sectionTitleStyle),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Helper method to build a standard dialog
  static Widget buildDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    double? width,
    double? height,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    // Responsive sizing based on orientation
    final responsiveWidth = width ?? (isLandscape ? 
      (screenSize.width * 0.6).clamp(500.0, 800.0) : 
      (screenSize.width * 0.9).clamp(300.0, 500.0));
    
    final responsiveHeight = height ?? (isLandscape ? 
      screenSize.height * 0.85 : 
      screenSize.height * 0.8);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: responsiveWidth,
        height: responsiveHeight,
        decoration: BoxDecoration(
          color: AppColors.dialogBackgroundColor,
          borderRadius: AppTheme.dialogRadius,
          border: Border.all(
            color: AppColors.sectionBorderColor, // Blue accent with 0.5 opacity
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: AppTheme.dialogRadius,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  title,
                  style: const TextStyle(color: AppColors.primaryTextColor),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.primaryTextColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(child: content),
              if (actions != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}