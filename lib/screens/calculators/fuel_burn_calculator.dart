import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../utils/form_theme_helper.dart';

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
      backgroundColor: FormThemeHelper.backgroundColor,
      appBar: AppBar(
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        title: const Text(
          'Fuel Burn Calculator',
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
                  controller: _fuelFlowController,
                  labelText: 'Fuel Flow Rate ($flowUnit)',
                  hintText: 'Average cruise fuel consumption',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _flightTimeHoursController,
                            labelText: 'Flight Time (Hours)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _flightTimeMinutesController,
                            labelText: 'Minutes',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FormThemeHelper.buildFormField(
                      controller: _reserveTimeController,
                      labelText: 'Reserve Time (Minutes)',
                      hintText: 'FAA minimum: 30 min VFR, 45 min IFR',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FormThemeHelper.buildFormField(
                      controller: _totalFuelController,
                      labelText: 'Available Fuel ($fuelUnit) - Optional',
                      hintText: 'Total usable fuel on board',
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
            if (_fuelRequired != null) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: _isSafe == false
                      ? Colors.red.withValues(alpha: 0.1)
                      : FormThemeHelper.sectionBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSafe == false
                        ? Colors.red
                        : FormThemeHelper.sectionBorderColor,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Fuel Requirements',
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
                                ? Colors.red
                                : FormThemeHelper.primaryTextColor,
                          ),
                        ),
                        if (_isSafe == false) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.warning,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'INSUFFICIENT FUEL!',
                                style: TextStyle(
                                  color: Colors.red,
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
