import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../utils/form_theme_helper.dart';
import 'dart:math' as math;

class WindCorrectionCalculator extends StatefulWidget {
  const WindCorrectionCalculator({super.key});

  @override
  State<WindCorrectionCalculator> createState() =>
      _WindCorrectionCalculatorState();
}

class _WindCorrectionCalculatorState extends State<WindCorrectionCalculator> {
  final _courseController = TextEditingController();
  final _windDirectionController = TextEditingController();
  final _windSpeedController = TextEditingController();
  final _trueAirspeedController = TextEditingController();

  // Results
  double? _windCorrectionAngle;
  double? _groundSpeed;
  double? _headingToFly;
  String? _windType;

  @override
  void dispose() {
    _courseController.dispose();
    _windDirectionController.dispose();
    _windSpeedController.dispose();
    _trueAirspeedController.dispose();
    super.dispose();
  }

  void _calculate() {
    final course = double.tryParse(_courseController.text);
    final windDirection = double.tryParse(_windDirectionController.text);
    final windSpeed = double.tryParse(_windSpeedController.text);
    final trueAirspeed = double.tryParse(_trueAirspeedController.text);

    if (course == null ||
        windDirection == null ||
        windSpeed == null ||
        trueAirspeed == null) {
      return;
    }

    // Convert to radians
    final windDirRad = windDirection * math.pi / 180;

    // Calculate wind angle relative to course
    double windAngle = windDirection - course;
    while (windAngle > 180) {
      windAngle -= 360;
    }
    while (windAngle < -180) {
      windAngle += 360;
    }
    final windAngleRad = windAngle * math.pi / 180;

    // Calculate crosswind component
    final crosswind = windSpeed * math.sin(windAngleRad);

    // Calculate wind correction angle (WCA)
    double wca = 0;
    if (trueAirspeed > 0) {
      wca = math.asin(crosswind / trueAirspeed) * 180 / math.pi;
    }

    // Calculate heading to fly
    double heading = course + wca;
    while (heading >= 360) {
      heading -= 360;
    }
    while (heading < 0) {
      heading += 360;
    }

    // Calculate groundspeed using vector math
    // Wind components in x,y coordinates
    final windX = windSpeed * math.sin(windDirRad);
    final windY = windSpeed * math.cos(windDirRad);

    // Aircraft velocity components (with WCA applied)
    final headingRad = heading * math.pi / 180;
    final aircraftX = trueAirspeed * math.sin(headingRad);
    final aircraftY = trueAirspeed * math.cos(headingRad);

    // Ground velocity components
    final groundX = aircraftX + windX;
    final groundY = aircraftY + windY;

    // Ground speed
    final groundSpeed = math.sqrt(groundX * groundX + groundY * groundY);

    // Determine wind type
    final headwind = windSpeed * math.cos(windAngleRad);
    String windType;
    if (headwind > 5) {
      windType = 'Headwind';
    } else if (headwind < -5) {
      windType = 'Tailwind';
    } else if (crosswind.abs() > 5) {
      windType = crosswind > 0 ? 'Right Crosswind' : 'Left Crosswind';
    } else {
      windType = 'Light/Variable';
    }

    setState(() {
      _windCorrectionAngle = wca;
      _groundSpeed = groundSpeed;
      _headingToFly = heading;
      _windType = windType;
    });
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
          'Wind Correction Angle',
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
              title: 'Flight Parameters',
              children: [
                FormThemeHelper.buildFormField(
                  controller: _courseController,
                  labelText: 'Desired Course (°)',
                  hintText: 'True course to destination',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                FormThemeHelper.buildFormField(
                  controller: _trueAirspeedController,
                  labelText: 'True Airspeed ($speedUnit)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FormThemeHelper.buildSection(
              title: 'Wind Information',
              children: [
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
            if (_windCorrectionAngle != null) ...[
              const SizedBox(height: 24),
              Container(
                decoration: FormThemeHelper.getSectionDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Navigation Results',
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
                              Icon(Icons.explore, size: 40, color: FormThemeHelper.primaryAccent),
                              const SizedBox(height: 8),
                              Text('Heading to Fly', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                              Text(
                                '${_headingToFly!.toStringAsFixed(0)}°',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: FormThemeHelper.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.rotate_left, size: 40, color: FormThemeHelper.primaryAccent),
                              const SizedBox(height: 8),
                              Text('Wind Correction', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                              Text(
                                '${_windCorrectionAngle! > 0 ? "+" : ""}${_windCorrectionAngle!.toStringAsFixed(1)}°',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: FormThemeHelper.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Divider(height: 32, color: FormThemeHelper.borderColor),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.speed, size: 32, color: FormThemeHelper.primaryAccent),
                              const SizedBox(height: 4),
                              Text('Ground Speed', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                              Text(
                                '${_groundSpeed!.toStringAsFixed(0)} $speedUnit',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: FormThemeHelper.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.air, size: 32, color: FormThemeHelper.primaryAccent),
                              const SizedBox(height: 4),
                              Text('Wind Type', style: TextStyle(color: FormThemeHelper.primaryTextColor)),
                              Text(
                                _windType!,
                                style: TextStyle(fontSize: 16, color: FormThemeHelper.primaryTextColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FormThemeHelper.fillColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: FormThemeHelper.borderColor),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Summary',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: FormThemeHelper.primaryAccent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'To maintain course ${_courseController.text}°, fly heading ${_headingToFly!.toStringAsFixed(0)}°',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: FormThemeHelper.primaryTextColor),
                            ),
                            if (_windCorrectionAngle!.abs() > 20) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Large wind correction angle - verify wind data',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
