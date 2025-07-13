import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../models/aircraft.dart';
import '../../widgets/aircraft_selector_widget.dart';
import '../../utils/form_theme_helper.dart';
import 'dart:math';

class DescentPerformanceCalculator extends StatefulWidget {
  const DescentPerformanceCalculator({super.key});

  @override
  State<DescentPerformanceCalculator> createState() =>
      _DescentPerformanceCalculatorState();
}

class _DescentPerformanceCalculatorState
    extends State<DescentPerformanceCalculator> {
  final _formKey = GlobalKey<FormState>();
  final _currentAltitudeController = TextEditingController();
  final _targetAltitudeController = TextEditingController();
  final _currentWeightController = TextEditingController();
  final _descentRateController = TextEditingController();
  final _airspeedController = TextEditingController();
  final _windController = TextEditingController();

  Aircraft? _selectedAircraft;
  double? _descentTime;
  double? _fuelUsed;
  double? _distanceCovered;
  double? _descentAngle;
  double? _groundSpeed;

  @override
  void dispose() {
    _currentAltitudeController.dispose();
    _targetAltitudeController.dispose();
    _currentWeightController.dispose();
    _descentRateController.dispose();
    _airspeedController.dispose();
    _windController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Set default descent rate to 500 fpm
    _descentRateController.text = '500';
  }

  void _calculate() {
    if (!_formKey.currentState!.validate() || _selectedAircraft == null) {
      return;
    }

    final currentAlt = double.parse(_currentAltitudeController.text);
    final targetAlt = double.parse(_targetAltitudeController.text);
    final descentRate = double.parse(_descentRateController.text);
    final airspeed = double.parse(_airspeedController.text);
    final wind = double.tryParse(_windController.text) ?? 0;

    final settings = Provider.of<SettingsService>(context, listen: false);
    final isImperial = settings.units == 'imperial';

    // Convert inputs to appropriate units for calculations
    final currentAltFt = isImperial ? currentAlt : currentAlt * 3.28084;
    final targetAltFt = isImperial ? targetAlt : targetAlt * 3.28084;
    final airspeedKt = isImperial ? airspeed : airspeed / 1.852; // Convert km/h to knots if needed
    final windKt = isImperial ? wind : wind / 1.852; // Convert km/h to knots if needed

    // Calculate altitude change
    final altitudeChange = currentAltFt - targetAltFt;
    
    // Calculate descent time
    _descentTime = altitudeChange / descentRate; // in minutes
    
    // Calculate ground speed
    final groundSpeedKt = airspeedKt + windKt; // wind is positive for tailwind
    _groundSpeed = isImperial ? groundSpeedKt : groundSpeedKt * 1.852; // Convert to km/h if metric
    
    // Calculate distance covered during descent
    final distanceNm = (groundSpeedKt * _descentTime!) / 60; // Distance in nautical miles
    _distanceCovered = isImperial ? distanceNm : distanceNm * 1.852; // Convert to km if metric
    
    // Calculate descent angle
    _descentAngle = atan(descentRate / (airspeedKt * 101.27)) * 180 / pi; // Convert to degrees
    // 101.27 is the conversion factor from fpm to ft/min to match airspeed in knots
    
    // Calculate fuel used during descent
    // Descent typically uses 30-40% less fuel than cruise
    final descentFuelRate = _selectedAircraft!.fuelConsumption * 0.65;
    final fuelUsedGal = (_descentTime! / 60) * descentFuelRate;
    _fuelUsed = isImperial ? fuelUsedGal : fuelUsedGal * 3.78541; // Convert to liters if metric

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsService>(context);
    final isImperial = settings.units == 'imperial';

    return Scaffold(
      backgroundColor: FormThemeHelper.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Descent Performance',
          style: TextStyle(color: FormThemeHelper.primaryTextColor),
        ),
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        foregroundColor: FormThemeHelper.primaryTextColor,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FormThemeHelper.buildSection(
              title: 'Aircraft Selection',
              children: [
                AircraftSelectorWidget(
                  selectedAircraft: _selectedAircraft,
                  onAircraftSelected: (aircraft) {
                    setState(() {
                      _selectedAircraft = aircraft;
                      if (aircraft != null) {
                        _currentWeightController.text = 
                            (aircraft.maxTakeoffWeight * 0.85).toStringAsFixed(0);
                        _airspeedController.text = 
                            aircraft.cruiseSpeed.toString();
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            FormThemeHelper.buildSection(
              title: 'Descent Parameters',
              children: [
                    Row(
                      children: [
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _currentAltitudeController,
                            labelText: 'Current Altitude (${isImperial ? "ft" : "m"})',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter current altitude';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _targetAltitudeController,
                            labelText: 'Target Altitude (${isImperial ? "ft" : "m"})',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter target altitude';
                              }
                              final target = double.tryParse(value);
                              if (target == null) {
                                return 'Please enter a valid number';
                              }
                              final current = double.tryParse(
                                  _currentAltitudeController.text);
                              if (current != null && target >= current) {
                                return 'Target must be lower than current';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _descentRateController,
                            labelText: 'Descent Rate (fpm)',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter descent rate';
                              }
                              final rate = double.tryParse(value);
                              if (rate == null || rate <= 0) {
                                return 'Please enter a valid rate';
                              }
                              if (_selectedAircraft != null &&
                                  rate > _selectedAircraft!.maximumDescentRate) {
                                return 'Exceeds max descent rate';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _airspeedController,
                            labelText: 'Descent Airspeed (${isImperial ? "kt" : "km/h"})',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter airspeed';
                              }
                              final speed = double.tryParse(value);
                              if (speed == null || speed <= 0) {
                                return 'Please enter a valid speed';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _currentWeightController,
                            labelText: 'Current Weight (${isImperial ? "lbs" : "kg"})',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter current weight';
                              }
                              final weight = double.tryParse(value);
                              if (weight == null || weight <= 0) {
                                return 'Please enter a valid weight';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _windController,
                            labelText: 'Wind Component (${isImperial ? "kt" : "km/h"})',
                            hintText: 'Positive = tailwind, Negative = headwind',
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedAircraft == null ? null : _calculate,
                        style: FormThemeHelper.getPrimaryButtonStyle().copyWith(
                          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
                        ),
                        child: const Text('Calculate Descent Performance'),
                      ),
                    ),
              ],
            ),
            if (_descentTime != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: FormThemeHelper.getSectionDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Descent Performance Results',
                        style: FormThemeHelper.sectionTitleStyle.copyWith(
                          color: FormThemeHelper.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildResultRow(
                        'Descent Time',
                        '${_descentTime!.toStringAsFixed(1)} minutes',
                        theme,
                      ),
                      _buildResultRow(
                        'Ground Speed',
                        '${_groundSpeed!.toStringAsFixed(1)} ${isImperial ? "kt" : "km/h"}',
                        theme,
                      ),
                      _buildResultRow(
                        'Distance Covered',
                        '${_distanceCovered!.toStringAsFixed(1)} ${isImperial ? "nm" : "km"}',
                        theme,
                      ),
                      _buildResultRow(
                        'Descent Angle',
                        '${_descentAngle!.toStringAsFixed(1)}°',
                        theme,
                      ),
                      _buildResultRow(
                        'Fuel Used',
                        '${_fuelUsed!.toStringAsFixed(1)} ${isImperial ? "gal" : "L"}',
                        theme,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FormThemeHelper.fillColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: FormThemeHelper.borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: FormThemeHelper.primaryAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Descent calculations assume constant rate and airspeed. Actual performance may vary with atmospheric conditions.',
                                style: TextStyle(
                                  color: FormThemeHelper.primaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildResultRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: FormThemeHelper.primaryTextColor,
              fontSize: theme.textTheme.bodyMedium?.fontSize,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: FormThemeHelper.primaryAccent,
              fontSize: theme.textTheme.bodyLarge?.fontSize,
            ),
          ),
        ],
      ),
    );
  }
}