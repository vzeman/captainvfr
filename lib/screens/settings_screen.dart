import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/themed_dialog.dart';
import '../services/settings_service.dart';

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
        borderRadius: BorderRadius.circular(12),
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
class SettingsDialog {
  const SettingsDialog._();

  static Future<void> show(BuildContext context) {
    return ThemedDialog.show(
      context: context,
      title: 'Settings',
      barrierDismissible: true,
      maxWidth: 380,
      maxHeight: 600,
      content: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return Column(
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
          );
        },
      ),
      actions: [],
    );
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
