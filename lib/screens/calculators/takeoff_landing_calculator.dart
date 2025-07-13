import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../models/aircraft.dart';
import '../../widgets/aircraft_selector_widget.dart';

class TakeoffLandingCalculator extends StatefulWidget {
  const TakeoffLandingCalculator({super.key});

  @override
  State<TakeoffLandingCalculator> createState() =>
      _TakeoffLandingCalculatorState();
}

class _TakeoffLandingCalculatorState extends State<TakeoffLandingCalculator> {
  Aircraft? _selectedAircraft;
  final _fieldElevationController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _altimeterController = TextEditingController();
  final _headwindController = TextEditingController();
  final _runwayConditionController = TextEditingController(
    text: '0',
  ); // % contamination
  final _weightController = TextEditingController();

  // Results
  double? _densityAltitude;
  double? _takeoffGroundRoll;
  double? _takeoffOver50ft;
  double? _landingGroundRoll;
  double? _landingOver50ft;

  @override
  void dispose() {
    _fieldElevationController.dispose();
    _temperatureController.dispose();
    _altimeterController.dispose();
    _headwindController.dispose();
    _runwayConditionController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_selectedAircraft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an aircraft')),
      );
      return;
    }

    // Check if aircraft has performance data
    if (_selectedAircraft!.takeoffGroundRoll50ft == null ||
        _selectedAircraft!.landingGroundRoll50ft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected aircraft lacks performance data'),
        ),
      );
      return;
    }

    final settingsService = context.read<SettingsService>();
    final isImperial = settingsService.units == 'imperial';

    double? fieldElevation = double.tryParse(_fieldElevationController.text);
    double? temperature = double.tryParse(_temperatureController.text);
    double? altimeter = double.tryParse(_altimeterController.text);
    double? headwind = double.tryParse(_headwindController.text) ?? 0;
    double? runwayContamination =
        double.tryParse(_runwayConditionController.text) ?? 0;
    double? weight = double.tryParse(_weightController.text);

    if (fieldElevation == null || temperature == null || altimeter == null) {
      return;
    }

    // Convert units
    if (!isImperial) {
      fieldElevation = fieldElevation * 3.28084; // meters to feet
      temperature = (temperature * 9 / 5) + 32; // C to F
      weight = weight != null ? weight * 2.20462 : null; // kg to lbs
    }

    if (settingsService.pressureUnit == 'hPa') {
      altimeter = altimeter * 0.02953; // hPa to inHg
    }

    // Calculate pressure altitude
    double pressureAltitude = fieldElevation + ((29.92 - altimeter) * 1000);

    // Calculate density altitude
    double tempC = (temperature - 32) * 5 / 9;
    double isaTemp = 15 - (pressureAltitude * 0.00198);
    double tempDeviation = tempC - isaTemp;
    double densityAltitude = pressureAltitude + (120 * tempDeviation);

    // Base distances from aircraft data
    double baseTakeoffGround = _selectedAircraft!.takeoffGroundRoll50ft!
        .toDouble();
    double baseTakeoffOver50 = _selectedAircraft!.takeoffOver50ft!.toDouble();
    double baseLandingGround = _selectedAircraft!.landingGroundRoll50ft!
        .toDouble();
    double baseLandingOver50 = _selectedAircraft!.landingOver50ft!.toDouble();

    // Altitude correction (7% per 1000ft density altitude)
    double altitudeFactor = 1 + (densityAltitude * 0.07 / 1000);

    // Temperature correction (already included in density altitude)

    // Weight correction (if provided and aircraft has MTOW)
    double weightFactor = 1.0;
    if (weight != null && _selectedAircraft!.maxTakeoffWeight > 0) {
      // Approximate: 10% increase in distance for 10% over standard weight
      double standardWeight =
          _selectedAircraft!.maxTakeoffWeight *
          0.9; // Assume 90% MTOW is standard
      weightFactor = 1 + ((weight - standardWeight) / standardWeight) * 1.0;
      if (weightFactor < 0.9) weightFactor = 0.9; // Minimum factor
    }

    // Wind correction
    // Headwind: -10% per 10 knots headwind
    // Tailwind: +20% per 10 knots tailwind
    double windFactor = 1.0;
    if (headwind > 0) {
      windFactor = 1 - (headwind * 0.1 / 10); // Headwind reduces distance
    } else {
      windFactor = 1 + ((-headwind) * 0.2 / 10); // Tailwind increases distance
    }

    // Runway surface correction
    double surfaceFactor =
        1 + (runwayContamination / 100 * 0.5); // Up to 50% increase

    // Calculate final distances
    _takeoffGroundRoll =
        baseTakeoffGround *
        altitudeFactor *
        weightFactor *
        windFactor *
        surfaceFactor;
    _takeoffOver50ft =
        baseTakeoffOver50 *
        altitudeFactor *
        weightFactor *
        windFactor *
        surfaceFactor;
    _landingGroundRoll =
        baseLandingGround *
        altitudeFactor *
        weightFactor *
        windFactor *
        surfaceFactor;
    _landingOver50ft =
        baseLandingOver50 *
        altitudeFactor *
        weightFactor *
        windFactor *
        surfaceFactor;
    _densityAltitude = densityAltitude;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final isImperial = settingsService.units == 'imperial';
    final pressureUnit = settingsService.pressureUnit;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Takeoff & Landing Calculator'),
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
            AircraftSelectorWidget(
              selectedAircraft: _selectedAircraft,
              onAircraftSelected: (aircraft) {
                setState(() {
                  _selectedAircraft = aircraft;
                  // Pre-fill weight if aircraft has empty weight
                  if (aircraft != null && aircraft.emptyWeight != null) {
                    double weight =
                        aircraft.emptyWeight! + 400; // Add typical pilot + fuel
                    if (!isImperial) {
                      weight = weight / 2.20462; // Convert to kg
                    }
                    _weightController.text = weight.toStringAsFixed(0);
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Environmental Conditions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _fieldElevationController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Field Elevation (${isImperial ? "ft" : "m"})',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _temperatureController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Temperature (${isImperial ? "°F" : "°C"})',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _altimeterController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Altimeter Setting ($pressureUnit)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _headwindController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Headwind Component (${isImperial ? "kts" : "km/h"})',
                        helperText: 'Use negative value for tailwind',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _runwayConditionController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Runway Contamination (%)',
                        helperText: '0 = Dry, 100 = Standing water/slush',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Aircraft Weight (${isImperial ? "lbs" : "kg"})',
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
            if (_takeoffGroundRoll != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Performance Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Density Altitude: ${isImperial ? _densityAltitude!.toStringAsFixed(0) : (_densityAltitude! / 3.28084).toStringAsFixed(0)} ${isImperial ? "ft" : "m"}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.flight_takeoff, size: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'TAKEOFF',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ground Roll',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '${isImperial ? _takeoffGroundRoll!.toStringAsFixed(0) : (_takeoffGroundRoll! / 3.28084).toStringAsFixed(0)} ${isImperial ? "ft" : "m"}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Over 50ft',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '${isImperial ? _takeoffOver50ft!.toStringAsFixed(0) : (_takeoffOver50ft! / 3.28084).toStringAsFixed(0)} ${isImperial ? "ft" : "m"}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(Icons.flight_land, size: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'LANDING',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ground Roll',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '${isImperial ? _landingGroundRoll!.toStringAsFixed(0) : (_landingGroundRoll! / 3.28084).toStringAsFixed(0)} ${isImperial ? "ft" : "m"}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Over 50ft',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '${isImperial ? _landingOver50ft!.toStringAsFixed(0) : (_landingOver50ft! / 3.28084).toStringAsFixed(0)} ${isImperial ? "ft" : "m"}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_densityAltitude! > 5000) ...[
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'High density altitude significantly affects performance',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ],
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
