import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/offline_map_service.dart';
import '../services/cache_service.dart';
import '../services/airport_service.dart';
import '../services/navaid_service.dart';
import '../services/runway_service.dart';
import '../services/frequency_service.dart';
import '../services/weather_service.dart';
import '../services/openaip_service.dart';
import '../utils/form_theme_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Screen for managing all offline data and caches
class OfflineDataScreen extends StatefulWidget {
  const OfflineDataScreen({super.key});

  @override
  State<OfflineDataScreen> createState() => _OfflineDataScreenState();
}

class _OfflineDataScreenState extends State<OfflineDataScreen> {
  final OfflineMapService _offlineMapService = OfflineMapService();
  final CacheService _cacheService = CacheService();
  final AirportService _airportService = AirportService();
  final NavaidService _navaidService = NavaidService();
  final RunwayService _runwayService = RunwayService();
  final FrequencyService _frequencyService = FrequencyService();
  final WeatherService _weatherService = WeatherService();
  final OpenAIPService _openAIPService = OpenAIPService();

  // Scroll controller to preserve position
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _currentTiles = 0;
  int _totalTiles = 0;
  int _skippedTiles = 0;
  int _downloadedTiles = 0;

  // Cache statistics
  Map<String, dynamic>? _mapCacheStats;
  Map<String, dynamic> _cacheStats = {};

  int _minZoom = 8;
  int _maxZoom = 14;

