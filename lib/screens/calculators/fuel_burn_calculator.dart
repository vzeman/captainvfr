import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';

class FuelBurnCalculator extends StatefulWidget {
  const FuelBurnCalculator({super.key});

  @override
  State<FuelBurnCalculator> createState() => _FuelBurnCalculatorState();
}

class _FuelBurnCalculatorState extends State<FuelBurnCalculator> {
  final _fuelFlowController = TextEditingController();
  final _flightTimeHoursController = TextEditingController();
  final _flightTimeMinutesController = TextEditingController();
  final _totalFuelController = TextEditingController();
  final _reserveTimeController = TextEditingController(text: '30');

  // Results
  double? _fuelRequired;
  double? _reserveFuel;
  double? _totalFuelRequired;
  double? _endurance;
  double? _remainingFuel;
  bool? _isSafe;

  @override
  void dispose() {
    _fuelFlowController.dispose();
    _flightTimeHoursController.dispose();
    _flightTimeMinutesController.dispose();
    _totalFuelController.dispose();
    _reserveTimeController.dispose();
    super.dispose();
  }

  void _calculate() {
    final fuelFlow = double.tryParse(_fuelFlowController.text);
    final hours = double.tryParse(_flightTimeHoursController.text) ?? 0;
    final minutes = double.tryParse(_flightTimeMinutesController.text) ?? 0;
    final totalFuel = double.tryParse(_totalFuelController.text);
    final reserveTime = double.tryParse(_reserveTimeController.text) ?? 30;

    if (fuelFlow == null || fuelFlow <= 0) return;

    // Convert time to hours
    final flightTime = hours + (minutes / 60);

    // Calculate fuel required for flight
    final fuelRequired = flightTime * fuelFlow;

    // Calculate reserve fuel (default 30 minutes)
    final reserveFuel = (reserveTime / 60) * fuelFlow;

    // Total fuel required
    final totalRequired = fuelRequired + reserveFuel;

    // Calculate endurance if total fuel is provided
    double? endurance;
    double? remainingFuel;
    bool isSafe = true;

    if (totalFuel != null && totalFuel > 0) {
      endurance = totalFuel / fuelFlow;
      remainingFuel = totalFuel - totalRequired;
      isSafe = remainingFuel >= 0;
    }

    setState(() {
      _fuelRequired = fuelRequired;
      _reserveFuel = reserveFuel;
      _totalFuelRequired = totalRequired;
      _endurance = endurance;
      _remainingFuel = remainingFuel;
      _isSafe = isSafe;
    });
  }

  String _formatTime(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final isImperial = settingsService.units == 'imperial';
    final fuelUnit = isImperial ? 'gal' : 'L';
    final flowUnit = isImperial ? 'gal/hr' : 'L/hr';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Fuel Burn Calculator'),
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
                      controller: _fuelFlowController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Fuel Flow Rate ($flowUnit)',
                        helperText: 'Average cruise fuel consumption',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _flightTimeHoursController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Flight Time (Hours)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _flightTimeMinutesController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Minutes',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reserveTimeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Reserve Time (Minutes)',
                        helperText: 'FAA minimum: 30 min VFR, 45 min IFR',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _totalFuelController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Available Fuel ($fuelUnit) - Optional',
                        helperText: 'Total usable fuel on board',
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
            if (_fuelRequired != null) ...[
              const SizedBox(height: 24),
              Card(
                color: _isSafe == false
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Fuel Requirements',
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
                              const Icon(Icons.flight, size: 32),
                              const SizedBox(height: 4),
                              const Text('Flight Fuel'),
                              Text(
                                '${_fuelRequired!.toStringAsFixed(1)} $fuelUnit',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(Icons.security, size: 32),
                              const SizedBox(height: 4),
                              const Text('Reserve Fuel'),
                              Text(
                                '${_reserveFuel!.toStringAsFixed(1)} $fuelUnit',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        'Total Required: ${_totalFuelRequired!.toStringAsFixed(1)} $fuelUnit',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_endurance != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Endurance: ${_formatTime(_endurance!)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Remaining: ${_remainingFuel!.toStringAsFixed(1)} $fuelUnit',
                          style: TextStyle(
                            fontSize: 16,
                            color: _remainingFuel! < 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        if (_isSafe == false) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'INSUFFICIENT FUEL!',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
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
