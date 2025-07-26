import 'package:flutter/material.dart';
import '../../flight_log_screen.dart';
import '../../offline_data_screen.dart';
import '../../flight_plans_screen.dart';
import '../../aircraft_settings_screen.dart';
import '../../checklist_settings_screen.dart';
import '../../licenses_screen.dart';
import '../../calculators_screen.dart';
import '../../settings_screen.dart';
import '../../logbook/logbook_screen.dart';

class NavigationMenu extends StatelessWidget {
  final VoidCallback onPauseTimers;
  final VoidCallback onResumeTimers;

  const NavigationMenu({
    super.key,
    required this.onPauseTimers,
    required this.onResumeTimers,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Colors.black),
      tooltip: 'Menu',
      onSelected: (value) => _handleMenuSelection(context, value),
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'flight_log',
          child: ListTile(
            leading: Icon(Icons.book),
            title: Text('Flight Log'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logbook',
          child: ListTile(
            leading: Icon(Icons.menu_book),
            title: Text('LogBook'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'offline_maps',
          child: ListTile(
            leading: Icon(Icons.map),
            title: Text('Offline Data'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'flight_plans',
          child: ListTile(
            leading: Icon(Icons.route),
            title: Text('Flight Plans'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'aircraft_settings',
          child: ListTile(
            leading: Icon(Icons.airplanemode_active),
            title: Text('Aircraft Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'checklist_settings',
          child: ListTile(
            leading: Icon(Icons.checklist),
            title: Text('Checklist Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'calculators',
          child: ListTile(
            leading: Icon(Icons.calculate),
            title: Text('Calculators'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'licenses',
          child: ListTile(
            leading: Icon(Icons.article),
            title: Text('Licenses'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _handleMenuSelection(BuildContext context, String value) {
    Widget? screen;
    
    switch (value) {
      case 'flight_log':
        screen = const FlightLogScreen();
        break;
      case 'logbook':
        screen = const LogBookScreen();
        break;
      case 'offline_maps':
        screen = const OfflineDataScreen();
        break;
      case 'flight_plans':
        screen = const FlightPlansScreen();
        break;
      case 'aircraft_settings':
        screen = const AircraftSettingsScreen();
        break;
      case 'checklist_settings':
        screen = const ChecklistSettingsScreen();
        break;
      case 'calculators':
        screen = const CalculatorsScreen();
        break;
      case 'licenses':
        screen = const LicensesScreen();
        break;
      case 'settings':
        screen = const SettingsScreen();
        break;
    }
    
    if (screen != null) {
      onPauseTimers();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen!),
      ).then((_) => onResumeTimers());
    }
  }
}