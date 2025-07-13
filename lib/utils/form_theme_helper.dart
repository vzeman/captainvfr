import 'package:flutter/material.dart';

/// Helper class providing consistent form styling across the application
class FormThemeHelper {
  // Color scheme
  static const Color primaryAccent = Color(0xFF448AFF);
  static const Color backgroundColor = Colors.black87;
  static const Color dialogBackgroundColor = Color(0xE6000000);
  static const Color sectionBackgroundColor = Color(0x1A448AFF);
  static const Color sectionBorderColor = Color(0x7F448AFF);
  static const Color primaryTextColor = Colors.white;
  static const Color secondaryTextColor = Colors.white70;
  static const Color borderColor = Color(0xFF448AFF); // Blue border like settings
  static const Color fillColor = Colors.white12;

  /// Standard input decoration for form fields
  static InputDecoration getInputDecoration(String labelText, {String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: secondaryTextColor),
      hintStyle: const TextStyle(color: secondaryTextColor),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: primaryAccent, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: fillColor,
    );
  }

  /// Standard text style for form fields
  static const TextStyle inputTextStyle = TextStyle(
    color: primaryTextColor,
    fontSize: 16,
  );

  /// Section container decoration
  static BoxDecoration getSectionDecoration() {
    return BoxDecoration(
      color: sectionBackgroundColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: sectionBorderColor),
    );
  }

  /// Section title text style
  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: primaryTextColor,
  );

  /// Standard button style for primary actions
  static ButtonStyle getPrimaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: primaryAccent,
      foregroundColor: primaryTextColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  /// Standard button style for secondary actions
  static ButtonStyle getSecondaryButtonStyle() {
    return TextButton.styleFrom(
      foregroundColor: secondaryTextColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );
  }

  /// Standard button style for outlined buttons
  static ButtonStyle getOutlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: primaryAccent,
      side: const BorderSide(color: primaryAccent),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  /// Standard AppBar theme
  static AppBarTheme getAppBarTheme() {
    return const AppBarTheme(
      backgroundColor: dialogBackgroundColor,
      foregroundColor: primaryTextColor,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: primaryTextColor,
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
      dropdownColor: dialogBackgroundColor,
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
          color: dialogBackgroundColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: sectionBorderColor, // Blue accent with 0.5 opacity
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  title,
                  style: const TextStyle(color: primaryTextColor),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close, color: primaryTextColor),
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
                      top: BorderSide(color: borderColor.withValues(alpha: 0.3)),
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