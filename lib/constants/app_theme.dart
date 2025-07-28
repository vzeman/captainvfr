import 'package:flutter/material.dart';

/// Application theme constants
class AppTheme {
  // Border radius constants - Maximum 8px as per design requirements
  static const double borderRadiusSmall = 2.0;
  static const double borderRadiusMedium = 3.0;
  static const double borderRadiusDefault = 4.0;
  static const double borderRadiusLarge = 6.0; // Capped at 8px
  static const double borderRadiusExtraLarge = 8.0; // Capped at 8px
  static const double borderRadiusCircular = 8.0; // Capped at 8px
  
  // Standard border radius for dialogs and forms
  static const double dialogBorderRadius = borderRadiusDefault;
  static const double formFieldBorderRadius = borderRadiusDefault;
  static const double buttonBorderRadius = borderRadiusDefault;
  static const double cardBorderRadius = borderRadiusDefault;
  static const double chipBorderRadius = borderRadiusDefault; // Changed to 8px
  static const double sectionBorderRadius = borderRadiusDefault; // Changed to 8px
  
  // Pre-defined BorderRadius objects for convenience
  static BorderRadius get smallRadius => BorderRadius.circular(borderRadiusSmall);
  static BorderRadius get mediumRadius => BorderRadius.circular(borderRadiusMedium);
  static BorderRadius get defaultRadius => BorderRadius.circular(borderRadiusDefault);
  static BorderRadius get largeRadius => BorderRadius.circular(borderRadiusLarge);
  static BorderRadius get extraLargeRadius => BorderRadius.circular(borderRadiusExtraLarge);
  static BorderRadius get circularRadius => BorderRadius.circular(borderRadiusCircular);
  
  // Specific BorderRadius for common UI elements
  static BorderRadius get dialogRadius => BorderRadius.circular(dialogBorderRadius);
  static BorderRadius get formFieldRadius => BorderRadius.circular(formFieldBorderRadius);
  static BorderRadius get buttonRadius => BorderRadius.circular(buttonBorderRadius);
  static BorderRadius get cardRadius => BorderRadius.circular(cardBorderRadius);
  static BorderRadius get chipRadius => BorderRadius.circular(chipBorderRadius);
  static BorderRadius get sectionRadius => BorderRadius.circular(sectionBorderRadius);
  
  // Spacing constants
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingDefault = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;
  
  // Font sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeDefault = 14.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeLarge = 18.0;
  static const double fontSizeXLarge = 20.0;
  static const double fontSizeXXLarge = 24.0;
  
  // Icon sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeDefault = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;
  
  // Component heights
  static const double buttonHeight = 48.0;
  static const double inputFieldHeight = 56.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 60.0;
  
  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationDefault = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Elevation values
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;
  static const double elevationVeryHigh = 16.0;
}