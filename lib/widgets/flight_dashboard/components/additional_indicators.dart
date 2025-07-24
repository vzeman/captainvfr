import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/flight_service.dart';
import '../../../services/barometer_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/aircraft_settings_service.dart';
import '../../../widgets/themed_dialog.dart';
import 'small_indicator_widget.dart';

/// Additional indicators showing pressure, QNH, and fuel information
class AdditionalIndicators extends StatelessWidget {
  final FlightService flightService;
  final BarometerService barometerService;

  const AdditionalIndicators({
    super.key,
    required this.flightService,
    required this.barometerService,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsService, AircraftSettingsService>(
      builder: (context, settings, aircraftService, child) {
        // Convert pressure based on user preference
        final pressureValue = flightService.currentPressure;
        final displayPressure = settings.pressureUnit == 'inHg'
            ? pressureValue * 0.02953 // Convert hPa to inHg
            : pressureValue;
        final pressureStr = settings.pressureUnit == 'inHg'
            ? displayPressure.toStringAsFixed(2)
            : displayPressure.toStringAsFixed(0);

        // Convert QNH based on user preference
        final qnhValue = barometerService.seaLevelPressure;
        final displayQNH = settings.pressureUnit == 'inHg'
            ? qnhValue * 0.02953 // Convert hPa to inHg
            : qnhValue;
        final qnhStr = settings.pressureUnit == 'inHg'
            ? displayQNH.toStringAsFixed(2)
            : displayQNH.toStringAsFixed(0);

        // Check if aircraft is selected
        final hasAircraft = aircraftService.selectedAircraft != null;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: SmallIndicatorWidget(
                label: 'PRESS',
                value: '$pressureStr ${settings.pressureUnit}',
                icon: Icons.compress,
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _showQNHDialog(context, barometerService, settings),
                child: SmallIndicatorWidget(
                  label: 'QNH',
                  value: '$qnhStr ${settings.pressureUnit}',
                  icon: Icons.settings_input_antenna,
                ),
              ),
            ),
            if (hasAircraft)
              Expanded(
                child: SmallIndicatorWidget(
                  label: 'FUEL',
                  value: settings.units == 'metric'
                      ? '${(flightService.fuelUsed * 3.78541).toStringAsFixed(1)} L'
                      : '${flightService.fuelUsed.toStringAsFixed(1)} gal',
                  icon: Icons.local_gas_station,
                ),
              ),
          ],
        );
      },
    );
  }

  void _showQNHDialog(
    BuildContext context,
    BarometerService barometerService,
    SettingsService settings,
  ) {
    final TextEditingController qnhController = TextEditingController();
    final currentQNH = barometerService.seaLevelPressure;
    final displayQNH = settings.pressureUnit == 'inHg'
        ? currentQNH * 0.02953 // Convert hPa to inHg
        : currentQNH;
    qnhController.text = settings.pressureUnit == 'inHg'
        ? displayQNH.toStringAsFixed(2)
        : displayQNH.toStringAsFixed(0);

    ThemedDialog.show(
      context: context,
      title: 'Set QNH',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter QNH value in ${settings.pressureUnit}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: qnhController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'QNH (${settings.pressureUnit})',
              labelStyle: const TextStyle(color: Colors.white54),
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final qnhText = qnhController.text.trim();
            if (qnhText.isNotEmpty) {
              final qnhValue = double.tryParse(qnhText);
              if (qnhValue != null) {
                // Convert to hPa if needed
                final qnhInHPa = settings.pressureUnit == 'inHg'
                    ? qnhValue / 0.02953 // Convert inHg to hPa
                    : qnhValue;
                barometerService.setSeaLevelPressure(qnhInHPa);
                Navigator.of(context).pop();
              }
            }
          },
          child: const Text('Set'),
        ),
      ],
    );
  }
}