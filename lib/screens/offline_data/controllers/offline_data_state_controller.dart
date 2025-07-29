import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State controller for offline data screen
class OfflineDataStateController extends ChangeNotifier {
  static const String _keyMinZoom = 'offline_min_zoom';
  static const String _keyMaxZoom = 'offline_max_zoom';
  static const String _keyDownloadMapTilesForFlightPlan = 'download_map_tiles_for_flight_plan';
  static const String _keyValidateTilesOnStartup = 'validate_tiles_on_startup';
  
  SharedPreferences? _prefs;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _currentTiles = 0;
  int _totalTiles = 0;
  int _skippedTiles = 0;
  int _downloadedTiles = 0;
  int _minZoom = 8;
  int _maxZoom = 14;
  bool _downloadMapTilesForFlightPlan = true;
  bool _validateTilesOnStartup = true;

  // Cache statistics
  Map<String, dynamic>? _mapCacheStats;
  Map<String, dynamic> _cacheStats = {};

  // Getters
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  int get currentTiles => _currentTiles;
  int get totalTiles => _totalTiles;
  int get skippedTiles => _skippedTiles;
  int get downloadedTiles => _downloadedTiles;
  int get minZoom => _minZoom;
  int get maxZoom => _maxZoom;
  bool get downloadMapTilesForFlightPlan => _downloadMapTilesForFlightPlan;
  bool get validateTilesOnStartup => _validateTilesOnStartup;
  Map<String, dynamic>? get mapCacheStats => _mapCacheStats;
  Map<String, dynamic> get cacheStats => _cacheStats;

  OfflineDataStateController() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    if (_prefs != null) {
      _minZoom = _prefs!.getInt(_keyMinZoom) ?? 8;
      _maxZoom = _prefs!.getInt(_keyMaxZoom) ?? 14;
      _downloadMapTilesForFlightPlan = _prefs!.getBool(_keyDownloadMapTilesForFlightPlan) ?? true;
      _validateTilesOnStartup = _prefs!.getBool(_keyValidateTilesOnStartup) ?? true;
      notifyListeners();
    }
  }

  // Setters
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setRefreshing(bool value) {
    _isRefreshing = value;
    notifyListeners();
  }

  void setDownloading(bool value) {
    _isDownloading = value;
    notifyListeners();
  }

  void updateDownloadProgress(int current, int total, int skipped, int downloaded) {
    _currentTiles = current;
    _totalTiles = total;
    _skippedTiles = skipped;
    _downloadedTiles = downloaded;
    _downloadProgress = total > 0 ? current / total : 0.0;
    
    // Only notify every 10 tiles or at 5% intervals to reduce rebuilds
    final shouldUpdate = current % 10 == 0 || 
        (total > 0 && (current / total * 100).round() % 5 == 0) ||
        current == total;
        
    if (shouldUpdate) {
      notifyListeners();
    }
  }

  void setZoomLevels(int minZoom, int maxZoom) {
    _minZoom = minZoom;
    _maxZoom = maxZoom;
    notifyListeners();
  }

  void setMinZoom(int value) {
    _minZoom = value;
    if (_minZoom > _maxZoom) {
      _maxZoom = _minZoom;
    }
    _prefs?.setInt(_keyMinZoom, _minZoom);
    notifyListeners();
  }

  void setMaxZoom(int value) {
    _maxZoom = value;
    if (_maxZoom < _minZoom) {
      _minZoom = _maxZoom;
    }
    _prefs?.setInt(_keyMaxZoom, _maxZoom);
    notifyListeners();
  }

  void setDownloadMapTilesForFlightPlan(bool value) {
    _downloadMapTilesForFlightPlan = value;
    _prefs?.setBool(_keyDownloadMapTilesForFlightPlan, value);
    notifyListeners();
  }
  
  void setValidateTilesOnStartup(bool value) {
    _validateTilesOnStartup = value;
    _prefs?.setBool(_keyValidateTilesOnStartup, value);
    notifyListeners();
  }

  void setMapCacheStats(Map<String, dynamic>? stats) {
    _mapCacheStats = stats;
    notifyListeners();
  }

  void setCacheStats(Map<String, dynamic> stats) {
    _cacheStats = stats;
    notifyListeners();
  }

  void resetDownloadState() {
    _isDownloading = false;
    _downloadProgress = 0.0;
    _currentTiles = 0;
    _totalTiles = 0;
    _skippedTiles = 0;
    _downloadedTiles = 0;
    notifyListeners();
  }
}