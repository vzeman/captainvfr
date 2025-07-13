import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';

class WeightBalanceCalculator extends StatefulWidget {
  const WeightBalanceCalculator({super.key});

  @override
  State<WeightBalanceCalculator> createState() =>
      _WeightBalanceCalculatorState();
}

class _WeightBalanceCalculatorState extends State<WeightBalanceCalculator> {
  // Controllers for weight inputs
  final _emptyWeightController = TextEditingController();
  final _emptyWeightArmController = TextEditingController();
  final _pilotWeightController = TextEditingController();
  final _pilotArmController = TextEditingController();
  final _copilotWeightController = TextEditingController();
  final _copilotArmController = TextEditingController();
  final _rearPax1Controller = TextEditingController();
  final _rearPax1ArmController = TextEditingController();
  final _rearPax2Controller = TextEditingController();
  final _rearPax2ArmController = TextEditingController();
  final _baggageController = TextEditingController();
  final _baggageArmController = TextEditingController();
  final _fuelController = TextEditingController();
  final _fuelArmController = TextEditingController();

  // Limits
  final _maxGrossWeightController = TextEditingController();
  final _forwardCGLimitController = TextEditingController();
  final _aftCGLimitController = TextEditingController();

  // Results
  double? _totalWeight;
  double? _totalMoment;
  double? _centerOfGravity;
  bool? _withinLimits;

  @override
  void dispose() {
    _emptyWeightController.dispose();
    _emptyWeightArmController.dispose();
    _pilotWeightController.dispose();
    _pilotArmController.dispose();
    _copilotWeightController.dispose();
    _copilotArmController.dispose();
    _rearPax1Controller.dispose();
    _rearPax1ArmController.dispose();
    _rearPax2Controller.dispose();
    _rearPax2ArmController.dispose();
    _baggageController.dispose();
    _baggageArmController.dispose();
    _fuelController.dispose();
    _fuelArmController.dispose();
    _maxGrossWeightController.dispose();
    _forwardCGLimitController.dispose();
    _aftCGLimitController.dispose();
    super.dispose();
  }

  void _calculate() {
    final settingsService = context.read<SettingsService>();
    final isImperial = settingsService.units == 'imperial';

    // Parse all inputs
    double emptyWeight = double.tryParse(_emptyWeightController.text) ?? 0;
    double emptyWeightArm =
        double.tryParse(_emptyWeightArmController.text) ?? 0;
    double pilotWeight = double.tryParse(_pilotWeightController.text) ?? 0;
    double pilotArm = double.tryParse(_pilotArmController.text) ?? 0;
    double copilotWeight = double.tryParse(_copilotWeightController.text) ?? 0;
    double copilotArm = double.tryParse(_copilotArmController.text) ?? 0;
    double rearPax1 = double.tryParse(_rearPax1Controller.text) ?? 0;
    double rearPax1Arm = double.tryParse(_rearPax1ArmController.text) ?? 0;
    double rearPax2 = double.tryParse(_rearPax2Controller.text) ?? 0;
    double rearPax2Arm = double.tryParse(_rearPax2ArmController.text) ?? 0;
    double baggage = double.tryParse(_baggageController.text) ?? 0;
    double baggageArm = double.tryParse(_baggageArmController.text) ?? 0;
    double fuel = double.tryParse(_fuelController.text) ?? 0;
    double fuelArm = double.tryParse(_fuelArmController.text) ?? 0;

    // Convert weights from kg to lbs if needed
    if (!isImperial) {
      emptyWeight *= 2.20462;
      pilotWeight *= 2.20462;
      copilotWeight *= 2.20462;
      rearPax1 *= 2.20462;
      rearPax2 *= 2.20462;
      baggage *= 2.20462;
      fuel *= 2.20462; // Assuming fuel is entered in kg
    }

    // Convert arms from cm to inches if needed
    if (!isImperial) {
      emptyWeightArm /= 2.54;
      pilotArm /= 2.54;
      copilotArm /= 2.54;
      rearPax1Arm /= 2.54;
      rearPax2Arm /= 2.54;
      baggageArm /= 2.54;
      fuelArm /= 2.54;
    }

    // Calculate moments (weight × arm)
    double emptyMoment = emptyWeight * emptyWeightArm;
    double pilotMoment = pilotWeight * pilotArm;
    double copilotMoment = copilotWeight * copilotArm;
    double rearPax1Moment = rearPax1 * rearPax1Arm;
    double rearPax2Moment = rearPax2 * rearPax2Arm;
    double baggageMoment = baggage * baggageArm;
    double fuelMoment = fuel * fuelArm;

    // Calculate totals
    double totalWeight =
        emptyWeight +
        pilotWeight +
        copilotWeight +
        rearPax1 +
        rearPax2 +
        baggage +
        fuel;
    double totalMoment =
        emptyMoment +
        pilotMoment +
        copilotMoment +
        rearPax1Moment +
        rearPax2Moment +
        baggageMoment +
        fuelMoment;

    // Calculate CG
    double cg = totalWeight > 0 ? totalMoment / totalWeight : 0;

    // Check limits
    double? maxGross = double.tryParse(_maxGrossWeightController.text);
    double? forwardLimit = double.tryParse(_forwardCGLimitController.text);
    double? aftLimit = double.tryParse(_aftCGLimitController.text);

    if (!isImperial && maxGross != null) {
      maxGross *= 2.20462; // Convert kg to lbs
    }
    if (!isImperial && forwardLimit != null) {
      forwardLimit /= 2.54; // Convert cm to inches
    }
    if (!isImperial && aftLimit != null) {
      aftLimit /= 2.54; // Convert cm to inches
    }

    bool withinLimits = true;
    if (maxGross != null && totalWeight > maxGross) withinLimits = false;
    if (forwardLimit != null && cg < forwardLimit) withinLimits = false;
    if (aftLimit != null && cg > aftLimit) withinLimits = false;

    setState(() {
      _totalWeight = totalWeight;
      _totalMoment = totalMoment;
      _centerOfGravity = cg;
      _withinLimits = withinLimits;
    });
  }

