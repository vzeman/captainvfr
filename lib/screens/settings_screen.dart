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
                    subtitle: 'Map rotates to match aircraft heading during tracking',
                    value: settings.rotateMapWithHeading,
                    onChanged: (value) => settings.setRotateMapWithHeading(value),
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
                    onChanged: (value) => settings.setHighPrecisionTracking(value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Display',
                children: [
                  ListTile(
                    title: const Text(
                      'Units',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Distance and altitude units',
                      style: TextStyle(color: Colors.white70),
                    ),
                    trailing: DropdownButton<String>(
                      value: settings.units,
                      dropdownColor: const Color(0xE6000000),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'metric', child: Text('Metric')),
                        DropdownMenuItem(value: 'imperial', child: Text('Imperial')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          settings.setUnits(value);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text(
                      'Pressure Unit',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Barometric pressure display unit',
                      style: TextStyle(color: Colors.white70),
                    ),
                    trailing: DropdownButton<String>(
                      value: settings.pressureUnit,
                      dropdownColor: const Color(0xE6000000),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'hPa', child: Text('hPa')),
                        DropdownMenuItem(value: 'inHg', child: Text('inHg')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          settings.setPressureUnit(value);
                        }
                      },
                    ),
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

  Widget _buildSection({required String title, required List<Widget> children}) {
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
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white70),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF448AFF),
    );
  }

  void _showResetDialog(BuildContext context, SettingsService settings) {
    ThemedDialog.showConfirmation(
      context: context,
      title: 'Reset Settings',
      message: 'Are you sure you want to reset all settings to their default values?',
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
      maxHeight: 450,
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
                title: 'Display',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Units',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        SizedBox(
                          height: 28,
                          child: DropdownButton<String>(
                            value: settings.units,
                            dropdownColor: const Color(0xE6000000),
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 'metric', child: Text('Metric')),
                              DropdownMenuItem(value: 'imperial', child: Text('Imperial')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                settings.setUnits(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pressure',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        SizedBox(
                          height: 28,
                          child: DropdownButton<String>(
                            value: settings.pressureUnit,
                            dropdownColor: const Color(0xE6000000),
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 'hPa', child: Text('hPa')),
                              DropdownMenuItem(value: 'inHg', child: Text('inHg')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                settings.setPressureUnit(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
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
}