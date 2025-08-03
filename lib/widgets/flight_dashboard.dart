import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/flight_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/barometer_service.dart';
import '../services/heading_service.dart';
import 'flight_dashboard/components/expanded_view.dart';
import 'flight_dashboard/components/collapsed_view.dart';
import '../constants/app_theme.dart';

class FlightDashboard extends StatefulWidget {
  final bool? isExpanded;
  final Function(bool)? onExpandedChanged;

  const FlightDashboard({super.key, this.isExpanded, this.onExpandedChanged});

  @override
  State<FlightDashboard> createState() => _FlightDashboardState();
}

class _FlightDashboardState extends State<FlightDashboard> with WidgetsBindingObserver {
  late bool _isExpanded;
  Timer? _headingCheckTimer;
  bool _hasShownPermissionDialog = false;
  static const String _permissionNotificationKey = 'has_shown_location_permission_notification';

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded ?? true;
    
    // Add lifecycle observer to detect when app returns from background
    WidgetsBinding.instance.addObserver(this);
    
    // Load saved preference for permission notification
    _loadPermissionNotificationPreference();

    // Auto-select aircraft and start heading service after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectAircraft();
      _startHeadingService();
      _startPeriodicHeadingCheck();
    });
  }
  
  Future<void> _loadPermissionNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _hasShownPermissionDialog = prefs.getBool(_permissionNotificationKey) ?? false;
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App returned from background - refresh heading service
      // This happens when user returns from Settings
      _startHeadingService();
    }
  }

  void _autoSelectAircraft() {
    final aircraftService = context.read<AircraftSettingsService>();
    final flightService = context.read<FlightService>();

    // Only auto-select if no aircraft is currently selected
    if (aircraftService.selectedAircraft == null &&
        aircraftService.aircrafts.isNotEmpty) {
      if (aircraftService.aircrafts.length == 1) {
        // Only one aircraft - auto-select it
        aircraftService.aircraftService.selectAircraft(
          aircraftService.aircrafts.first.id,
        );
        if (flightService.isTracking) {
          flightService.setAircraft(aircraftService.aircrafts.first);
        }
      } else if (aircraftService.aircrafts.length > 1) {
        // Multiple aircraft - try to select the last used one
        final flights = flightService.flights;
        if (flights.isNotEmpty) {
          // Since Flight model doesn't have aircraftId, we can't implement this yet
          // For now, just select the first aircraft
          aircraftService.aircraftService.selectAircraft(
            aircraftService.aircrafts.first.id,
          );
          if (flightService.isTracking) {
            flightService.setAircraft(aircraftService.aircrafts.first);
          }
        }
      }
    }
  }

  void _startHeadingService() async {
    // Start heading service when panel is shown
    final headingService = context.read<HeadingService>();
    
    // Always try to start/restart the service
    await headingService.retryStart();
    
    // Only show permission notification once and only if permission is actually denied
    if (!_hasShownPermissionDialog && mounted) {
      // Check actual permission status
      final whenInUseStatus = await Permission.locationWhenInUse.status;
      final alwaysStatus = await Permission.locationAlways.status;
      
      // Only show notification if permission is truly denied or permanently denied
      if ((whenInUseStatus.isDenied || whenInUseStatus.isPermanentlyDenied) &&
          (alwaysStatus.isDenied || alwaysStatus.isPermanentlyDenied)) {
        _hasShownPermissionDialog = true;
        _showPermissionDeniedNotification();
      }
    }
  }
  
  void _startPeriodicHeadingCheck() {
    // Check heading service every 2 seconds to ensure it's running
    _headingCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final headingService = context.read<HeadingService>();
      if (!headingService.isRunning && !headingService.hasError) {
        headingService.retryStart();
      }
    });
  }

  void _showPermissionDeniedNotification() async {
    if (!mounted) return;
    
    // Save that we've shown the notification
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionNotificationKey, true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SizedBox(
          height: 36,
          child: Row(
            children: [
              const Icon(
                Icons.location_off,
                color: Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location permission needed',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Enable for compass heading',
                      style: TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  openAppSettings();
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(50, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    color: Color(0xFF448AFF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xE6000000),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(
            color: Color(0x7F448AFF),
            width: 1.0,
          ),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _toggleExpanded(bool expanded) {
    setState(() {
      _isExpanded = expanded;
    });
    widget.onExpandedChanged?.call(expanded);
  }

  @override
  void dispose() {
    _headingCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flightService = Provider.of<FlightService>(context);
    final barometerService = Provider.of<BarometerService>(context);

    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    // Responsive margins and width
    final horizontalMargin = isPhone ? 8.0 : 16.0;
    final maxWidth = isPhone ? double.infinity : (isTablet ? 600.0 : 800.0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: 16.0,
      ),
      constraints: BoxConstraints(
        minHeight: _isExpanded ? 160 : 60,
        maxHeight: _isExpanded ? 260 : 60,
        minWidth: 300,
        maxWidth: maxWidth,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(_isExpanded ? 12.0 : 8.0),
          decoration: BoxDecoration(
            color: const Color(0xB3000000), // Black with 0.7 opacity
            borderRadius: AppTheme.largeRadius,
            border: Border.all(
              color: const Color(0x7F448AFF),
              width: 1.0,
            ), // Blue accent with 0.5 opacity
          ),
          child: _isExpanded
              ? ExpandedView(
                  onCollapse: () => _toggleExpanded(false),
                  flightService: flightService,
                  barometerService: barometerService,
                )
              : CollapsedView(
                  onExpand: () => _toggleExpanded(true),
                ),
        ),
      ),
    );
  }
}
