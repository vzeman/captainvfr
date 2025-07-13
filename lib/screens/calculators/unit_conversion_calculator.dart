import 'package:flutter/material.dart';
import '../../utils/form_theme_helper.dart';

class UnitConversionCalculator extends StatefulWidget {
  const UnitConversionCalculator({super.key});

  @override
  State<UnitConversionCalculator> createState() =>
      _UnitConversionCalculatorState();
}

class _UnitConversionCalculatorState extends State<UnitConversionCalculator> {
  final _inputController = TextEditingController();

  String _selectedCategory = 'Distance';
  String _fromUnit = 'Nautical Miles';
  String _toUnit = 'Kilometers';
  double? _result;

  final Map<String, Map<String, Map<String, double>>> _conversions = {
    'Distance': {
      'Nautical Miles': {
        'Nautical Miles': 1,
        'Statute Miles': 1.15078,
        'Kilometers': 1.852,
        'Meters': 1852,
        'Feet': 6076.12,
      },
      'Statute Miles': {
        'Nautical Miles': 0.868976,
        'Statute Miles': 1,
        'Kilometers': 1.60934,
        'Meters': 1609.34,
        'Feet': 5280,
      },
      'Kilometers': {
        'Nautical Miles': 0.539957,
        'Statute Miles': 0.621371,
        'Kilometers': 1,
        'Meters': 1000,
        'Feet': 3280.84,
      },
      'Meters': {
        'Nautical Miles': 0.000539957,
        'Statute Miles': 0.000621371,
        'Kilometers': 0.001,
        'Meters': 1,
        'Feet': 3.28084,
      },
      'Feet': {
        'Nautical Miles': 0.000164579,
        'Statute Miles': 0.000189394,
        'Kilometers': 0.0003048,
        'Meters': 0.3048,
        'Feet': 1,
      },
    },
    'Speed': {
      'Knots': {
        'Knots': 1,
        'MPH': 1.15078,
        'KPH': 1.852,
        'M/S': 0.514444,
        'FPM': 101.269,
      },
      'MPH': {
        'Knots': 0.868976,
        'MPH': 1,
        'KPH': 1.60934,
        'M/S': 0.44704,
        'FPM': 88,
      },
      'KPH': {
        'Knots': 0.539957,
        'MPH': 0.621371,
        'KPH': 1,
        'M/S': 0.277778,
        'FPM': 54.6807,
      },
      'M/S': {
        'Knots': 1.94384,
        'MPH': 2.23694,
        'KPH': 3.6,
        'M/S': 1,
        'FPM': 196.85,
      },
      'FPM': {
        'Knots': 0.00987473,
        'MPH': 0.0113636,
        'KPH': 0.018288,
        'M/S': 0.00508,
        'FPM': 1,
      },
    },
    'Altitude': {
      'Feet': {'Feet': 1, 'Meters': 0.3048, 'Flight Level': 0.01},
      'Meters': {'Feet': 3.28084, 'Meters': 1, 'Flight Level': 0.0328084},
      'Flight Level': {'Feet': 100, 'Meters': 30.48, 'Flight Level': 1},
    },
    'Weight': {
      'Pounds': {
        'Pounds': 1,
        'Kilograms': 0.453592,
        'Tons': 0.0005,
        'Metric Tons': 0.000453592,
      },
      'Kilograms': {
        'Pounds': 2.20462,
        'Kilograms': 1,
        'Tons': 0.00110231,
        'Metric Tons': 0.001,
      },
      'Tons': {
        'Pounds': 2000,
        'Kilograms': 907.185,
        'Tons': 1,
        'Metric Tons': 0.907185,
      },
      'Metric Tons': {
        'Pounds': 2204.62,
        'Kilograms': 1000,
        'Tons': 1.10231,
        'Metric Tons': 1,
      },
    },
    'Volume': {
      'US Gallons': {
        'US Gallons': 1,
        'Imperial Gallons': 0.832674,
        'Liters': 3.78541,
        'Quarts': 4,
      },
      'Imperial Gallons': {
        'US Gallons': 1.20095,
        'Imperial Gallons': 1,
        'Liters': 4.54609,
        'Quarts': 4.80380,
      },
      'Liters': {
        'US Gallons': 0.264172,
        'Imperial Gallons': 0.219969,
        'Liters': 1,
        'Quarts': 1.05669,
      },
      'Quarts': {
        'US Gallons': 0.25,
        'Imperial Gallons': 0.208169,
        'Liters': 0.946353,
        'Quarts': 1,
      },
    },
    'Temperature': {
      'Celsius': {'Celsius': 1.0},
      'Fahrenheit': {'Fahrenheit': 1.0},
      'Kelvin': {'Kelvin': 1.0},
    },
    'Pressure': {
      'inHg': {'inHg': 1, 'hPa': 33.8639, 'mb': 33.8639, 'PSI': 0.491154},
      'hPa': {'inHg': 0.0295301, 'hPa': 1, 'mb': 1, 'PSI': 0.0145038},
      'mb': {'inHg': 0.0295301, 'hPa': 1, 'mb': 1, 'PSI': 0.0145038},
      'PSI': {'inHg': 2.03602, 'hPa': 68.9476, 'mb': 68.9476, 'PSI': 1},
    },
  };

