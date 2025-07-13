import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
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

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Wind Components',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    Text(_windType ?? '', style: const TextStyle(fontSize: 14)),
                    Text(
                      '${_headwindComponent!.toStringAsFixed(1)} $speedUnit',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                    const Text('Crosswind', style: TextStyle(fontSize: 14)),
                    Text(
                      '${_crosswindComponent!.toStringAsFixed(1)} $speedUnit',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Crosswind Calculator'),
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
                      'Wind Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _runwayHeadingController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Runway Heading (°)',
                        helperText: 'Magnetic heading of the runway',
                        border: OutlineInputBorder(),
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
            if (_headwindComponent != null && _crosswindComponent != null) ...[
              const SizedBox(height: 24),
              _buildResultCard(),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Reference',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('• 15° off runway: ~25% crosswind'),
                      const Text('• 30° off runway: ~50% crosswind'),
                      const Text('• 45° off runway: ~70% crosswind'),
                      const Text('• 60° off runway: ~85% crosswind'),
                      const Text('• 90° off runway: 100% crosswind'),
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