  Widget _buildWeightInput(
    String label,
    TextEditingController weightController,
    TextEditingController armController,
    bool isImperial,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '$label (${isImperial ? "lbs" : "kg"})',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: armController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Arm (${isImperial ? "in" : "cm"})',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final isImperial = settingsService.units == 'imperial';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Weight & Balance Calculator'),
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
                      'Aircraft Limits',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _maxGrossWeightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Max Gross Weight (${isImperial ? "lbs" : "kg"})',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _forwardCGLimitController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Forward CG Limit (${isImperial ? "in" : "cm"})',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _aftCGLimitController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Aft CG Limit (${isImperial ? "in" : "cm"})',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
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
                      'Weight & Arm Inputs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildWeightInput(
                      'Empty Weight',
                      _emptyWeightController,
                      _emptyWeightArmController,
                      isImperial,
                    ),
                    const SizedBox(height: 12),
                    _buildWeightInput(
                      'Pilot',
                      _pilotWeightController,
                      _pilotArmController,
                      isImperial,
                    ),
                    const SizedBox(height: 12),
                    _buildWeightInput(
                      'Co-pilot',
                      _copilotWeightController,
                      _copilotArmController,
                      isImperial,
                    ),
                    const SizedBox(height: 12),
                    _buildWeightInput(
                      'Rear Pax 1',
                      _rearPax1Controller,
                      _rearPax1ArmController,
                      isImperial,
                    ),
                    const SizedBox(height: 12),
                    _buildWeightInput(
                      'Rear Pax 2',
                      _rearPax2Controller,
                      _rearPax2ArmController,
                      isImperial,
                    ),
                    const SizedBox(height: 12),
                    _buildWeightInput(
                      'Baggage',
                      _baggageController,
                      _baggageArmController,
                      isImperial,
                    ),
                    const SizedBox(height: 12),
                    _buildWeightInput(
                      'Fuel',
                      _fuelController,
                      _fuelArmController,
                      isImperial,
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
            if (_totalWeight != null) ...[
              const SizedBox(height: 24),
              Card(
                color: _withinLimits == true
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _withinLimits == true
                              ? null
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Total Weight: ${isImperial ? _totalWeight!.toStringAsFixed(1) : (_totalWeight! / 2.20462).toStringAsFixed(1)} ${isImperial ? "lbs" : "kg"}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Moment: ${_totalMoment!.toStringAsFixed(1)} ${isImperial ? "lb-in" : "kg-cm"}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Center of Gravity: ${isImperial ? _centerOfGravity!.toStringAsFixed(2) : (_centerOfGravity! * 2.54).toStringAsFixed(2)} ${isImperial ? "in" : "cm"}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_withinLimits == false) ...[
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
                              'OUTSIDE LIMITS!',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Within Limits',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
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
