import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vibration_measurement_service.dart';

/// Widget to display vibration measurements during flight
class VibrationDisplay extends StatefulWidget {
  const VibrationDisplay({super.key});

  @override
  State<VibrationDisplay> createState() => _VibrationDisplayState();
}

class _VibrationDisplayState extends State<VibrationDisplay> {
  VibrationData? _latestData;
  bool _isCalibrated = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final service = context.read<VibrationMeasurementService>();
    service.vibrationStream.listen((data) {
      if (mounted) {
        setState(() {
          _latestData = data;
          if (!_isCalibrated && data.level == VibrationLevel.none) {
            _isCalibrated = true;
          }
        });
      }
    });
  }

  Color _getVibrationColor(VibrationLevel level) {
    switch (level) {
      case VibrationLevel.none:
        return Colors.green;
      case VibrationLevel.light:
        return Colors.lightGreen;
      case VibrationLevel.moderate:
        return Colors.orange;
      case VibrationLevel.strong:
        return Colors.deepOrange;
      case VibrationLevel.severe:
        return Colors.red;
    }
  }

  IconData _getVibrationIcon(VibrationLevel level) {
    switch (level) {
      case VibrationLevel.none:
      case VibrationLevel.light:
        return Icons.check_circle;
      case VibrationLevel.moderate:
        return Icons.warning;
      case VibrationLevel.strong:
      case VibrationLevel.severe:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_latestData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(Icons.vibration, size: 20),
              SizedBox(width: 8),
              Text('Initializing...', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final color = _getVibrationColor(_latestData!.level);
    final icon = _getVibrationIcon(_latestData!.level);

    return Card(
      color: _latestData!.isSignificant ? color.withValues(alpha: 0.2) : null,
      child: InkWell(
        onTap: _showDetails,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Vibration: ${_latestData!.level.displayName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '${_latestData!.rmsAcceleration.toStringAsFixed(2)} m/s²',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
              if (!_isCalibrated) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _calibrate,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text(
                    'Calibrate',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _calibrate() {
    final service = context.read<VibrationMeasurementService>();
    service.calibrate();
    setState(() {
      _isCalibrated = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vibration sensor calibrated'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showDetails() {
    if (_latestData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vibration),
            SizedBox(width: 8),
            Text('Vibration Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Level', _latestData!.level.displayName),
            _buildDetailRow(
              'RMS Acceleration',
              '${_latestData!.rmsAcceleration.toStringAsFixed(3)} m/s²',
            ),
            _buildDetailRow(
              'Peak Acceleration',
              '${_latestData!.peakAcceleration.toStringAsFixed(3)} m/s²',
            ),
            _buildDetailRow(
              'Frequency',
              '${_latestData!.frequency.toStringAsFixed(1)} Hz',
            ),
            const SizedBox(height: 16),
            const Text(
              'Axis Data:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildDetailRow(
              '  Lateral (X)',
              '${_latestData!.axisData.x.toStringAsFixed(3)} m/s²',
            ),
            _buildDetailRow(
              '  Longitudinal (Y)',
              '${_latestData!.axisData.y.toStringAsFixed(3)} m/s²',
            ),
            _buildDetailRow(
              '  Vertical (Z)',
              '${_latestData!.axisData.z.toStringAsFixed(3)} m/s²',
            ),
            const SizedBox(height: 16),
            Text(
              _isCalibrated
                  ? 'Sensor is calibrated'
                  : 'Sensor needs calibration',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: _isCalibrated ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isCalibrated)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _calibrate();
              },
              child: const Text('Calibrate'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
