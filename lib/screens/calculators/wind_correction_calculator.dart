import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Wind Correction Angle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Flight Parameters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _courseController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Desired Course (°)',
                        helperText: 'True course to destination',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _trueAirspeedController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'True Airspeed ($speedUnit)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wind Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _windDirectionController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Wind Direction (°)',
                        helperText: 'Direction wind is coming FROM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _windSpeedController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Wind Speed ($speedUnit)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _calculate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Calculate', style: TextStyle(fontSize: 16)),
            ),
            if (_windCorrectionAngle != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Navigation Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.explore, size: 40),
                              const SizedBox(height: 8),
                              const Text('Heading to Fly'),
                              Text(
                                '${_headingToFly!.toStringAsFixed(0)}°',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(Icons.rotate_left, size: 40),
                              const SizedBox(height: 8),
                              const Text('Wind Correction'),
                              Text(
                                '${_windCorrectionAngle! > 0 ? "+" : ""}${_windCorrectionAngle!.toStringAsFixed(1)}°',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.speed, size: 32),
                              const SizedBox(height: 4),
                              const Text('Ground Speed'),
                              Text(
                                '${_groundSpeed!.toStringAsFixed(0)} $speedUnit',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(Icons.air, size: 32),
                              const SizedBox(height: 4),
                              const Text('Wind Type'),
                              Text(
                                _windType!,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Summary',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'To maintain course ${_courseController.text}°, fly heading ${_headingToFly!.toStringAsFixed(0)}°',
                              textAlign: TextAlign.center,
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
