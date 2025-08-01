import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../models/aircraft.dart';
import '../../widgets/aircraft_selector_widget.dart';
import '../../constants/app_colors.dart';
import 'dart:math';

class CruisePerformanceCalculator extends StatefulWidget {
  const CruisePerformanceCalculator({super.key});

  @override
  State<CruisePerformanceCalculator> createState() =>
      _CruisePerformanceCalculatorState();
}

class _CruisePerformanceCalculatorState
    extends State<CruisePerformanceCalculator> {
  final _formKey = GlobalKey<FormState>();
  final _cruiseAltitudeController = TextEditingController();
  final _currentWeightController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _windController = TextEditingController();
  final _distanceController = TextEditingController();

  Aircraft? _selectedAircraft;
  double? _trueAirspeed;
  double? _groundSpeed;
  double? _fuelFlow;
  double? _flightTime;
  double? _fuelRequired;
  double? _specificRange;

  @override
  void dispose() {
    _cruiseAltitudeController.dispose();
    _currentWeightController.dispose();
    _temperatureController.dispose();
    _windController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate() || _selectedAircraft == null) {
      return;
    }

    final cruiseAlt = double.parse(_cruiseAltitudeController.text);
    final weight = double.parse(_currentWeightController.text);
    final temp = double.parse(_temperatureController.text);
    final wind = double.tryParse(_windController.text) ?? 0; // negative = headwind
    final distance = double.parse(_distanceController.text);

    final settings = Provider.of<SettingsService>(context, listen: false);
    final isImperial = settings.units == 'imperial';

    // Convert inputs to appropriate units for calculations
    final cruiseAltFt = isImperial ? cruiseAlt : cruiseAlt * 3.28084;
    final weightLbs = isImperial ? weight : weight * 2.20462;
    final windKt = isImperial ? wind : wind / 1.852; // Convert km/h to knots if needed
    final distanceNm = isImperial ? distance : distance / 1.852; // Convert km to nautical miles if needed

    // Calculate density altitude
    final pressureAlt = cruiseAltFt; // Simplified - assuming standard pressure
    final isaTemp = 15 - (pressureAlt * 0.00198); // ISA temperature in Celsius
    final tempDeviation = temp - isaTemp;
    final densityAlt = pressureAlt + (120 * tempDeviation);

    // Calculate true airspeed
    // Base on cruise speed with adjustments for altitude and weight
    final baseCruiseSpeed = _selectedAircraft!.cruiseSpeed.toDouble();
    
    // TAS increases with altitude (approximately 2% per 1000ft)
    final altitudeFactor = 1 + (cruiseAltFt * 0.00002);
    
    // Reduce speed slightly for heavier weights
    final weightRatio = weightLbs / _selectedAircraft!.maxTakeoffWeight;
    final weightFactor = 1.05 - (0.05 * weightRatio);
    
    // High density altitude reduces performance
    final densityFactor = 1 - (max(0, densityAlt - cruiseAltFt) / 50000);
    
    final trueAirspeedKt = baseCruiseSpeed * altitudeFactor * weightFactor * densityFactor;
    _trueAirspeed = isImperial ? trueAirspeedKt : trueAirspeedKt * 1.852; // Convert to km/h if metric
    
    // Calculate ground speed
    final groundSpeedKt = trueAirspeedKt + windKt; // wind is positive for tailwind
    _groundSpeed = isImperial ? groundSpeedKt : groundSpeedKt * 1.852; // Convert to km/h if metric
    
    // Calculate fuel flow (increases with altitude and weight)
    final baseFuelFlow = _selectedAircraft!.fuelConsumption;
    final altitudeFuelFactor = 1 + (cruiseAltFt * 0.000015); // Slight increase with altitude
    final weightFuelFactor = 0.85 + (0.15 * weightRatio); // More fuel for heavier weight
    
    final fuelFlowGph = baseFuelFlow * altitudeFuelFactor * weightFuelFactor;
    _fuelFlow = isImperial ? fuelFlowGph : fuelFlowGph * 3.78541; // Convert to L/h if metric
    
    // Calculate flight time and fuel required
    _flightTime = distanceNm / groundSpeedKt; // in hours
    final fuelRequiredGal = _flightTime! * fuelFlowGph;
    _fuelRequired = isImperial ? fuelRequiredGal : fuelRequiredGal * 3.78541; // Convert to liters if metric
    
    // Calculate specific range
    _specificRange = isImperial 
        ? distanceNm / fuelRequiredGal  // nm/gal
        : (distanceNm * 1.852) / (fuelRequiredGal * 3.78541); // km/L

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<SettingsService>(context);
    final isImperial = settings.units == 'imperial';

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Cruise Performance',
          style: TextStyle(color: AppColors.primaryTextColor),
        ),
        backgroundColor: AppColors.dialogBackgroundColor,
        foregroundColor: AppColors.primaryTextColor,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection(
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
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Flight Parameters',
              children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            controller: _cruiseAltitudeController,
                            labelText: 'Cruise Altitude (${isImperial ? "ft" : "m"})',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter cruise altitude';
                              }
                              final alt = double.tryParse(value);
                              if (alt == null || alt < 0) {
                                return 'Please enter a valid altitude';
                              }
                              if (_selectedAircraft != null &&
                                  alt > _selectedAircraft!.maximumAltitude) {
                                return 'Exceeds aircraft max altitude';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFormField(
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
                              if (_selectedAircraft != null &&
                                  weight > _selectedAircraft!.maxTakeoffWeight) {
                                return 'Weight exceeds max takeoff weight';
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
                          child: _buildFormField(
                            controller: _temperatureController,
                            labelText: 'Temperature (°C)',
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFormField(
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
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _distanceController,
                      labelText: 'Distance to Fly (${isImperial ? "nm" : "km"})',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter distance';
                        }
                        final distance = double.tryParse(value);
                        if (distance == null || distance <= 0) {
                          return 'Please enter a valid distance';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedAircraft == null ? null : _calculate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAccent,
                          foregroundColor: Colors.white,
                        ).copyWith(
                          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
                        ),
                        child: const Text('Calculate Cruise Performance'),
                      ),
                    ),
              ],
            ),
            if (_trueAirspeed != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.sectionBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sectionBorderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cruise Performance Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ).copyWith(
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildResultRow(
                        'True Airspeed',
                        '${_trueAirspeed!.toStringAsFixed(1)} ${isImperial ? "kt" : "km/h"}',
                        theme,
                      ),
                      _buildResultRow(
                        'Ground Speed',
                        '${_groundSpeed!.toStringAsFixed(1)} ${isImperial ? "kt" : "km/h"}',
                        theme,
                      ),
                      _buildResultRow(
                        'Fuel Flow',
                        '${_fuelFlow!.toStringAsFixed(1)} ${isImperial ? "gph" : "L/h"}',
                        theme,
                      ),
                      _buildResultRow(
                        'Flight Time',
                        '${(_flightTime! * 60).toStringAsFixed(0)} minutes',
                        theme,
                      ),
                      _buildResultRow(
                        'Fuel Required',
                        '${_fuelRequired!.toStringAsFixed(1)} ${isImperial ? "gal" : "L"}',
                        theme,
                      ),
                      _buildResultRow(
                        'Specific Range',
                        '${_specificRange!.toStringAsFixed(1)} ${isImperial ? "nm/gal" : "km/L"}',
                        theme,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.fillColorFaint,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryAccent),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.primaryAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Performance calculated for cruise conditions with density altitude and weight adjustments',
                                style: TextStyle(
                                  color: AppColors.primaryTextColor,
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
              color: AppColors.primaryTextColor,
              fontSize: theme.textTheme.bodyMedium?.fontSize,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryAccent,
              fontSize: theme.textTheme.bodyLarge?.fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppColors.primaryTextColor),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(color: AppColors.secondaryTextColor),
        hintStyle: TextStyle(color: AppColors.secondaryTextColor.withValues(alpha: 0.5)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryAccent),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        fillColor: AppColors.fillColorFaint,
        filled: true,
      ),
    );
  }
}