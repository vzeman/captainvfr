import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/offline_map_service.dart';

/// Screen for managing offline map downloads and cache
class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final OfflineMapService _offlineMapService = OfflineMapService();
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _currentTiles = 0;
  int _totalTiles = 0;
  Map<String, dynamic>? _cacheStats;

  // Download area controllers
  final TextEditingController _northController = TextEditingController();
  final TextEditingController _southController = TextEditingController();
  final TextEditingController _eastController = TextEditingController();
  final TextEditingController _westController = TextEditingController();
  int _minZoom = 8;
  int _maxZoom = 14;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    try {
      final stats = await _offlineMapService.getCacheStatistics();
      setState(() {
        _cacheStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cache stats: $e')),
        );
      }
    }
  }

  Future<void> _downloadCurrentArea() async {
    // Use current map bounds or a default area
    await _downloadArea(
      northEast: const LatLng(50.0, 15.0), // Example coordinates
      southWest: const LatLng(48.0, 12.0),
    );
  }

  Future<void> _downloadCustomArea() async {
    if (_northController.text.isEmpty || _southController.text.isEmpty ||
        _eastController.text.isEmpty || _westController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all coordinates')),
      );
      return;
    }

    try {
      final north = double.parse(_northController.text);
      final south = double.parse(_southController.text);
      final east = double.parse(_eastController.text);
      final west = double.parse(_westController.text);

      await _downloadArea(
        northEast: LatLng(north, east),
        southWest: LatLng(south, west),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid coordinates: $e')),
      );
    }
  }

  Future<void> _downloadArea({
    required LatLng northEast,
    required LatLng southWest,
  }) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _currentTiles = 0;
      _totalTiles = 0;
    });

    try {
      await _offlineMapService.downloadAreaTiles(
        northEast: northEast,
        southWest: southWest,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        onProgress: (current, total) {
          setState(() {
            _currentTiles = current;
            _totalTiles = total;
            _downloadProgress = total > 0 ? current / total : 0.0;
          });

          // Update cache statistics every 50 tiles or every 5% progress
          if (current % 50 == 0 || (total > 0 && (current / total * 100).round() % 5 == 0)) {
            _loadCacheStats();
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Map tiles downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isUserCancelled = e.toString().contains('cancelled by user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUserCancelled ? '🛑 Download cancelled' : 'Download failed: $e'),
            backgroundColor: isUserCancelled ? Colors.orange : Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
      });
      await _loadCacheStats();
    }
  }

  /// Stop the current download
  void _stopDownload() {
    _offlineMapService.cancelDownload();
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all cached map tiles?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _offlineMapService.clearCache();
        await _loadCacheStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cache cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing cache: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Maps'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cache Statistics Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cache Statistics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_cacheStats != null) ...[
                            Text('Total Tiles: ${_cacheStats!['totalTiles']}'),
                            Text('Total Size: ${_cacheStats!['totalSizeMB']} MB'),
                            const SizedBox(height: 8),
                            const Text('Zoom Levels:'),
                            ...(_cacheStats!['zoomLevels'] as List).map(
                              (level) => Text(
                                '  Level ${level['z']}: ${level['count']} tiles',
                              ),
                            ),
                          ] else
                            const Text('No cached tiles'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _clearCache,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Clear Cache'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Download Progress Card
                  if (_isDownloading)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Downloading...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: _downloadProgress),
                            const SizedBox(height: 8),
                            Text('$_currentTiles / $_totalTiles tiles'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _stopDownload,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.stop, size: 18),
                                  SizedBox(width: 8),
                                  Text('Stop Download'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Quick Download Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Download',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Download tiles for current map area'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _isDownloading ? null : _downloadCurrentArea,
                            child: const Text('Download Current Area'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Custom Area Download Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Custom Area Download',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Coordinate inputs
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _northController,
                                  decoration: const InputDecoration(
                                    labelText: 'North Latitude',
                                    hintText: '50.0',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _eastController,
                                  decoration: const InputDecoration(
                                    labelText: 'East Longitude',
                                    hintText: '15.0',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _southController,
                                  decoration: const InputDecoration(
                                    labelText: 'South Latitude',
                                    hintText: '48.0',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _westController,
                                  decoration: const InputDecoration(
                                    labelText: 'West Longitude',
                                    hintText: '12.0',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Zoom level sliders
                          Text('Min Zoom Level: $_minZoom'),
                          Slider(
                            value: _minZoom.toDouble(),
                            min: 4,
                            max: 16,
                            divisions: 12,
                            onChanged: (value) {
                              setState(() {
                                _minZoom = value.round();
                                if (_minZoom > _maxZoom) _maxZoom = _minZoom;
                              });
                            },
                          ),
                          Text('Max Zoom Level: $_maxZoom'),
                          Slider(
                            value: _maxZoom.toDouble(),
                            min: 4,
                            max: 16,
                            divisions: 12,
                            onChanged: (value) {
                              setState(() {
                                _maxZoom = value.round();
                                if (_maxZoom < _minZoom) _minZoom = _maxZoom;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          ElevatedButton(
                            onPressed: _isDownloading ? null : _downloadCustomArea,
                            child: const Text('Download Custom Area'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Information Card
                  Card(
                    color: Colors.blue[50],
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ℹ️ Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Offline maps allow you to use navigation even without internet connection\n'
                            '• Higher zoom levels provide more detail but require more storage\n'
                            '• Download areas before your flight for best experience\n'
                            '• Maps are automatically cached when viewed online',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _northController.dispose();
    _southController.dispose();
    _eastController.dispose();
    _westController.dispose();
    super.dispose();
  }
}