  // OpenAIP API key
  String _openAIPApiKey = '';
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllCacheStats();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      final settingsBox = await Hive.openBox('settings');
      final apiKey = settingsBox.get('openaip_api_key', defaultValue: '');
      setState(() {
        _openAIPApiKey = apiKey;
        _apiKeyController.text = apiKey;
      });
      if (apiKey.isNotEmpty) {
        _openAIPService.setApiKey(apiKey);
      }
    } catch (e) {
      // debugPrint('Error loading OpenAIP API key: $e');
    }
  }

  Future<void> _saveApiKey(String apiKey) async {
    try {
      final settingsBox = await Hive.openBox('settings');
      await settingsBox.put('openaip_api_key', apiKey);
      setState(() {
        _openAIPApiKey = apiKey;
      });
      _openAIPService.setApiKey(apiKey);

      // No success message for auto-save
      // debugPrint('✅ OpenAIP API key auto-saved');

      // If this is the first time setting an API key, load reporting points and airspaces
      if (apiKey.isNotEmpty) {
        // Check and load reporting points
        final cachedPoints = await _openAIPService.getCachedReportingPoints();
        final cachedAirspaces = await _openAIPService.getCachedAirspaces();

        if (cachedPoints.isEmpty || cachedAirspaces.isEmpty) {
          // debugPrint('📍 First time API key set, loading data...');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text('Loading airspaces and reporting points...'),
                    ),
                  ],
                ),
                duration: Duration(seconds: 60),
              ),
            );
          }

          try {
            // Load both in parallel
            final futures = <Future>[];

            if (cachedPoints.isEmpty) {
              futures.add(_openAIPService.fetchAllReportingPoints());
            }

            if (cachedAirspaces.isEmpty) {
              futures.add(_openAIPService.fetchAllAirspaces());
            }

            await Future.wait(futures);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Airspaces and reporting points loaded successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
            // Reload cache statistics
            await _loadAllCacheStats();
          } catch (e) {
            // debugPrint('❌ Error loading data: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading data: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      // debugPrint('Error saving OpenAIP API key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving API key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAllCacheStats({bool preserveScroll = false}) async {
    // Save current scroll position if requested
    double? scrollPosition;
    if (preserveScroll && _scrollController.hasClients) {
      scrollPosition = _scrollController.offset;
    }

    // Don't show loading indicator if we're preserving scroll
    if (!preserveScroll) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Initialize services if needed
      await _cacheService.initialize();
      await _weatherService.initialize();

      // Get map cache statistics
      final mapStats = await _offlineMapService.getCacheStatistics();

      // Get data cache statistics
      final stats = await _getCacheStatistics();

      setState(() {
        _mapCacheStats = mapStats;
        _cacheStats = stats;
        _isLoading = false;
      });

      // Restore scroll position after rebuild
      if (scrollPosition != null && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            scrollPosition!,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        });
      }
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

  Future<Map<String, dynamic>> _getCacheStatistics() async {
    final Map<String, dynamic> stats = {};

    try {
      // Open boxes to get counts
      final airportsBox = await Hive.openBox<Map>('airports_cache');
      final navaidsBox = await Hive.openBox<Map>('navaids_cache');
      final runwaysBox = await Hive.openBox<Map>('runways_cache');
      final frequenciesBox = await Hive.openBox<Map>('frequencies_cache');
      final airspacesBox = await Hive.openBox<Map>('airspaces_cache');
      final reportingPointsBox = await Hive.openBox<Map>(
        'reporting_points_cache',
      );
      // Weather stats are now retrieved directly from WeatherService
      final metadataBox = await Hive.openBox('cache_metadata');

      // Get counts
      stats['airports'] = {
        'count': airportsBox.length,
        'lastFetch': metadataBox.get('airports_last_fetch'),
      };

      stats['navaids'] = {
        'count': navaidsBox.length,
        'lastFetch': metadataBox.get('navaids_last_fetch'),
      };

      stats['runways'] = {
        'count': runwaysBox.length,
        'lastFetch': metadataBox.get('runways_last_fetch'),
      };

      stats['frequencies'] = {
        'count': frequenciesBox.length,
        'lastFetch': metadataBox.get('frequencies_last_fetch'),
      };

      stats['airspaces'] = {
        'count': airspacesBox.length,
        'lastFetch': metadataBox.get('airspaces_last_fetch'),
      };

      stats['reportingPoints'] = {
        'count': reportingPointsBox.length,
        'lastFetch': metadataBox.get('reporting_points_last_fetch'),
      };

      // Get weather statistics from WeatherService
      final weatherStats = _weatherService.getCacheStatistics();
      stats['weather'] = {
        'metars': weatherStats['metars'] ?? 0,
        'tafs': weatherStats['tafs'] ?? 0,
        'lastFetch': weatherStats['lastFetch']?.toIso8601String(),
      };
    } catch (e) {
      // debugPrint('Error getting cache statistics: $e');
    }

    return stats;
  }

  String _formatLastFetch(String? lastFetch) {
    if (lastFetch == null) return 'Never';

    try {
      final date = DateTime.parse(lastFetch);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Refresh all data from network
  Future<void> _refreshAllData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // debugPrint('Refreshing all data...');

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Refreshing all aviation data...')),
              ],
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      // Refresh all data services
      final futures = [
        _airportService.refreshData(),
        _navaidService.refreshData(),
        _runwayService.fetchRunways(forceRefresh: true),
        _frequencyService.fetchFrequencies(forceRefresh: true),
        _weatherService.forceReload(),
      ];

      // Add airspaces refresh if API key is set
      if (_openAIPApiKey.isNotEmpty) {
        futures.add(_openAIPService.refreshAirspacesCache());
        futures.add(_openAIPService.refreshReportingPointsCache());
      }

      await Future.wait(futures);

      // Reload cache statistics
      await _loadAllCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // debugPrint('All data refreshed successfully');
    } catch (e) {
      // debugPrint('Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshAirspaces() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // debugPrint('Refreshing airspaces...');

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return FormThemeHelper.buildDialog(
              context: context,
              title: 'Loading Airspaces',
              content: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Fetching airspaces in tiles...',
                      style: TextStyle(color: FormThemeHelper.primaryTextColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This process fetches data in 20 tiles to avoid timeouts.\nIt may take a few minutes.',
                      style: TextStyle(fontSize: 12, color: FormThemeHelper.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      // Refresh airspaces
      await _openAIPService.refreshAirspacesCache();

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Reload cache statistics
      await _loadAllCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Airspaces refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // debugPrint('Error refreshing airspaces: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing airspaces: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshReportingPoints() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // debugPrint('Refreshing reporting points...');

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return FormThemeHelper.buildDialog(
              context: context,
              title: 'Loading Reporting Points',
              content: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Fetching reporting points in tiles...',
                      style: TextStyle(color: FormThemeHelper.primaryTextColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This process fetches data in 20 tiles to avoid timeouts.\nIt may take a few minutes.',
                      style: TextStyle(fontSize: 12, color: FormThemeHelper.secondaryTextColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      // Force refresh reporting points
      await _openAIPService.refreshReportingPointsCache(forceRefresh: true);

      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Reload cache statistics
      await _loadAllCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporting points refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // debugPrint('Error refreshing reporting points: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing reporting points: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshWeatherData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // debugPrint('Refreshing weather data...');

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Refreshing weather data...')),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Refresh weather data
      await _weatherService.forceReload();

      // Reload cache statistics
      await _loadAllCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weather data refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // debugPrint('Weather data refreshed successfully');
    } catch (e) {
      // debugPrint('Error refreshing weather data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing weather data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _clearSpecificCache(String cacheName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: 'Clear $cacheName Cache',
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Are you sure you want to clear the $cacheName cache? This data will be re-downloaded when needed.',
            style: TextStyle(color: FormThemeHelper.primaryTextColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: FormThemeHelper.getSecondaryButtonStyle(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        switch (cacheName) {
          case 'Airports':
            await _cacheService.clearAirportsCache();
            break;
          case 'Navaids':
            await _cacheService.clearNavaidsCache();
            break;
          case 'Runways':
            await _cacheService.clearRunwaysCache();
            break;
          case 'Frequencies':
            await _cacheService.clearFrequenciesCache();
            break;
          case 'Airspaces':
            await _cacheService.clearAirspacesCache();
            break;
          case 'Reporting Points':
            await _cacheService.clearReportingPointsCache();
            break;
          case 'Weather':
            await _cacheService.clearWeatherCache();
            break;
          case 'Map Tiles':
            await _offlineMapService.clearCache();
            break;
        }
        await _loadAllCacheStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$cacheName cache cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing $cacheName cache: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllCaches() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: 'Clear All Caches',
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Are you sure you want to clear all caches? This will delete all offline data including map tiles, aviation data, and weather information.',
            style: TextStyle(color: FormThemeHelper.primaryTextColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: FormThemeHelper.getSecondaryButtonStyle(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Future.wait([
          _cacheService.clearAllCaches(),
          _offlineMapService.clearCache(),
        ]);
        await _loadAllCacheStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All caches cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error clearing caches: $e')));
        }
      }
    }
  }

  Widget _buildCacheCard({
    required String title,
    required IconData icon,
    required int count,
    required String lastFetch,
    required VoidCallback onClear,
    String? subtitle,
    VoidCallback? onRefresh,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: FormThemeHelper.sectionBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FormThemeHelper.sectionBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: FormThemeHelper.primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FormThemeHelper.primaryTextColor,
                    ),
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: Icon(Icons.refresh, color: FormThemeHelper.primaryAccent),
                    onPressed: _isRefreshing ? null : onRefresh,
                    tooltip: 'Refresh $title',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onClear,
                  tooltip: 'Clear cache',
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: FormThemeHelper.secondaryTextColor),
              ),
            ],
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entries: $count',
                  style: TextStyle(fontSize: 16, color: FormThemeHelper.primaryTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated: $lastFetch',
                  style: TextStyle(fontSize: 14, color: FormThemeHelper.secondaryTextColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadCurrentArea() async {
    // Use current map bounds or a default area
    await _downloadArea(
      northEast: const LatLng(50.0, 15.0), // Example coordinates
      southWest: const LatLng(48.0, 12.0),
    );
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
      _skippedTiles = 0;
      _downloadedTiles = 0;
    });

    try {
      await _offlineMapService.downloadAreaTiles(
        northEast: northEast,
        southWest: southWest,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        onProgress: (current, total, skipped, downloaded) {
          // Update internal values without setState
          _currentTiles = current;
          _totalTiles = total;
          _skippedTiles = skipped;
          _downloadedTiles = downloaded;
          _downloadProgress = total > 0 ? current / total : 0.0;

          // Only update UI every 10 tiles or at 5% intervals to reduce rebuilds
          final shouldUpdateUI = current % 10 == 0 || 
              (total > 0 && (current / total * 100).round() % 5 == 0) ||
              current == total;
          
          if (shouldUpdateUI && mounted) {
            setState(() {
              // Trigger UI update
            });
          }

          // Update cache statistics every 25 tiles, preserving scroll position
          if (current % 25 == 0 || current == total) {
            _loadAllCacheStats(preserveScroll: true);
          }
        },
      );

      if (mounted) {
        final message = _skippedTiles > 0
            ? 'Downloaded $_downloadedTiles new tiles, skipped $_skippedTiles cached tiles'
            : 'Downloaded $_downloadedTiles tiles successfully!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isUserCancelled = e.toString().contains('cancelled by user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUserCancelled ? 'Download cancelled' : 'Download failed: $e',
            ),
            backgroundColor: isUserCancelled ? Colors.orange : Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDownloading = false;
      });
      await _loadAllCacheStats(preserveScroll: true);
    }
  }

  void _stopDownload() {
    _offlineMapService.cancelDownload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Offline Data',
          style: TextStyle(color: FormThemeHelper.primaryTextColor),
        ),
        backgroundColor: FormThemeHelper.dialogBackgroundColor,
        foregroundColor: FormThemeHelper.primaryTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshAllData,
            tooltip: 'Refresh all data',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearAllCaches,
            tooltip: 'Clear all caches',
          ),
        ],
      ),
      backgroundColor: FormThemeHelper.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadAllCacheStats(),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Data Caches Section
                    Text(
                      'Aviation Data Caches',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: FormThemeHelper.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Airports cache
                    _buildCacheCard(
                      title: 'Airports',
                      icon: Icons.flight_land,
                      count: _cacheStats['airports']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(
                        _cacheStats['airports']?['lastFetch'],
                      ),
                      onClear: () => _clearSpecificCache('Airports'),
                      subtitle: 'Airport information and details',
                    ),

                    const SizedBox(height: 8),

                    // Navaids cache
                    _buildCacheCard(
                      title: 'Navigation Aids',
                      icon: Icons.radar,
                      count: _cacheStats['navaids']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(
                        _cacheStats['navaids']?['lastFetch'],
                      ),
                      onClear: () => _clearSpecificCache('Navaids'),
                      subtitle: 'VOR, NDB, and other navigation aids',
                    ),

                    const SizedBox(height: 8),

                    // Runways cache
                    _buildCacheCard(
                      title: 'Runways',
                      icon: Icons.horizontal_rule,
                      count: _cacheStats['runways']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(
                        _cacheStats['runways']?['lastFetch'],
                      ),
                      onClear: () => _clearSpecificCache('Runways'),
                      subtitle: 'Runway information for airports',
                    ),

                    const SizedBox(height: 8),

                    // Frequencies cache
                    _buildCacheCard(
                      title: 'Frequencies',
                      icon: Icons.radio,
                      count: _cacheStats['frequencies']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(
                        _cacheStats['frequencies']?['lastFetch'],
                      ),
                      onClear: () => _clearSpecificCache('Frequencies'),
                      subtitle: 'Radio frequencies for airports',
                    ),

                    const SizedBox(height: 8),

                    // Airspaces cache
                    _buildCacheCard(
                      title: 'Airspaces',
                      icon: Icons.layers,
                      count: _cacheStats['airspaces']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(
                        _cacheStats['airspaces']?['lastFetch'],
                      ),
                      onClear: () => _clearSpecificCache('Airspaces'),
                      subtitle: 'Controlled airspaces and restricted areas',
                      onRefresh: _openAIPApiKey.isNotEmpty
                          ? _refreshAirspaces
                          : null,
                    ),

                    const SizedBox(height: 8),

                    // Reporting points cache
                    _buildCacheCard(
                      title: 'Reporting Points',
                      icon: Icons.location_on,
                      count: _cacheStats['reportingPoints']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(
                        _cacheStats['reportingPoints']?['lastFetch'],
                      ),
                      onClear: () => _clearSpecificCache('Reporting Points'),
                      subtitle: 'VFR reporting points for navigation',
                      onRefresh: _openAIPApiKey.isNotEmpty
                          ? _refreshReportingPoints
                          : null,
                    ),

                    const SizedBox(height: 8),

                    // Weather cache
                    Container(
                      decoration: BoxDecoration(
                        color: FormThemeHelper.sectionBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FormThemeHelper.sectionBorderColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.cloud, size: 24, color: FormThemeHelper.primaryAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Weather Data',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: FormThemeHelper.primaryTextColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.refresh, color: FormThemeHelper.primaryAccent),
                                  onPressed: _isRefreshing ? null : _refreshWeatherData,
                                  tooltip: 'Refresh weather data',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _clearSpecificCache('Weather'),
                                  tooltip: 'Clear cache',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'METARs, TAFs, and weather information',
                              style: TextStyle(fontSize: 14, color: FormThemeHelper.secondaryTextColor),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'METARs: ${_cacheStats['weather']?['metars'] ?? 0}',
                                      style: TextStyle(fontSize: 16, color: FormThemeHelper.primaryTextColor),
                                    ),
                                    Text(
                                      'TAFs: ${_cacheStats['weather']?['tafs'] ?? 0}',
                                      style: TextStyle(fontSize: 16, color: FormThemeHelper.primaryTextColor),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Updated: ${_formatLastFetch(_cacheStats['weather']?['lastFetch'])}',
                                  style: TextStyle(fontSize: 14, color: FormThemeHelper.secondaryTextColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    // OpenAIP Configuration
                    FormThemeHelper.buildSection(
                      title: 'OpenAIP Configuration',
                      children: [
                        FormThemeHelper.buildFormField(
                          controller: _apiKeyController,
                          labelText: 'API Key',
                          hintText: 'Enter your OpenAIP API key',
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _saveApiKey(_apiKeyController.text),
                              style: FormThemeHelper.getPrimaryButtonStyle(),
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                if (_apiKeyController.text.isNotEmpty) {
                                  final nav = Navigator.of(context);
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => FormThemeHelper.buildDialog(
                                      context: context,
                                      title: 'Testing API Key',
                                      content: const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  );
                                  
                                  try {
                                    _openAIPService.setApiKey(_apiKeyController.text);
                                    // Try to fetch a small amount of data to test the API key
                                    await _openAIPService.getCachedAirspaces();
                                    if (mounted) {
                                      nav.pop();
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('API key is valid!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      nav.pop();
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text('API key test failed: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: FormThemeHelper.getOutlinedButtonStyle(),
                              child: const Text('Test API Key'),
                            ),
                          ],
                        ),
                        if (_openAIPApiKey.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Auto-loading of airspaces and reporting points enabled',
                            style: TextStyle(
                              fontSize: 12,
                              color: FormThemeHelper.secondaryTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Offline Map Tiles Section
                    Text(
                      'Offline Map Tiles',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: FormThemeHelper.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: FormThemeHelper.sectionBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: FormThemeHelper.sectionBorderColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.map, size: 24, color: FormThemeHelper.primaryAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Map Tiles Cache',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: FormThemeHelper.primaryTextColor,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _clearSpecificCache('Map Tiles'),
                                  tooltip: 'Clear map cache',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_mapCacheStats != null && (_mapCacheStats!['tileCount'] ?? 0) > 0) ...[
                              Text(
                                'Total tiles: ${_mapCacheStats!['tileCount'] ?? 0}',
                                style: TextStyle(fontSize: 16, color: FormThemeHelper.primaryTextColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total size: ${((_mapCacheStats!['totalSizeBytes'] ?? 0) / 1024 / 1024).toStringAsFixed(2)} MB',
                                style: TextStyle(fontSize: 16, color: FormThemeHelper.primaryTextColor),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tiles by zoom level:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: FormThemeHelper.primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_mapCacheStats!['tilesByZoom'] != null)
                                ...((_mapCacheStats!['tilesByZoom'] as Map<int, Map<String, int>>?) ?? {})
                                    .entries
                                    .map((entry) {
                                final zoom = entry.key;
                                final count = entry.value['count'] ?? 0;
                                final sizeBytes = entry.value['sizeBytes'] ?? 0;
                                final sizeMB = sizeBytes / 1024 / 1024;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Zoom $zoom:',
                                        style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                                      ),
                                      Text(
                                        '$count tiles (${sizeMB.toStringAsFixed(2)} MB)',
                                        style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                                      ),
                                    ],
                                  ),
                                );
                                }),
                            ] else
                              Text(
                                'No cached tiles',
                                style: TextStyle(fontSize: 16, color: FormThemeHelper.secondaryTextColor),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Download controls
                    FormThemeHelper.buildSection(
                      title: 'Download Map Tiles',
                      children: [
                        Text(
                          'Download map tiles for offline use',
                          style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Min Zoom: $_minZoom',
                                    style: TextStyle(color: FormThemeHelper.primaryTextColor),
                                  ),
                                  Slider(
                                    value: _minZoom.toDouble(),
                                    min: 1,
                                    max: 18,
                                    divisions: 17,
                                    label: _minZoom.toString(),
                                    activeColor: FormThemeHelper.primaryAccent,
                                    onChanged: (value) {
                                      setState(() {
                                        _minZoom = value.toInt();
                                        if (_minZoom > _maxZoom) {
                                          _maxZoom = _minZoom;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Max Zoom: $_maxZoom',
                                    style: TextStyle(color: FormThemeHelper.primaryTextColor),
                                  ),
                                  Slider(
                                    value: _maxZoom.toDouble(),
                                    min: 1,
                                    max: 18,
                                    divisions: 17,
                                    label: _maxZoom.toString(),
                                    activeColor: FormThemeHelper.primaryAccent,
                                    onChanged: (value) {
                                      setState(() {
                                        _maxZoom = value.toInt();
                                        if (_maxZoom < _minZoom) {
                                          _minZoom = _maxZoom;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isDownloading) ...[
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: FormThemeHelper.borderColor.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(FormThemeHelper.primaryAccent),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress: $_currentTiles / $_totalTiles tiles',
                                style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                              ),
                              Text(
                                '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: FormThemeHelper.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Downloaded: $_downloadedTiles',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FormThemeHelper.secondaryTextColor,
                                ),
                              ),
                              Text(
                                'Skipped: $_skippedTiles',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FormThemeHelper.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _stopDownload,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop Download'),
                          ),
                        ] else
                          ElevatedButton.icon(
                            onPressed: _downloadCurrentArea,
                            style: FormThemeHelper.getPrimaryButtonStyle(),
                            icon: const Icon(Icons.download),
                            label: const Text('Download Current Area'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}