import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../widgets/themed_dialog.dart';
import '../services/settings_service.dart';
import '../services/offline_map_service.dart';
import '../services/cache_service.dart';
import '../services/airport_service.dart';
import '../services/navaid_service.dart';
import '../services/weather_service.dart';
import '../constants/app_theme.dart';
import '../constants/app_colors.dart';
import 'offline_data/controllers/offline_data_state_controller.dart';
import 'offline_data/sections/download_map_tiles_section.dart';
import 'offline_data/dialogs/clear_cache_dialog.dart';
import 'offline_data/helpers/date_formatter.dart';
import 'offline_data/helpers/cache_statistics_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xE6000000),
      ),
      backgroundColor: Colors.black87,
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                title: 'Map Settings',
                children: [
                  _buildSwitchTile(
                    title: 'Rotate Map with Heading',
                    subtitle:
                        'Map rotates to match aircraft heading during tracking',
                    value: settings.rotateMapWithHeading,
                    onChanged: (value) =>
                        settings.setRotateMapWithHeading(value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Flight Tracking',
                children: [
                  _buildSwitchTile(
                    title: 'High Precision Mode',
                    subtitle: 'Use high accuracy GPS (uses more battery)',
                    value: settings.highPrecisionTracking,
                    onChanged: (value) =>
                        settings.setHighPrecisionTracking(value),
                  ),
                  _buildSwitchTile(
                    title: 'Auto-create Logbook Entry',
                    subtitle: 'Automatically create logbook entry after flight',
                    value: settings.autoCreateLogbookEntry,
                    onChanged: (value) =>
                        settings.setAutoCreateLogbookEntry(value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Development',
                children: [
                  _buildSwitchTile(
                    title: 'Development Mode',
                    subtitle: 'Show performance debug information',
                    value: settings.developmentMode,
                    onChanged: (value) =>
                        settings.setDevelopmentMode(value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Unit Settings',
                children: [
                  // Legacy unit selector for quick presets
                  ListTile(
                    title: const Text(
                      'Quick Presets',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Apply common unit combinations',
                      style: TextStyle(color: Colors.white70),
                    ),
                    trailing: DropdownButton<String>(
                      value: settings.units,
                      dropdownColor: const Color(0xE6000000),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                          value: 'european_aviation',
                          child: Text('European Aviation'),
                        ),
                        DropdownMenuItem(
                          value: 'us_general_aviation',
                          child: Text('US General Aviation'),
                        ),
                        DropdownMenuItem(
                          value: 'metric_preference',
                          child: Text('Metric Preference'),
                        ),
                        DropdownMenuItem(
                          value: 'mixed_international',
                          child: Text('Mixed International'),
                        ),
                        DropdownMenuItem(
                          value: 'metric',
                          child: Text('Legacy Metric'),
                        ),
                        DropdownMenuItem(
                          value: 'imperial',
                          child: Text('Legacy Imperial'),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value != null) {
                          await settings.setUnits(value);
                          // Apply preset unit combinations
                          switch (value) {
                            case 'european_aviation':
                              await settings.setAltitudeUnit('ft');
                              await settings.setDistanceUnit('km');
                              await settings.setSpeedUnit('kt');
                              await settings.setTemperatureUnit('C');
                              await settings.setWeightUnit('kg');
                              await settings.setFuelUnit('L');
                              await settings.setWindUnit('kt');
                              await settings.setPressureUnit('hPa');
                              break;
                            case 'us_general_aviation':
                              await settings.setAltitudeUnit('ft');
                              await settings.setDistanceUnit('nm');
                              await settings.setSpeedUnit('kt');
                              await settings.setTemperatureUnit('F');
                              await settings.setWeightUnit('lbs');
                              await settings.setFuelUnit('gal');
                              await settings.setWindUnit('kt');
                              await settings.setPressureUnit('inHg');
                              break;
                            case 'metric_preference':
                              await settings.setAltitudeUnit('m');
                              await settings.setDistanceUnit('km');
                              await settings.setSpeedUnit('km/h');
                              await settings.setTemperatureUnit('C');
                              await settings.setWeightUnit('kg');
                              await settings.setFuelUnit('L');
                              await settings.setWindUnit('km/h');
                              await settings.setPressureUnit('hPa');
                              break;
                            case 'mixed_international':
                              await settings.setAltitudeUnit('ft');
                              await settings.setDistanceUnit('nm');
                              await settings.setSpeedUnit('kt');
                              await settings.setTemperatureUnit('C');
                              await settings.setWeightUnit('kg');
                              await settings.setFuelUnit('L');
                              await settings.setWindUnit('kt');
                              await settings.setPressureUnit('hPa');
                              break;
                            case 'metric':
                              await settings.setAltitudeUnit('m');
                              await settings.setDistanceUnit('km');
                              await settings.setSpeedUnit('km/h');
                              await settings.setTemperatureUnit('C');
                              await settings.setWeightUnit('kg');
                              await settings.setFuelUnit('L');
                              await settings.setWindUnit('km/h');
                              await settings.setPressureUnit('hPa');
                              break;
                            case 'imperial':
                              await settings.setAltitudeUnit('ft');
                              await settings.setDistanceUnit('nm');
                              await settings.setSpeedUnit('kt');
                              await settings.setTemperatureUnit('C');
                              await settings.setWeightUnit('lbs');
                              await settings.setFuelUnit('gal');
                              await settings.setWindUnit('kt');
                              await settings.setPressureUnit('inHg');
                              break;
                          }
                        }
                      },
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  
                  // Individual unit controls
                  _buildUnitDropdown(
                    'Altitude',
                    settings.altitudeUnit,
                    const ['ft', 'm'],
                    const ['Feet', 'Meters'],
                    settings.setAltitudeUnit,
                  ),
                  _buildUnitDropdown(
                    'Distance',
                    settings.distanceUnit,
                    const ['nm', 'km', 'mi'],
                    const ['Nautical Miles', 'Kilometers', 'Statute Miles'],
                    settings.setDistanceUnit,
                  ),
                  _buildUnitDropdown(
                    'Airspeed',
                    settings.speedUnit,
                    const ['kt', 'mph', 'km/h'],
                    const ['Knots', 'Miles per Hour', 'Kilometers per Hour'],
                    settings.setSpeedUnit,
                  ),
                  _buildUnitDropdown(
                    'Wind Speed',
                    settings.windUnit,
                    const ['kt', 'mph', 'km/h'],
                    const ['Knots', 'Miles per Hour', 'Kilometers per Hour'],
                    settings.setWindUnit,
                  ),
                  _buildUnitDropdown(
                    'Temperature',
                    settings.temperatureUnit,
                    const ['C', 'F'],
                    const ['Celsius', 'Fahrenheit'],
                    settings.setTemperatureUnit,
                  ),
                  _buildUnitDropdown(
                    'Weight',
                    settings.weightUnit,
                    const ['lbs', 'kg'],
                    const ['Pounds', 'Kilograms'],
                    settings.setWeightUnit,
                  ),
                  _buildUnitDropdown(
                    'Fuel',
                    settings.fuelUnit,
                    const ['gal', 'L'],
                    const ['US Gallons', 'Liters'],
                    settings.setFuelUnit,
                  ),
                  _buildUnitDropdown(
                    'Pressure',
                    settings.pressureUnit,
                    const ['inHg', 'hPa'],
                    const ['Inches of Mercury', 'Hectopascals'],
                    settings.setPressureUnit,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: () => _showResetDialog(context, settings),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reset to Defaults'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x1A448AFF),
        borderRadius: AppTheme.defaultRadius,
        border: Border.all(color: const Color(0x7F448AFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF448AFF),
    );
  }

  void _showResetDialog(BuildContext context, SettingsService settings) {
    ThemedDialog.showConfirmation(
      context: context,
      title: 'Reset Settings',
      message:
          'Are you sure you want to reset all settings to their default values?',
      confirmText: 'Reset',
      cancelText: 'Cancel',
      destructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        settings.resetToDefaults();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings reset to defaults'),
              backgroundColor: Color(0xE6000000),
            ),
          );
        }
      }
    });
  }

  Widget _buildUnitDropdown(
    String title,
    String currentValue,
    List<String> values,
    List<String> displayNames,
    Future<void> Function(String) onChanged,
  ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: DropdownButton<String>(
        value: currentValue,
        dropdownColor: const Color(0xE6000000),
        style: const TextStyle(color: Colors.white),
        items: values.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          return DropdownMenuItem(
            value: value,
            child: Text(displayNames[index]),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}

/// Settings dialog that can be shown as a modal
class SettingsDialog extends StatefulWidget {
  final LatLngBounds? currentMapBounds;
  
  const SettingsDialog({
    super.key,
    this.currentMapBounds,
  });

  static Future<void> show(BuildContext context, {LatLngBounds? currentMapBounds}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.87),
      builder: (BuildContext context) {
        return SettingsDialog(currentMapBounds: currentMapBounds);
      },
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OfflineMapService _offlineMapService = OfflineMapService();
  final CacheService _cacheService = CacheService();
  final AirportService _airportService = AirportService();
  final NavaidService _navaidService = NavaidService();
  final WeatherService _weatherService = WeatherService();
  final OfflineDataStateController _stateController = OfflineDataStateController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllCacheStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCacheStats() async {
    _stateController.setLoading(true);

    try {
      await _cacheService.initialize();
      await _weatherService.initialize();
      await _offlineMapService.initialize();

      final mapStats = await _offlineMapService.getCacheStatistics();
      final stats = await CacheStatisticsHelper.getCacheStatistics(_weatherService);

      _stateController.setMapCacheStats(mapStats);
      _stateController.setCacheStats(stats);
      _stateController.setLoading(false);
    } catch (e) {
      _stateController.setLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cache stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    final responsiveWidth = isLandscape ? 
      (screenSize.width * 0.6).clamp(500.0, 800.0) : 
      (screenSize.width * 0.9).clamp(300.0, 500.0);
    
    final responsiveHeight = isLandscape ? 
      screenSize.height * 0.85 : 
      screenSize.height * 0.8;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: responsiveWidth,
        height: responsiveHeight,
        decoration: BoxDecoration(
          color: AppColors.dialogBackgroundColor,
          borderRadius: AppTheme.dialogRadius,
          border: Border.all(
            color: AppColors.primaryAccentDim,
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            // Header with tabs
            Container(
              decoration: BoxDecoration(
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
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primaryAccent,
                      labelColor: AppColors.primaryAccent,
                      unselectedLabelColor: AppColors.secondaryTextColor,
                      tabs: const [
                        Tab(text: 'Settings'),
                        Tab(text: 'Offline Data'),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.primaryTextColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Settings Tab
                  _buildSettingsTab(),
                  // Offline Data Tab
                  _buildOfflineDataTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactSection(
                title: 'Map',
                children: [
                  _buildCompactSwitch(
                    'Rotate with heading',
                    settings.rotateMapWithHeading,
                    (value) => settings.setRotateMapWithHeading(value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCompactSection(
                title: 'Tracking',
                children: [
                  _buildCompactSwitch(
                    'High precision GPS',
                    settings.highPrecisionTracking,
                    (value) => settings.setHighPrecisionTracking(value),
                  ),
                  _buildCompactSwitch(
                    'Auto-create logbook',
                    settings.autoCreateLogbookEntry,
                    (value) => settings.setAutoCreateLogbookEntry(value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCompactSection(
                title: 'Development',
                children: [
                  _buildCompactSwitch(
                    'Development mode',
                    settings.developmentMode,
                    (value) => settings.setDevelopmentMode(value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCompactSection(
                title: 'Units',
                children: [
                  // Quick Presets
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Presets',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        SizedBox(
                          height: 28,
                          child: DropdownButton<String>(
                            value: settings.units,
                            dropdownColor: const Color(0xE6000000),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'european_aviation',
                                child: Text('European Aviation'),
                              ),
                              DropdownMenuItem(
                                value: 'us_general_aviation',
                                child: Text('US General Aviation'),
                              ),
                              DropdownMenuItem(
                                value: 'metric_preference',
                                child: Text('Metric Preference'),
                              ),
                              DropdownMenuItem(
                                value: 'mixed_international',
                                child: Text('Mixed International'),
                              ),
                              DropdownMenuItem(
                                value: 'metric',
                                child: Text('Legacy Metric'),
                              ),
                              DropdownMenuItem(
                                value: 'imperial',
                                child: Text('Legacy Imperial'),
                              ),
                            ],
                            onChanged: (value) async {
                              if (value != null) {
                                await settings.setUnits(value);
                                // Apply preset unit combinations
                                switch (value) {
                                  case 'european_aviation':
                                    await settings.setAltitudeUnit('ft');
                                    await settings.setDistanceUnit('km');
                                    await settings.setSpeedUnit('kt');
                                    await settings.setTemperatureUnit('C');
                                    await settings.setWeightUnit('kg');
                                    await settings.setFuelUnit('L');
                                    await settings.setWindUnit('kt');
                                    await settings.setPressureUnit('hPa');
                                    break;
                                  case 'us_general_aviation':
                                    await settings.setAltitudeUnit('ft');
                                    await settings.setDistanceUnit('nm');
                                    await settings.setSpeedUnit('kt');
                                    await settings.setTemperatureUnit('F');
                                    await settings.setWeightUnit('lbs');
                                    await settings.setFuelUnit('gal');
                                    await settings.setWindUnit('kt');
                                    await settings.setPressureUnit('inHg');
                                    break;
                                  case 'metric_preference':
                                    await settings.setAltitudeUnit('m');
                                    await settings.setDistanceUnit('km');
                                    await settings.setSpeedUnit('km/h');
                                    await settings.setTemperatureUnit('C');
                                    await settings.setWeightUnit('kg');
                                    await settings.setFuelUnit('L');
                                    await settings.setWindUnit('km/h');
                                    await settings.setPressureUnit('hPa');
                                    break;
                                  case 'mixed_international':
                                    await settings.setAltitudeUnit('ft');
                                    await settings.setDistanceUnit('nm');
                                    await settings.setSpeedUnit('kt');
                                    await settings.setTemperatureUnit('C');
                                    await settings.setWeightUnit('kg');
                                    await settings.setFuelUnit('L');
                                    await settings.setWindUnit('kt');
                                    await settings.setPressureUnit('hPa');
                                    break;
                                  case 'metric':
                                    await settings.setAltitudeUnit('m');
                                    await settings.setDistanceUnit('km');
                                    await settings.setSpeedUnit('km/h');
                                    await settings.setTemperatureUnit('C');
                                    await settings.setWeightUnit('kg');
                                    await settings.setFuelUnit('L');
                                    await settings.setWindUnit('km/h');
                                    await settings.setPressureUnit('hPa');
                                    break;
                                  case 'imperial':
                                    await settings.setAltitudeUnit('ft');
                                    await settings.setDistanceUnit('nm');
                                    await settings.setSpeedUnit('kt');
                                    await settings.setTemperatureUnit('C');
                                    await settings.setWeightUnit('lbs');
                                    await settings.setFuelUnit('gal');
                                    await settings.setWindUnit('kt');
                                    await settings.setPressureUnit('inHg');
                                    break;
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Individual unit controls
                  _buildCompactUnitDropdown('Altitude', settings.altitudeUnit, 
                    ['ft', 'm'], settings.setAltitudeUnit),
                  _buildCompactUnitDropdown('Distance', settings.distanceUnit, 
                    ['nm', 'km', 'mi'], settings.setDistanceUnit),
                  _buildCompactUnitDropdown('Speed', settings.speedUnit, 
                    ['kt', 'mph', 'km/h'], settings.setSpeedUnit),
                  _buildCompactUnitDropdown('Wind', settings.windUnit, 
                    ['kt', 'mph', 'km/h'], settings.setWindUnit),
                  _buildCompactUnitDropdown('Temperature', settings.temperatureUnit, 
                    ['C', 'F'], settings.setTemperatureUnit),
                  _buildCompactUnitDropdown('Weight', settings.weightUnit, 
                    ['lbs', 'kg'], settings.setWeightUnit),
                  _buildCompactUnitDropdown('Fuel', settings.fuelUnit, 
                    ['gal', 'L'], settings.setFuelUnit),
                  _buildCompactUnitDropdown('Pressure', settings.pressureUnit, 
                    ['inHg', 'hPa'], settings.setPressureUnit),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineDataTab() {
    return ListenableBuilder(
      listenable: _stateController,
      builder: (context, child) {
        if (_stateController.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Aviation Data Caches Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Aviation Data Caches',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _stateController.isRefreshing ? null : _refreshAllData,
                        tooltip: 'Refresh all data',
                        color: AppColors.primaryAccent,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(maxHeight: 32, maxWidth: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, size: 20),
                        onPressed: _clearAllCaches,
                        tooltip: 'Clear all caches',
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(maxHeight: 32, maxWidth: 32),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Cache cards in a more compact format
              _buildCompactCacheCard(
                title: 'Airports',
                icon: Icons.flight_land,
                count: _stateController.cacheStats['airports']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['airports']?['lastFetch']),
                onClear: () => _clearSpecificCache('Airports'),
              ),
              _buildCompactCacheCard(
                title: 'Navigation Aids',
                icon: Icons.radar,
                count: _stateController.cacheStats['navaids']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['navaids']?['lastFetch']),
                onClear: () => _clearSpecificCache('Navaids'),
              ),
              _buildCompactCacheCard(
                title: 'Runways',
                icon: Icons.horizontal_rule,
                count: _stateController.cacheStats['runways']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['runways']?['lastFetch']),
                onClear: () => _clearSpecificCache('Runways'),
              ),
              _buildCompactCacheCard(
                title: 'Frequencies',
                icon: Icons.radio,
                count: _stateController.cacheStats['frequencies']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['frequencies']?['lastFetch']),
                onClear: () => _clearSpecificCache('Frequencies'),
              ),
              _buildCompactCacheCard(
                title: 'Weather',
                icon: Icons.cloud,
                count: (_stateController.cacheStats['weather']?['metars'] ?? 0) + 
                       (_stateController.cacheStats['weather']?['tafs'] ?? 0),
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['weather']?['lastFetch']),
                onClear: () => _clearSpecificCache('Weather'),
                onRefresh: _refreshWeatherData,
              ),

              const SizedBox(height: 16),

              // Offline Map Tiles Section
              const Text(
                'Offline Map Tiles',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),

              // Map tiles cache card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x1A448AFF),
                  borderRadius: AppTheme.defaultRadius,
                  border: Border.all(color: AppColors.primaryAccentFaint),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.map, color: AppColors.primaryAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Map Tiles: ${(_stateController.mapCacheStats?['totalTiles'] as int?) ?? 0}',
                                style: const TextStyle(
                                  color: AppColors.primaryTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatFileSize((_stateController.mapCacheStats?['totalSizeBytes'] as int?) ?? 0),
                                style: const TextStyle(
                                  color: AppColors.secondaryTextColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _clearSpecificCache('Map Tiles'),
                          color: Colors.red,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Download controls
                    DownloadMapTilesSection(
                      controller: _stateController,
                      onDownload: _downloadCurrentArea,
                      onStopDownload: _stopDownload,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactCacheCard({
    required String title,
    required IconData icon,
    required int count,
    required String lastFetch,
    required VoidCallback onClear,
    VoidCallback? onRefresh,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1A448AFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryAccentFaint),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title: $count',
                  style: const TextStyle(
                    color: AppColors.primaryTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  lastFetch,
                  style: const TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: _stateController.isRefreshing ? null : onRefresh,
              color: AppColors.primaryAccent,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxHeight: 24, maxWidth: 24),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: onClear,
            color: Colors.red,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(maxHeight: 24, maxWidth: 24),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  Future<void> _refreshAllData() async {
    if (!mounted) return;
    
    _stateController.setRefreshing(true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Refreshing all aviation data...')),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      final futures = [
        _airportService.refreshData(),
        _navaidService.refreshData(),
        _weatherService.forceReload(),
      ];

      await Future.wait(futures);
      
      if (mounted) {
        await _loadAllCacheStats();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        _stateController.setRefreshing(false);
      }
    }
  }

  Future<void> _refreshWeatherData() async {
    if (!mounted) return;
    
    _stateController.setRefreshing(true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Refreshing weather data...')),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      await _weatherService.forceReload();
      
      if (mounted) {
        await _loadAllCacheStats();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weather data refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing weather data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _stateController.setRefreshing(false);
      }
    }
  }

  Future<void> _clearSpecificCache(String cacheName) async {
    final confirm = await ClearCacheDialog.show(
      context: context,
      cacheName: cacheName,
    );

    if (confirm == true) {
      try {
        switch (cacheName) {
          case 'Airports':
            await _cacheService.clearAirportsCache();
            break;
          case 'Navaids':
            await _cacheService.clearNavaidsCache();
            break;
          case 'Runways':
            await _cacheService.clearRunwaysCache();
            break;
          case 'Frequencies':
            await _cacheService.clearFrequenciesCache();
            break;
          case 'Airspaces':
            await _cacheService.clearAirspacesCache();
            break;
          case 'Reporting Points':
            await _cacheService.clearReportingPointsCache();
            break;
          case 'Weather':
            await _cacheService.clearWeatherCache();
            break;
          case 'Map Tiles':
            await _offlineMapService.clearCache();
            break;
        }
        await _loadAllCacheStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$cacheName cache cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing $cacheName cache: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllCaches() async {
    final confirm = await ClearCacheDialog.show(
      context: context,
      cacheName: '',
      isAllCaches: true,
    );

    if (confirm == true) {
      try {
        await Future.wait([
          _cacheService.clearAllCaches(),
          _offlineMapService.clearCache(),
        ]);
        await _loadAllCacheStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All caches cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing caches: $e')),
          );
        }
      }
    }
  }

  Future<void> _downloadCurrentArea() async {
    if (widget.currentMapBounds == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please open this screen from the map to download the current area'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    await _downloadArea(
      northEast: widget.currentMapBounds!.northEast,
      southWest: widget.currentMapBounds!.southWest,
    );
  }

  Future<void> _downloadArea({
    required LatLng northEast,
    required LatLng southWest,
  }) async {
    if (!mounted) return;
    
    _stateController.setDownloading(true);
    _stateController.resetDownloadState();

    try {
      await _offlineMapService.downloadAreaTiles(
        bounds: LatLngBounds(northEast, southWest),
        minZoom: _stateController.minZoom,
        maxZoom: _stateController.maxZoom,
        onProgress: (current, total, skipped, downloaded) {
          if (!mounted) return;
          _stateController.updateDownloadProgress(current, total, skipped, downloaded);
          
          if (current % 25 == 0 || current == total) {
            if (mounted) {
              _loadAllCacheStats();
            }
          }
        },
      );

      if (mounted) {
        final message = _stateController.skippedTiles > 0
            ? 'Downloaded ${_stateController.downloadedTiles} new tiles, skipped ${_stateController.skippedTiles} cached tiles'
            : 'Downloaded ${_stateController.downloadedTiles} tiles successfully!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isUserCancelled = e.toString().contains('cancelled by user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUserCancelled ? 'Download cancelled' : 'Download failed: $e',
            ),
            backgroundColor: isUserCancelled ? Colors.orange : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _stateController.resetDownloadState();
        await _loadAllCacheStats();
      }
    }
  }

  void _stopDownload() {
    if (!mounted) return;
    _offlineMapService.cancelDownload();
  }

  static Widget _buildCompactSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF448AFF),
          ),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    );
  }

  static Widget _buildCompactSwitch(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF448AFF),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  static Widget _buildCompactUnitDropdown(
    String label,
    String currentValue,
    List<String> values,
    Future<void> Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          SizedBox(
            height: 28,
            child: DropdownButton<String>(
              value: currentValue,
              dropdownColor: const Color(0xE6000000),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
              isDense: true,
              items: values.map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
