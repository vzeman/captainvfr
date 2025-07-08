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
  
  late SharedPreferences _prefs;
  bool _isInitialized = false;
  
  // Settings with defaults
  bool _rotateMapWithHeading = false;
  bool _showAirspaces = true;
  bool _showNavaids = true;
  bool _autoSaveFlights = true;
  bool _highPrecisionTracking = false;
  bool _darkMode = true;
  String _units = 'metric'; // 'metric' or 'imperial'
  
  // Getters
  bool get rotateMapWithHeading => _rotateMapWithHeading;
  bool get showAirspaces => _showAirspaces;
  bool get showNavaids => _showNavaids;
  bool get autoSaveFlights => _autoSaveFlights;
  bool get highPrecisionTracking => _highPrecisionTracking;
  bool get darkMode => _darkMode;
  String get units => _units;
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
    _units = _prefs.getString(_keyUnits) ?? 'metric';
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
    if (value == 'metric' || value == 'imperial') {
      _units = value;
      await _prefs.setString(_keyUnits, value);
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
    await setUnits('metric');
  }
  
  // Unit conversion helpers
  double convertDistance(double meters) {
    if (_units == 'imperial') {
      return meters * 0.000621371; // meters to miles
    }
    return meters / 1000; // meters to kilometers
  }
  
  String distanceUnit() {
    return _units == 'imperial' ? 'mi' : 'km';
  }
  
  double convertAltitude(double meters) {
    if (_units == 'imperial') {
      return meters * 3.28084; // meters to feet
    }
    return meters;
  }
  
  String altitudeUnit() {
    return _units == 'imperial' ? 'ft' : 'm';
  }
  
  double convertSpeed(double metersPerSecond) {
    if (_units == 'imperial') {
      return metersPerSecond * 1.94384; // m/s to knots
    }
    return metersPerSecond * 3.6; // m/s to km/h
  }
  
  String speedUnit() {
    return _units == 'imperial' ? 'kt' : 'km/h';
  }
}