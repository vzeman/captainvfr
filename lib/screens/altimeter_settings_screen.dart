import 'package:flutter/material.dart';
import '../services/barometer_service.dart';
import '../services/altitude_service.dart';
import '../widgets/qnh_settings_widget.dart';
import '../widgets/altitude_calibration_widget.dart';

class AltimeterSettingsScreen extends StatefulWidget {
  const AltimeterSettingsScreen({super.key});

  @override
  State<AltimeterSettingsScreen> createState() =>
      _AltimeterSettingsScreenState();
}

class _AltimeterSettingsScreenState extends State<AltimeterSettingsScreen> {
  late BarometerService _barometerService;
  late AltitudeService _altitudeService;
  double? _currentPressure;
  double? _currentAltitude;
  bool _isBarometerAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _barometerService = BarometerService();
    _altitudeService = AltitudeService();

    await _barometerService.initialize();
    await _altitudeService.initialize();

    setState(() {
      _isBarometerAvailable = _barometerService.isBarometerAvailable;
    });

    if (_isBarometerAvailable) {
      await _barometerService.startListening();
      await _altitudeService.startTracking();

      // Listen to updates
      _barometerService.onBarometerUpdate.listen((reading) {
        if (mounted) {
          setState(() {
            _currentPressure = reading.pressure;
            _currentAltitude = reading.altitude;
          });
        }
      });
    }
  }

  void _onQNHChanged(double newQNH) {
    // QNH change is handled by the widgets
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('QNH updated to ${newQNH.toStringAsFixed(2)} hPa'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onCalibrationChanged(double newQNH) {
    // Calibration change is handled by the widgets
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Altimeter calibrated (QNH: ${newQNH.toStringAsFixed(2)} hPa)',
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _barometerService.stopListening();
    _altitudeService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Altimeter Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            height: 1.0,
          ),
        ),
      ),
      body: _isBarometerAvailable
          ? _buildSettingsContent()
          : _buildUnavailableContent(),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Status Card
          _buildStatusCard(),

          const SizedBox(height: 8),

          // QNH Settings
          QNHSettingsWidget(
            barometerService: _barometerService,
            altitudeService: _altitudeService,
            onQNHChanged: _onQNHChanged,
          ),

          const SizedBox(height: 8),

          // Altitude Calibration
          AltitudeCalibrationWidget(
            barometerService: _barometerService,
            altitudeService: _altitudeService,
            onCalibrationChanged: _onCalibrationChanged,
          ),

          const SizedBox(height: 8),

          // Help Card
          _buildHelpCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sensors,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Barometer Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    'Pressure',
                    _currentPressure != null
                        ? '${_currentPressure!.toStringAsFixed(2)} hPa'
                        : 'Reading...',
                    Icons.compress,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    'Altitude',
                    _currentAltitude != null
                        ? '${_currentAltitude!.toStringAsFixed(1)} m'
                        : 'Reading...',
                    Icons.height,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors_off,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Barometer Unavailable',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This device does not have a barometric pressure sensor. '
              'Altitude measurements will use GPS data only, which is less accurate.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'How to Use',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'QNH Setting:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '• Get current QNH from ATIS, METAR, or airport information\n'
              '• Use quick adjustment buttons for fine-tuning\n'
              '• Standard atmosphere is 1013.25 hPa (29.92" Hg)',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 12),

            Text(
              'Altitude Calibration:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '• Enter known ground elevation (from airport charts)\n'
              '• Best done when stationary on the ground\n'
              '• Automatically calculates correct QNH for your location',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
