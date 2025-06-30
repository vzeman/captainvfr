import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/barometer_service.dart';
import '../services/altitude_service.dart';

class QNHSettingsWidget extends StatefulWidget {
  final BarometerService barometerService;
  final AltitudeService altitudeService;
  final Function(double)? onQNHChanged;

  const QNHSettingsWidget({
    super.key,
    required this.barometerService,
    required this.altitudeService,
    this.onQNHChanged,
  });

  @override
  State<QNHSettingsWidget> createState() => _QNHSettingsWidgetState();
}

class _QNHSettingsWidgetState extends State<QNHSettingsWidget> {
  late TextEditingController _qnhController;
  double _currentQNH = 1013.25;

  @override
  void initState() {
    super.initState();
    _currentQNH = widget.barometerService.seaLevelPressure;
    _qnhController = TextEditingController(text: _currentQNH.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _qnhController.dispose();
    super.dispose();
  }

  void _updateQNH(double newQNH) {
    if (newQNH >= 950.0 && newQNH <= 1050.0) {
      setState(() {
        _currentQNH = newQNH;
        _qnhController.text = newQNH.toStringAsFixed(2);
      });
      
      // Update both services
      widget.barometerService.setSeaLevelPressure(newQNH);
      widget.altitudeService.setSeaLevelPressure(newQNH);
      
      // Notify parent
      widget.onQNHChanged?.call(newQNH);
    }
  }

  void _incrementQNH(double delta) {
    _updateQNH(_currentQNH + delta);
  }

  void _onQNHTextChanged() {
    final text = _qnhController.text;
    final value = double.tryParse(text);
    if (value != null) {
      _updateQNH(value);
    }
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
                  Icons.tune,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Altimeter Setting (QNH)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current QNH Display
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current QNH',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        '${_currentQNH.toStringAsFixed(2)} hPa',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${(_currentQNH * 0.02953).toStringAsFixed(2)}" Hg',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick Adjustment Buttons
            Text(
              'Quick Adjustments',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAdjustButton('-1.0', -1.0),
                _buildQuickAdjustButton('-0.1', -0.1),
                _buildQuickAdjustButton('+0.1', 0.1),
                _buildQuickAdjustButton('+1.0', 1.0),
              ],
            ),

            const SizedBox(height: 16),

            // Manual Input
            Text(
              'Manual Entry',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qnhController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'QNH (hPa)',
                      hintText: '1013.25',
                      suffixText: 'hPa',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                    ),
                    onChanged: (_) => _onQNHTextChanged(),
                    onEditingComplete: _onQNHTextChanged,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _updateQNH(1013.25),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('STD'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Info Text
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Set QNH to match local altimeter setting for accurate altitude readings',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
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

  Widget _buildQuickAdjustButton(String label, double delta) {
    return ElevatedButton(
      onPressed: () => _incrementQNH(delta),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        minimumSize: const Size(60, 36),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
