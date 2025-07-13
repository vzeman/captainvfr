import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../utils/form_theme_helper.dart';

class DensityAltitudeCalculator extends StatefulWidget {
  const DensityAltitudeCalculator({super.key});

  @override
  State<DensityAltitudeCalculator> createState() =>
      _DensityAltitudeCalculatorState();
}

class _DensityAltitudeCalculatorState extends State<DensityAltitudeCalculator> {
  final _pressureAltitudeController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _altimeterController = TextEditingController();
  final _fieldElevationController = TextEditingController();

  double? _densityAltitude;
  double? _pressureAltitude;
  bool _useFieldElevation = true;

  @override
  void dispose() {
    _pressureAltitudeController.dispose();
    _temperatureController.dispose();
    _altimeterController.dispose();
    _fieldElevationController.dispose();
    super.dispose();
  }

  void _calculate() {
    final settingsService = context.read<SettingsService>();
    final isImperial = settingsService.units == 'imperial';

    double? temperature = double.tryParse(_temperatureController.text);
    double? altimeter = double.tryParse(_altimeterController.text);
    double? pressureAltitude;

    if (_useFieldElevation) {
      double? fieldElevation = double.tryParse(_fieldElevationController.text);
      if (fieldElevation == null || altimeter == null) return;

      // Convert field elevation to feet if needed
      if (!isImperial) {
        fieldElevation = fieldElevation * 3.28084; // meters to feet
      }

      // Convert altimeter setting to inHg if needed
      if (settingsService.pressureUnit == 'hPa') {
        altimeter = altimeter * 0.02953; // hPa to inHg
      }

      // Calculate pressure altitude
      pressureAltitude = fieldElevation + ((29.92 - altimeter) * 1000);
    } else {
      pressureAltitude = double.tryParse(_pressureAltitudeController.text);
      if (pressureAltitude == null) return;

      // Convert to feet if needed
      if (!isImperial) {
        pressureAltitude = pressureAltitude * 3.28084; // meters to feet
      }
    }

    if (temperature == null) return;

    // Convert temperature to Celsius if needed
    if (isImperial) {
      temperature = (temperature - 32) * 5 / 9; // Fahrenheit to Celsius
    }

    // ISA temperature at pressure altitude (in Celsius)
    final isaTemp = 15 - (pressureAltitude * 0.00198); // 1.98°C per 1000ft

    // Temperature deviation from ISA
    final tempDeviation = temperature - isaTemp;

    // Density altitude calculation
    // DA = PA + (120 × ΔT) where ΔT is temp deviation in °C
    final densityAltitude = pressureAltitude + (120 * tempDeviation);

    setState(() {
      _pressureAltitude = pressureAltitude;
      _densityAltitude = densityAltitude;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final isImperial = settingsService.units == 'imperial';
    final pressureUnit = settingsService.pressureUnit;

    return Scaffold(
      backgroundColor: FormThemeHelper.backgroundColor,
      appBar: AppBar(
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        title: const Text(
          'Density Altitude Calculator',
          style: TextStyle(color: FormThemeHelper.primaryTextColor),
        ),
        foregroundColor: FormThemeHelper.primaryTextColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormThemeHelper.buildSection(
              title: 'Input Method',
              children: [
                RadioListTile<bool>(
                  title: const Text('Field Elevation + Altimeter', style: FormThemeHelper.inputTextStyle),
                  value: true,
                  groupValue: _useFieldElevation,
                  activeColor: FormThemeHelper.primaryAccent,
                  onChanged: (value) {
                    setState(() {
                      _useFieldElevation = value!;
                      _densityAltitude = null;
                      _pressureAltitude = null;
                    });
                  },
                ),
                RadioListTile<bool>(
                  title: const Text('Pressure Altitude', style: FormThemeHelper.inputTextStyle),
                  value: false,
                  groupValue: _useFieldElevation,
                  activeColor: FormThemeHelper.primaryAccent,
                  onChanged: (value) {
                    setState(() {
                      _useFieldElevation = value!;
                      _densityAltitude = null;
                      _pressureAltitude = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            FormThemeHelper.buildSection(
              title: 'Inputs',
              children: [
                if (_useFieldElevation) ...[
                  FormThemeHelper.buildFormField(
                    controller: _fieldElevationController,
                    labelText: 'Field Elevation (${isImperial ? "ft" : "m"})',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  FormThemeHelper.buildFormField(
                    controller: _altimeterController,
                    labelText: 'Altimeter Setting ($pressureUnit)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ] else ...[
                  FormThemeHelper.buildFormField(
                    controller: _pressureAltitudeController,
                    labelText: 'Pressure Altitude (${isImperial ? "ft" : "m"})',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
                const SizedBox(height: 16),
                FormThemeHelper.buildFormField(
                  controller: _temperatureController,
                  labelText: 'Temperature (${isImperial ? "°F" : "°C"})',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _calculate,
              style: FormThemeHelper.getPrimaryButtonStyle().copyWith(
                minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
              ),
              child: const Text('Calculate', style: TextStyle(fontSize: 16)),
            ),
            if (_densityAltitude != null) ...[
              const SizedBox(height: 24),
              FormThemeHelper.buildSection(
                title: 'Results',
                children: [
                  if (_useFieldElevation && _pressureAltitude != null) ...[
                    Text(
                      'Pressure Altitude: ${isImperial ? _pressureAltitude!.toStringAsFixed(0) : (_pressureAltitude! / 3.28084).toStringAsFixed(0)} ${isImperial ? "ft" : "m"}',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Density Altitude: ${isImperial ? _densityAltitude!.toStringAsFixed(0) : (_densityAltitude! / 3.28084).toStringAsFixed(0)} ${isImperial ? "ft" : "m"}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: FormThemeHelper.primaryAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_densityAltitude! > 8000) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'High density altitude! Aircraft performance will be significantly reduced.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
