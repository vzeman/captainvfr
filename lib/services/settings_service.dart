import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyRotateMapWithHeading = 'rotate_map_with_heading';
  static const String _keyShowAirspaces = 'show_airspaces';
  static const String _keyShowNavaids = 'show_navaids';
  static const String _keyAutoSaveFlights = 'auto_save_flights';
  static const String _keyHighPrecisionTracking = 'high_precision_tracking';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyUnits = 'units';
  static const String _keyPressureUnit = 'pressure_unit';
  static const String _keyAltitudeUnit = 'altitude_unit';
  static const String _keyDistanceUnit = 'distance_unit';
  static const String _keySpeedUnit = 'speed_unit';
  static const String _keyTemperatureUnit = 'temperature_unit';
  static const String _keyWeightUnit = 'weight_unit';
  static const String _keyFuelUnit = 'fuel_unit';
  static const String _keyWindUnit = 'wind_unit';
  static const String _keyDevelopmentMode = 'development_mode';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Settings with defaults
  bool _rotateMapWithHeading = false;
  bool _showAirspaces = true;
  bool _showNavaids = true;
  bool _autoSaveFlights = true;
  bool _highPrecisionTracking = false;
  bool _darkMode = true;
  String _units = 'us_general_aviation'; // Default to US General Aviation preset
  String _pressureUnit = 'inHg'; // 'hPa' or 'inHg'
  String _altitudeUnit = 'ft'; // 'ft' or 'm'
  String _distanceUnit = 'nm'; // 'nm', 'km', 'mi'
  String _speedUnit = 'kt'; // 'kt', 'mph', 'km/h'
  String _temperatureUnit = 'C'; // 'C' or 'F'
  String _weightUnit = 'lbs'; // 'lbs' or 'kg'
  String _fuelUnit = 'gal'; // 'gal' or 'L'
  String _windUnit = 'kt'; // 'kt', 'mph', 'km/h'
  bool _developmentMode = false;

  // Getters
  bool get rotateMapWithHeading => _rotateMapWithHeading;
  bool get showAirspaces => _showAirspaces;
  bool get showNavaids => _showNavaids;
  bool get autoSaveFlights => _autoSaveFlights;
  bool get highPrecisionTracking => _highPrecisionTracking;
  bool get darkMode => _darkMode;
  String get units => _units;
  String get pressureUnit => _pressureUnit;
  String get altitudeUnit => _altitudeUnit;
  String get distanceUnit => _distanceUnit;
  String get speedUnit => _speedUnit;
  String get temperatureUnit => _temperatureUnit;
  String get weightUnit => _weightUnit;
  String get fuelUnit => _fuelUnit;
  String get windUnit => _windUnit;
  bool get developmentMode => _developmentMode;
  bool get isInitialized => _isInitialized;

  SettingsService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
    _isInitialized = true;
    notifyListeners();
  }

  void _loadSettings() {
    _rotateMapWithHeading = _prefs.getBool(_keyRotateMapWithHeading) ?? false;
    _showAirspaces = _prefs.getBool(_keyShowAirspaces) ?? true;
    _showNavaids = _prefs.getBool(_keyShowNavaids) ?? true;
    _autoSaveFlights = _prefs.getBool(_keyAutoSaveFlights) ?? true;
    _highPrecisionTracking = _prefs.getBool(_keyHighPrecisionTracking) ?? false;
    _darkMode = _prefs.getBool(_keyDarkMode) ?? true;
    _units = _prefs.getString(_keyUnits) ?? 'us_general_aviation';
    _pressureUnit = _prefs.getString(_keyPressureUnit) ?? 'inHg';
    _altitudeUnit = _prefs.getString(_keyAltitudeUnit) ?? 'ft';
    _distanceUnit = _prefs.getString(_keyDistanceUnit) ?? 'nm';
    _speedUnit = _prefs.getString(_keySpeedUnit) ?? 'kt';
    _temperatureUnit = _prefs.getString(_keyTemperatureUnit) ?? 'C';
    _weightUnit = _prefs.getString(_keyWeightUnit) ?? 'lbs';
    _fuelUnit = _prefs.getString(_keyFuelUnit) ?? 'gal';
    _windUnit = _prefs.getString(_keyWindUnit) ?? 'kt';
    _developmentMode = _prefs.getBool(_keyDevelopmentMode) ?? false;
  }

  // Setters
  Future<void> setRotateMapWithHeading(bool value) async {
    _rotateMapWithHeading = value;
    await _prefs.setBool(_keyRotateMapWithHeading, value);
    notifyListeners();
  }

  Future<void> setShowAirspaces(bool value) async {
    _showAirspaces = value;
    await _prefs.setBool(_keyShowAirspaces, value);
    notifyListeners();
  }

  Future<void> setShowNavaids(bool value) async {
    _showNavaids = value;
    await _prefs.setBool(_keyShowNavaids, value);
    notifyListeners();
  }

  Future<void> setAutoSaveFlights(bool value) async {
    _autoSaveFlights = value;
    await _prefs.setBool(_keyAutoSaveFlights, value);
    notifyListeners();
  }

  Future<void> setHighPrecisionTracking(bool value) async {
    _highPrecisionTracking = value;
    await _prefs.setBool(_keyHighPrecisionTracking, value);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _prefs.setBool(_keyDarkMode, value);
    notifyListeners();
  }

  Future<void> setUnits(String value) async {
    if (value == 'metric' || value == 'imperial' || 
        value == 'european_aviation' || value == 'us_general_aviation' ||
        value == 'metric_preference' || value == 'mixed_international') {
      _units = value;
      await _prefs.setString(_keyUnits, value);
      notifyListeners();
    }
  }

  Future<void> setPressureUnit(String value) async {
    if (value != _pressureUnit) {
      _pressureUnit = value;
      await _prefs.setString(_keyPressureUnit, value);
      notifyListeners();
    }
  }

  Future<void> setAltitudeUnit(String value) async {
    if (value != _altitudeUnit) {
      _altitudeUnit = value;
      await _prefs.setString(_keyAltitudeUnit, value);
      notifyListeners();
    }
  }

  Future<void> setDistanceUnit(String value) async {
    if (value != _distanceUnit) {
      _distanceUnit = value;
      await _prefs.setString(_keyDistanceUnit, value);
      notifyListeners();
    }
  }

  Future<void> setSpeedUnit(String value) async {
    if (value != _speedUnit) {
      _speedUnit = value;
      await _prefs.setString(_keySpeedUnit, value);
      notifyListeners();
    }
  }

  Future<void> setTemperatureUnit(String value) async {
    if (value != _temperatureUnit) {
      _temperatureUnit = value;
      await _prefs.setString(_keyTemperatureUnit, value);
      notifyListeners();
    }
  }

  Future<void> setWeightUnit(String value) async {
    if (value != _weightUnit) {
      _weightUnit = value;
      await _prefs.setString(_keyWeightUnit, value);
      notifyListeners();
    }
  }

  Future<void> setFuelUnit(String value) async {
    if (value != _fuelUnit) {
      _fuelUnit = value;
      await _prefs.setString(_keyFuelUnit, value);
      notifyListeners();
    }
  }

  Future<void> setWindUnit(String value) async {
    if (value != _windUnit) {
      _windUnit = value;
      await _prefs.setString(_keyWindUnit, value);
      notifyListeners();
    }
  }

  Future<void> setDevelopmentMode(bool value) async {
    if (value != _developmentMode) {
      _developmentMode = value;
      await _prefs.setBool(_keyDevelopmentMode, value);
      notifyListeners();
    }
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    await setRotateMapWithHeading(false);
    await setShowAirspaces(true);
    await setShowNavaids(true);
    await setAutoSaveFlights(true);
    await setHighPrecisionTracking(false);
    await setDarkMode(true);
    await setUnits('us_general_aviation');
    await setPressureUnit('inHg');
    await setAltitudeUnit('ft');
    await setDistanceUnit('nm');
    await setSpeedUnit('kt');
    await setTemperatureUnit('C');
    await setWeightUnit('lbs');
    await setFuelUnit('gal');
    await setWindUnit('kt');
  }

  // Unit conversion helpers - granular system
  
  // Altitude conversions (input in meters, output in selected unit)
  double convertAltitude(double meters) {
    switch (_altitudeUnit) {
      case 'ft':
        return meters * 3.28084; // meters to feet
      case 'm':
        return meters;
      default:
        return meters * 3.28084; // default to feet
    }
  }

  // Distance conversions (input in meters, output in selected unit)
  double convertDistance(double meters) {
    switch (_distanceUnit) {
      case 'nm':
        return meters * 0.000539957; // meters to nautical miles
      case 'km':
        return meters / 1000; // meters to kilometers
      case 'mi':
        return meters * 0.000621371; // meters to miles
      default:
        return meters * 0.000539957; // default to nautical miles
    }
  }

  // Speed conversions (input in m/s, output in selected unit)
  double convertSpeed(double metersPerSecond) {
    switch (_speedUnit) {
      case 'kt':
        return metersPerSecond * 1.94384; // m/s to knots
      case 'mph':
        return metersPerSecond * 2.23694; // m/s to mph
      case 'km/h':
        return metersPerSecond * 3.6; // m/s to km/h
      default:
        return metersPerSecond * 1.94384; // default to knots
    }
  }

  // Wind speed conversions (input in m/s, output in selected unit)
  double convertWindSpeed(double metersPerSecond) {
    switch (_windUnit) {
      case 'kt':
        return metersPerSecond * 1.94384; // m/s to knots
      case 'mph':
        return metersPerSecond * 2.23694; // m/s to mph
      case 'km/h':
        return metersPerSecond * 3.6; // m/s to km/h
      default:
        return metersPerSecond * 1.94384; // default to knots
    }
  }

  // Temperature conversions (input in Celsius, output in selected unit)
  double convertTemperature(double celsius) {
    switch (_temperatureUnit) {
      case 'C':
        return celsius;
      case 'F':
        return (celsius * 9 / 5) + 32; // Celsius to Fahrenheit
      default:
        return celsius; // default to Celsius
    }
  }

  // Weight conversions (input in kg, output in selected unit)
  double convertWeight(double kilograms) {
    switch (_weightUnit) {
      case 'kg':
        return kilograms;
      case 'lbs':
        return kilograms * 2.20462; // kg to pounds
      default:
        return kilograms * 2.20462; // default to pounds
    }
  }

  // Fuel conversions (input in liters, output in selected unit)
  double convertFuel(double liters) {
    switch (_fuelUnit) {
      case 'L':
        return liters;
      case 'gal':
        return liters * 0.264172; // liters to US gallons
      default:
        return liters * 0.264172; // default to gallons
    }
  }

  // Conversion helpers for calculations (convert FROM selected unit TO standard unit)
  
  // Convert altitude from selected unit to meters
  double convertAltitudeToMeters(double value) {
    switch (_altitudeUnit) {
      case 'ft':
        return value / 3.28084; // feet to meters
      case 'm':
        return value;
      default:
        return value / 3.28084; // default from feet
    }
  }

  // Convert distance from selected unit to meters
  double convertDistanceToMeters(double value) {
    switch (_distanceUnit) {
      case 'nm':
        return value / 0.000539957; // nautical miles to meters
      case 'km':
        return value * 1000; // kilometers to meters
      case 'mi':
        return value / 0.000621371; // miles to meters
      default:
        return value / 0.000539957; // default from nautical miles
    }
  }

  // Convert speed from selected unit to m/s
  double convertSpeedToMPS(double value) {
    switch (_speedUnit) {
      case 'kt':
        return value / 1.94384; // knots to m/s
      case 'mph':
        return value / 2.23694; // mph to m/s
      case 'km/h':
        return value / 3.6; // km/h to m/s
      default:
        return value / 1.94384; // default from knots
    }
  }

  // Convert temperature from selected unit to Celsius
  double convertTemperatureToCelsius(double value) {
    switch (_temperatureUnit) {
      case 'C':
        return value;
      case 'F':
        return (value - 32) * 5 / 9; // Fahrenheit to Celsius
      default:
        return value; // default from Celsius
    }
  }

  // Convert weight from selected unit to kg
  double convertWeightToKg(double value) {
    switch (_weightUnit) {
      case 'kg':
        return value;
      case 'lbs':
        return value / 2.20462; // pounds to kg
      default:
        return value / 2.20462; // default from pounds
    }
  }

  // Convert fuel from selected unit to liters
  double convertFuelToLiters(double value) {
    switch (_fuelUnit) {
      case 'L':
        return value;
      case 'gal':
        return value / 0.264172; // US gallons to liters
      default:
        return value / 0.264172; // default from gallons
    }
  }
}
