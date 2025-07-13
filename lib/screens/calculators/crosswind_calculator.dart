import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../utils/form_theme_helper.dart';
import 'dart:math' as math;

class CrosswindCalculator extends StatefulWidget {
  const CrosswindCalculator({super.key});

  @override
  State<CrosswindCalculator> createState() => _CrosswindCalculatorState();
}

class _CrosswindCalculatorState extends State<CrosswindCalculator> {
  final _runwayHeadingController = TextEditingController();
  final _windDirectionController = TextEditingController();
  final _windSpeedController = TextEditingController();

  double? _headwindComponent;
  double? _crosswindComponent;
  String? _windType;

  @override
  void dispose() {
    _runwayHeadingController.dispose();
    _windDirectionController.dispose();
    _windSpeedController.dispose();
    super.dispose();
  }

  void _calculate() {
    final runwayHeading = double.tryParse(_runwayHeadingController.text);
    final windDirection = double.tryParse(_windDirectionController.text);
    final windSpeed = double.tryParse(_windSpeedController.text);

    if (runwayHeading == null || windDirection == null || windSpeed == null) {
      return;
    }

    // Calculate the angle between runway and wind direction
    double angle = windDirection - runwayHeading;

    // Normalize angle to -180 to 180 range
    while (angle > 180) {
      angle -= 360;
    }
    while (angle < -180) {
      angle += 360;
    }

    // Convert to radians
    double angleRad = angle * (math.pi / 180);

    // Calculate components
    double headwind = windSpeed * math.cos(angleRad);
    double crosswind = windSpeed * math.sin(angleRad);

    // Determine wind type
    String windType;
    if (headwind > 0) {
      windType = 'Headwind';
    } else {
      windType = 'Tailwind';
      headwind = -headwind; // Make positive for display
    }

    // Make crosswind absolute value for display
    crosswind = crosswind.abs();

    setState(() {
      _headwindComponent = headwind;
      _crosswindComponent = crosswind;
      _windType = windType;
    });
  }

  Widget _buildResultCard() {
    final settingsService = context.read<SettingsService>();
    final isImperial = settingsService.units == 'imperial';
    final speedUnit = isImperial ? 'kts' : 'km/h';

    return Container(
      decoration: FormThemeHelper.getSectionDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Wind Components',
              style: FormThemeHelper.sectionTitleStyle.copyWith(
                color: FormThemeHelper.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Icon(
                      _windType == 'Headwind'
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 40,
                      color: _windType == 'Headwind'
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _windType ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: FormThemeHelper.primaryTextColor,
                      ),
                    ),
                    Text(
                      '${_headwindComponent!.toStringAsFixed(1)} $speedUnit',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: FormThemeHelper.primaryAccent,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Icon(
                      Icons.compare_arrows,
                      size: 40,
                      color: _crosswindComponent! > 20
                          ? Colors.red
                          : Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crosswind',
                      style: TextStyle(
                        fontSize: 14,
                        color: FormThemeHelper.primaryTextColor,
                      ),
                    ),
                    Text(
                      '${_crosswindComponent!.toStringAsFixed(1)} $speedUnit',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: FormThemeHelper.primaryAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_crosswindComponent! > 15) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _crosswindComponent! > 25
                          ? 'Very strong crosswind! Check aircraft limitations.'
                          : 'Significant crosswind. Use proper technique.',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final isImperial = settingsService.units == 'imperial';
    final speedUnit = isImperial ? 'kts' : 'km/h';

    return Scaffold(
      backgroundColor: FormThemeHelper.backgroundColor,
      appBar: AppBar(
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        title: const Text(
          'Crosswind Calculator',
          style: TextStyle(color: FormThemeHelper.primaryTextColor),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: FormThemeHelper.primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormThemeHelper.buildSection(
              title: 'Wind Information',
              children: [
                FormThemeHelper.buildFormField(
                  controller: _runwayHeadingController,
                  labelText: 'Runway Heading (°)',
                  hintText: 'Magnetic heading of the runway',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                FormThemeHelper.buildFormField(
                  controller: _windDirectionController,
                  labelText: 'Wind Direction (°)',
                  hintText: 'Direction wind is coming FROM',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                FormThemeHelper.buildFormField(
                  controller: _windSpeedController,
                  labelText: 'Wind Speed ($speedUnit)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
            if (_headwindComponent != null && _crosswindComponent != null) ...[
              const SizedBox(height: 24),
              _buildResultCard(),
              const SizedBox(height: 16),
              FormThemeHelper.buildSection(
                title: 'Quick Reference',
                children: [
                  Text('• 15° off runway: ~25% crosswind', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                  Text('• 30° off runway: ~50% crosswind', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                  Text('• 45° off runway: ~70% crosswind', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                  Text('• 60° off runway: ~85% crosswind', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                  Text('• 90° off runway: 100% crosswind', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
