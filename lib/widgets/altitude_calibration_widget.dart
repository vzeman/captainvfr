import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/barometer_service.dart';
import '../services/altitude_service.dart';

class AltitudeCalibrationWidget extends StatefulWidget {
  final BarometerService barometerService;
  final AltitudeService altitudeService;
  final Function(double)? onCalibrationChanged;

  const AltitudeCalibrationWidget({
    super.key,
    required this.barometerService,
    required this.altitudeService,
    this.onCalibrationChanged,
  });

  @override
  State<AltitudeCalibrationWidget> createState() => _AltitudeCalibrationWidgetState();
}

class _AltitudeCalibrationWidgetState extends State<AltitudeCalibrationWidget> {
  late TextEditingController _groundAltController;
  double? _currentPressure;
  double? _currentBarometricAltitude;
  double _knownGroundAltitude = 0.0;
  bool _isCalibrating = false;

  @override
  void initState() {
    super.initState();
    _groundAltController = TextEditingController();
    _startListeningToBarometer();
  }

  @override
  void dispose() {
    _groundAltController.dispose();
    super.dispose();
  }

  void _startListeningToBarometer() {
    widget.barometerService.onBarometerUpdate.listen((reading) {
      if (mounted) {
        setState(() {
          _currentPressure = reading.pressure;
          _currentBarometricAltitude = reading.altitude;
        });
      }
    });
  }

  void _calibrateToGroundLevel() async {
    final groundAltText = _groundAltController.text.trim();
    if (groundAltText.isEmpty) {
      _showError('Please enter the known ground altitude');
      return;
    }

    final groundAlt = double.tryParse(groundAltText);
    if (groundAlt == null) {
      _showError('Please enter a valid altitude');
      return;
    }

    if (_currentPressure == null) {
      _showError('No pressure data available. Please wait for sensor readings.');
      return;
    }

    setState(() {
      _isCalibrating = true;
      _knownGroundAltitude = groundAlt;
    });

    try {
      // Calculate the QNH that would give us the known altitude at current pressure
      final qnh = _calculateQNHForKnownAltitude(_currentPressure!, groundAlt);

      // Update both services with the calibrated QNH
      widget.barometerService.setSeaLevelPressure(qnh);
      widget.altitudeService.setSeaLevelPressure(qnh);

      widget.onCalibrationChanged?.call(qnh);

      _showSuccess('Altimeter calibrated to ${groundAlt.toStringAsFixed(1)}m\nQNH set to ${qnh.toStringAsFixed(2)} hPa');

    } catch (e) {
      _showError('Calibration failed: $e');
    } finally {
      setState(() {
        _isCalibrating = false;
      });
    }
  }

  double _calculateQNHForKnownAltitude(double currentPressure, double knownAltitude) {
    // Using the inverse barometric formula to calculate sea level pressure
    // P0 = P * ((T0 - L*h)/T0)^(-g*M/(R*L))
    const double temperatureLapseRate = 0.0065; // K/m
    const double temperatureSeaLevel = 288.15; // K (15°C)
    const double gasConstant = 8.3144598; // J/(mol·K)
    const double molarMass = 0.0289644; // kg/mol
    const double gravity = 9.80665; // m/s²

    final exponent = -gravity * molarMass / (gasConstant * temperatureLapseRate);
    final tempRatio = (temperatureSeaLevel - temperatureLapseRate * knownAltitude) / temperatureSeaLevel;
    final qnh = currentPressure * math.pow(tempRatio, exponent);

    return qnh;
  }

  void _resetToStandard() {
    const standardQNH = 1013.25;
    widget.barometerService.setSeaLevelPressure(standardQNH);
    widget.altitudeService.setSeaLevelPressure(standardQNH);
    widget.onCalibrationChanged?.call(standardQNH);
    _showSuccess('Reset to standard atmosphere (1013.25 hPa)');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.my_location,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Altitude Calibration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current Readings
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Pressure:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        _currentPressure != null
                            ? '${_currentPressure!.toStringAsFixed(2)} hPa'
                            : 'Reading...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Barometric Altitude:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        _currentBarometricAltitude != null
                            ? '${_currentBarometricAltitude!.toStringAsFixed(1)} m'
                            : 'Reading...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Ground Level Calibration
            Text(
              'Calibrate to Known Ground Altitude',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _groundAltController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d+\.?\d{0,1}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Known Ground Altitude',
                      hintText: '0.0',
                      suffixText: 'm',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isCalibrating ? null : _calibrateToGroundLevel,
                  icon: _isCalibrating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.tune, size: 18),
                  label: Text(_isCalibrating ? 'Calibrating...' : 'Calibrate'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reset Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetToStandard,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset to Standard Atmosphere'),
              ),
            ),

            const SizedBox(height: 12),

            // Info Text
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Calibration Tips:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Use airport elevation for most accurate results\n'
                    '• Calibrate when stationary on the ground\n'
                    '• Check local weather for current QNH setting',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
