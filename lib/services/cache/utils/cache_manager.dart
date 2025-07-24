import 'dart:developer' as developer;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/cache_constants.dart';

/// Manages Hive box initialization and lifecycle
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  bool _isInitialized = false;
  
  late Box<Map> _airportsBox;
  late Box<Map> _navaidsBox;
  late Box<Map> _runwaysBox;
  late Box<Map> _frequenciesBox;
  late Box<Map> _airspacesBox;
  late Box<Map> _reportingPointsBox;
  late Box<dynamic> _metadataBox;
  late Box<String> _weatherBox;

  bool get isInitialized => _isInitialized;
  
  Box<Map> get airportsBox => _airportsBox;
  Box<Map> get navaidsBox => _navaidsBox;
  Box<Map> get runwaysBox => _runwaysBox;
  Box<Map> get frequenciesBox => _frequenciesBox;
  Box<Map> get airspacesBox => _airspacesBox;
  Box<Map> get reportingPointsBox => _reportingPointsBox;
  Box<dynamic> get metadataBox => _metadataBox;
  Box<String> get weatherBox => _weatherBox;

  /// Initialize Hive boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive with Flutter support
      await Hive.initFlutter();

      _airportsBox = await Hive.openBox<Map>(CacheConstants.airportsBoxName);
      _navaidsBox = await Hive.openBox<Map>(CacheConstants.navaidsBoxName);
      _runwaysBox = await Hive.openBox<Map>(CacheConstants.runwaysBoxName);
      _frequenciesBox = await Hive.openBox<Map>(CacheConstants.frequenciesBoxName);
      _airspacesBox = await Hive.openBox<Map>(CacheConstants.airspacesBoxName);
      _reportingPointsBox = await Hive.openBox<Map>(CacheConstants.reportingPointsBoxName);
      _metadataBox = await Hive.openBox(CacheConstants.metadataBoxName);
      _weatherBox = await Hive.openBox<String>(CacheConstants.weatherBoxName);

      _isInitialized = true;
      developer.log('✅ Cache manager initialized');
    } catch (e) {
      developer.log('❌ Error initializing cache manager: $e');
      rethrow;
    }
  }

  /// Ensure all boxes are initialized and open
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }

    // Check if boxes are still open, and reopen them if they've been closed
    try {
      if (!_airportsBox.isOpen) {
        developer.log('🔄 Airports box was closed, reopening...');
        _airportsBox = await Hive.openBox<Map>(CacheConstants.airportsBoxName);
      }
      if (!_navaidsBox.isOpen) {
        developer.log('🔄 Navaids box was closed, reopening...');
        _navaidsBox = await Hive.openBox<Map>(CacheConstants.navaidsBoxName);
      }
      if (!_runwaysBox.isOpen) {
        developer.log('🔄 Runways box was closed, reopening...');
        _runwaysBox = await Hive.openBox<Map>(CacheConstants.runwaysBoxName);
      }
      if (!_frequenciesBox.isOpen) {
        developer.log('🔄 Frequencies box was closed, reopening...');
        _frequenciesBox = await Hive.openBox<Map>(CacheConstants.frequenciesBoxName);
      }
      if (!_airspacesBox.isOpen) {
        developer.log('🔄 Airspaces box was closed, reopening...');
        _airspacesBox = await Hive.openBox<Map>(CacheConstants.airspacesBoxName);
      }
      if (!_reportingPointsBox.isOpen) {
        developer.log('🔄 Reporting points box was closed, reopening...');
        _reportingPointsBox = await Hive.openBox<Map>(CacheConstants.reportingPointsBoxName);
      }
      if (!_metadataBox.isOpen) {
        developer.log('🔄 Metadata box was closed, reopening...');
        _metadataBox = await Hive.openBox(CacheConstants.metadataBoxName);
      }
      if (!_weatherBox.isOpen) {
        developer.log('🔄 Weather box was closed, reopening...');
        _weatherBox = await Hive.openBox<String>(CacheConstants.weatherBoxName);
      }
    } catch (e) {
      developer.log('❌ Error reopening boxes: $e, reinitializing...');
      _isInitialized = false;
      await initialize();
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await _airportsBox.clear();
    await _navaidsBox.clear();
    await _runwaysBox.clear();
    await _frequenciesBox.clear();
    await _airspacesBox.clear();
    await _reportingPointsBox.clear();
    await _weatherBox.clear();
    await _metadataBox.clear();
    developer.log('🗑️ All caches cleared');
  }

  /// Close all boxes
  void dispose() {
    if (_isInitialized) {
      Hive.close();
      _isInitialized = false;
      developer.log('📦 All Hive boxes closed');
    }
  }
}