  @override
  void initState() {
    super.initState();
    _updateUnits();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _updateUnits() {
    final units = _conversions[_selectedCategory]!.keys.toList();
    setState(() {
      _fromUnit = units.first;
      _toUnit = units.length > 1 ? units[1] : units.first;
      _result = null;
    });
  }

  void _convert() {
    final input = double.tryParse(_inputController.text);
    if (input == null) return;

    setState(() {
      if (_selectedCategory == 'Temperature') {
        _result = _convertTemperature(input, _fromUnit, _toUnit);
      } else {
        final fromMap = _conversions[_selectedCategory]![_fromUnit];
        if (fromMap != null && fromMap.containsKey(_toUnit)) {
          final conversionFactor = fromMap[_toUnit]!;
          _result = input * conversionFactor;
        }
      }
    });
  }

  double _convertTemperature(double value, String from, String to) {
    // Convert to Celsius first
    double celsius;
    switch (from) {
      case 'Celsius':
        celsius = value;
        break;
      case 'Fahrenheit':
        celsius = (value - 32) * 5 / 9;
        break;
      case 'Kelvin':
        celsius = value - 273.15;
        break;
      default:
        celsius = value;
    }

    // Convert from Celsius to target
    switch (to) {
      case 'Celsius':
        return celsius;
      case 'Fahrenheit':
        return celsius * 9 / 5 + 32;
      case 'Kelvin':
        return celsius + 273.15;
      default:
        return celsius;
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = _conversions[_selectedCategory]!.keys.toList();

    return Scaffold(
      backgroundColor: FormThemeHelper.backgroundColor,
      appBar: AppBar(
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        title: const Text(
          'Unit Conversion',
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
              title: 'Category',
              children: [
                FormThemeHelper.buildDropdownField<String>(
                  value: _selectedCategory,
                  labelText: 'Select Category',
                  items: _conversions.keys.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                      _updateUnits();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            FormThemeHelper.buildSection(
              title: 'Convert',
              children: [
                FormThemeHelper.buildFormField(
                  controller: _inputController,
                  labelText: 'Value',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FormThemeHelper.buildDropdownField<String>(
                            value: _fromUnit,
                            labelText: 'From',
                            items: units.map((unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  unit,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _fromUnit = value!;
                                _result = null;
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, color: FormThemeHelper.primaryAccent),
                        ),
                        Expanded(
                          child: FormThemeHelper.buildDropdownField<String>(
                            value: _toUnit,
                            labelText: 'To',
                            items: units.map((unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  unit,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _toUnit = value!;
                                _result = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _convert,
              style: FormThemeHelper.getPrimaryButtonStyle().copyWith(
                minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
              ),
              child: const Text('Convert', style: TextStyle(fontSize: 16)),
            ),
            if (_result != null) ...[
              const SizedBox(height: 24),
              Container(
                decoration: FormThemeHelper.getSectionDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Result',
                        style: FormThemeHelper.sectionTitleStyle.copyWith(
                          color: FormThemeHelper.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_inputController.text} $_fromUnit',
                        style: const TextStyle(
                          fontSize: 16,
                          color: FormThemeHelper.primaryTextColor,
                        ),
                      ),
                      Icon(Icons.arrow_downward, size: 32, color: FormThemeHelper.primaryAccent),
                      Text(
                        '${_result!.toStringAsFixed(4)} $_toUnit',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: FormThemeHelper.primaryAccent,
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
}
