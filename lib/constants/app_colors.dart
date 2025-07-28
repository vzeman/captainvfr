import 'package:flutter/material.dart';

/// Application color constants
class AppColors {
  // Primary colors
  static const Color primaryAccent = Color(0xFF448AFF);
  static const Color primaryAccentDim = Color(0x7F448AFF);
  static const Color primaryAccentFaint = Color(0x33448AFF);
  static const Color primaryAccentVeryFaint = Color(0x1A448AFF);
  
  // Background colors
  static const Color backgroundColor = Color(0xFF000000);
  static const Color dialogBackgroundColor = Color(0xF0000000);
  static const Color sectionBackgroundColor = Color(0xFF0A0A1A);
  static const Color sectionBorderColor = Color(0xFF1A1A2E);
  static const Color fillColorFaint = Color(0x1AFFFFFF);
  
  // Text colors
  static const Color primaryTextColor = Color(0xFFFFFFFF);
  static const Color secondaryTextColor = Color(0xFFB3B3B3);
  static const Color tertiaryTextColor = Color(0xFF999999);
  static const Color labelTextColor = Color(0xFFCCCCCC);
  static const Color hintTextColor = Color(0xFF666666);
  static const Color disabledTextColor = Color(0xFF4D4D4D);
  
  // Status colors
  static const Color errorColor = Color(0xFFFF5252);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color successColor = Color(0xFF66BB6A);
  static const Color infoColor = Color(0xFF29B6F6);
  
  // Airspace colors
  static const Color airspaceProhibited = Color(0xFFD32F2F); // Red
  static const Color airspaceRestricted = Color(0xFFF57C00); // Orange
  static const Color airspaceDanger = Color(0xFF1976D2); // Blue
  static const Color airspaceMoa = Color(0xFF7B1FA2); // Purple
  static const Color airspaceTraining = Color(0xFF512DA8); // Deep purple
  static const Color airspaceGliderProhibited = Color(0xFF388E3C); // Green
  static const Color airspaceWaveWindow = Color(0xFFFFA000); // Amber
  static const Color airspaceTransponderMandatory = Color(0xFFF9A825); // Yellow dark
  static const Color airspaceClassA = Color(0xFFB71C1C); // Red 900
  static const Color airspaceClassB = Color(0xFFD32F2F); // Red 700
  static const Color airspaceClassC = Color(0xFFE65100); // Orange 900
  static const Color airspaceClassD = Color(0xFF1565C0); // Blue 800
  static const Color airspaceClassE = Color(0xFF2E7D32); // Green 800
  static const Color airspaceClassG = Color(0xFF43A047); // Green 600
  static const Color airspaceDefault = Color(0xFF616161); // Grey 700
  
  // Map feature colors
  static const Color obstacleColor = Color(0xFFD32F2F); // Red
  static const Color navaidColor = Color(0xFF1976D2); // Blue
  static const Color airportColor = Color(0xFF7B1FA2); // Purple
  
  // Opacity values as constants
  static const double highOpacity = 0.94;
  static const double mediumOpacity = 0.5;
  static const double lowOpacity = 0.2;
  static const double veryLowOpacity = 0.1;
}