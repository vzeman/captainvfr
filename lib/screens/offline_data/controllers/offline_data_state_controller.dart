import 'package:flutter/material.dart';

/// State controller for offline data screen
class OfflineDataStateController extends ChangeNotifier {
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
  Map<String, dynamic>? get mapCacheStats => _mapCacheStats;
  Map<String, dynamic> get cacheStats => _cacheStats;

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
    notifyListeners();
  }

  void setMaxZoom(int value) {
    _maxZoom = value;
    if (_maxZoom < _minZoom) {
      _minZoom = _maxZoom;
    }
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