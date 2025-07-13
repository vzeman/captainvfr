import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../models/aircraft.dart';
import '../../widgets/aircraft_selector_widget.dart';
import '../../utils/form_theme_helper.dart';

class ClimbPerformanceCalculator extends StatefulWidget {
  const ClimbPerformanceCalculator({super.key});

  @override
  State<ClimbPerformanceCalculator> createState() =>
      _ClimbPerformanceCalculatorState();
}

class _ClimbPerformanceCalculatorState
    extends State<ClimbPerformanceCalculator> {
  final _formKey = GlobalKey<FormState>();
  final _currentAltitudeController = TextEditingController();
  final _targetAltitudeController = TextEditingController();
  final _currentWeightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _headwindController = TextEditingController();

  Aircraft? _selectedAircraft;
  double? _climbTime;
  double? _fuelBurn;
  double? _distanceCovered;
  double? _averageClimbRate;

  @override
  void dispose() {
    _currentAltitudeController.dispose();
    _targetAltitudeController.dispose();
    _currentWeightController.dispose();
    _temperatureController.dispose();
    _headwindController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate() || _selectedAircraft == null) {
      return;
    }

    final currentAlt = double.parse(_currentAltitudeController.text);
    final targetAlt = double.parse(_targetAltitudeController.text);
    final weight = double.parse(_currentWeightController.text);
    final temp = double.parse(_temperatureController.text);
    final headwind = double.tryParse(_headwindController.text) ?? 0;

    final settings = Provider.of<SettingsService>(context, listen: false);

    // Convert inputs to standard units for calculations
    final currentAltFt = settings.convertAltitudeToMeters(currentAlt) * 3.28084; // Convert to feet for calculations
    final targetAltFt = settings.convertAltitudeToMeters(targetAlt) * 3.28084; // Convert to feet for calculations
    final weightLbs = settings.convertWeightToKg(weight) * 2.20462; // Convert to pounds for calculations

    // Calculate density altitude for performance adjustment (use feet for calculations)
    final pressureAlt = currentAltFt; // Simplified - assuming standard pressure
    final isaTemp = 15 - (pressureAlt * 0.00198); // ISA temperature in Celsius
    final tempDeviation = temp - isaTemp;
    final densityAlt = pressureAlt + (120 * tempDeviation);

    // Adjust climb rate based on density altitude and weight
    final baseClimbRate = _selectedAircraft!.maximumClimbRate.toDouble();
    
    // Reduce climb rate by ~20 fpm per 1000ft density altitude
    final altitudeFactor = 1 - (densityAlt / 50000);
    
    // Reduce climb rate based on weight (assuming max weight reduces climb by 30%)
    final weightRatio = weightLbs / _selectedAircraft!.maxTakeoffWeight;
    final weightFactor = 1.3 - (0.3 * weightRatio);
    
    final adjustedClimbRate = baseClimbRate * altitudeFactor * weightFactor;
    
    // Calculate average climb rate (decreases with altitude)
    final avgAltitude = (currentAltFt + targetAltFt) / 2;
    final avgAltitudeFactor = 1 - (avgAltitude / 50000);
    _averageClimbRate = adjustedClimbRate * avgAltitudeFactor;
    
    // Calculate time to climb
    final altitudeChange = targetAltFt - currentAltFt;
    _climbTime = altitudeChange / _averageClimbRate!; // in minutes
    
    // Calculate fuel burn (increase by 20% for climb power)
    final climbFuelRate = _selectedAircraft!.fuelConsumption * 1.2;
    final fuelBurnGal = (_climbTime! / 60) * climbFuelRate;
    _fuelBurn = settings.convertFuel(fuelBurnGal * 3.78541); // Convert gallons to user's fuel unit
    
    // Calculate distance covered
    // Use Vy speed for climb (or Vx if available)
    final climbSpeed = _selectedAircraft!.vy ?? _selectedAircraft!.cruiseSpeed * 0.7;
    final headwindKt = settings.convertSpeedToMPS(headwind) * 1.94384; // Convert wind to knots
    final groundSpeed = climbSpeed - headwindKt;
    final distanceNm = (groundSpeed * _climbTime!) / 60; // Distance in nautical miles
    _distanceCovered = settings.convertDistance(distanceNm * 1852); // Convert nm to user's distance unit

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsService>(context);

    return Scaffold(
      backgroundColor: FormThemeHelper.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Climb Performance',
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
                            aircraft.maxTakeoffWeight.toString();
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            FormThemeHelper.buildSection(
              title: 'Climb Parameters',
              children: [
                    Row(
                      children: [
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _currentAltitudeController,
                            labelText: 'Current Altitude (${settings.altitudeUnit})',
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
                            labelText: 'Target Altitude (${settings.altitudeUnit})',
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
                              if (current != null && target <= current) {
                                return 'Target must be higher than current';
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
                            labelText: 'Current Weight (${settings.weightUnit})',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter current weight';
                              }
                              final weight = double.tryParse(value);
                              if (weight == null || weight <= 0) {
                                return 'Please enter a valid weight';
                              }
                              if (_selectedAircraft != null &&
                                  weight > _selectedAircraft!.maxTakeoffWeight) {
                                return 'Weight exceeds max takeoff weight';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FormThemeHelper.buildFormField(
                            controller: _temperatureController,
                            labelText: 'Temperature (°${settings.temperatureUnit})',
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter temperature';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FormThemeHelper.buildFormField(
                      controller: _headwindController,
                      labelText: 'Headwind Component (${settings.windUnit})',
                      hintText: 'Use negative value for tailwind',
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedAircraft == null ? null : _calculate,
                        style: FormThemeHelper.getPrimaryButtonStyle().copyWith(
                          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
                        ),
                        child: const Text('Calculate Climb Performance'),
                      ),
                    ),
              ],
            ),
            if (_climbTime != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: FormThemeHelper.getSectionDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Climb Performance Results',
                        style: FormThemeHelper.sectionTitleStyle.copyWith(
                          color: FormThemeHelper.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildResultRow(
                        'Time to Climb',
                        '${_climbTime!.toStringAsFixed(1)} minutes',
                        theme,
                      ),
                      _buildResultRow(
                        'Average Climb Rate',
                        '${_averageClimbRate!.toStringAsFixed(0)} fpm',
                        theme,
                      ),
                      _buildResultRow(
                        'Fuel Required',
                        '${_fuelBurn!.toStringAsFixed(1)} ${settings.fuelUnit}',
                        theme,
                      ),
                      _buildResultRow(
                        'Distance Covered',
                        '${_distanceCovered!.toStringAsFixed(1)} ${settings.distanceUnit}',
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
                                'Performance based on density altitude and weight adjustments',
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