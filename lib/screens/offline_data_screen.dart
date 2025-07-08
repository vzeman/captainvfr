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
      debugPrint('Error loading OpenAIP API key: $e');
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
      debugPrint('✅ OpenAIP API key auto-saved');
      
      // If this is the first time setting an API key, load reporting points and airspaces
      if (apiKey.isNotEmpty) {
        // Check and load reporting points
        final cachedPoints = await _openAIPService.getCachedReportingPoints();
        final cachedAirspaces = await _openAIPService.getCachedAirspaces();
        
        if (cachedPoints.isEmpty || cachedAirspaces.isEmpty) {
          debugPrint('📍 First time API key set, loading data...');
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
              debugPrint('📍 Loading reporting points...');
              futures.add(_openAIPService.fetchAllReportingPoints());
            }
            
            if (cachedAirspaces.isEmpty) {
              debugPrint('🌍 Loading airspaces...');
              futures.add(_openAIPService.fetchAllAirspaces());
            }
            
            await Future.wait(futures);
            
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Airspaces and reporting points loaded successfully'),
                backgroundColor: Colors.green,
              ),
            );
            // Reload cache statistics
            await _loadAllCacheStats();
          } catch (e) {
            debugPrint('❌ Error loading data: $e');
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
      debugPrint('Error saving OpenAIP API key: $e');
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
      final reportingPointsBox = await Hive.openBox<Map>('reporting_points_cache');
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
      debugPrint('Error getting cache statistics: $e');
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
      debugPrint('Refreshing all data...');

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
                Expanded(
                  child: Text('Refreshing all aviation data...'),
                ),
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

      debugPrint('All data refreshed successfully');
    } catch (e) {
      debugPrint('Error refreshing data: $e');
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
      debugPrint('Refreshing airspaces...');

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Loading Airspaces'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Fetching airspaces in tiles...'),
                  const SizedBox(height: 8),
                  Text(
                    'This process fetches data in 20 tiles to avoid timeouts.\nIt may take a few minutes.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
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
      
      debugPrint('Error refreshing airspaces: $e');
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
      debugPrint('Refreshing reporting points...');

      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Loading Reporting Points'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Fetching reporting points in tiles...'),
                  const SizedBox(height: 8),
                  Text(
                    'This process fetches data in 20 tiles to avoid timeouts.\nIt may take a few minutes.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
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
      
      debugPrint('Error refreshing reporting points: $e');
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
      debugPrint('Refreshing weather data...');

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
                Expanded(
                  child: Text('Refreshing weather data...'),
                ),
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

      debugPrint('Weather data refreshed successfully');
    } catch (e) {
      debugPrint('Error refreshing weather data: $e');
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

  Future<void> _clearSpecificCache(String cacheType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear $cacheType Cache'),
        content: Text('Are you sure you want to clear the $cacheType cache?'),
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
        switch (cacheType.toLowerCase()) {
          case 'airports':
            await _cacheService.clearAirportsCache();
            break;
          case 'navaids':
            await _cacheService.clearNavaidsCache();
            break;
          case 'runways':
            await _cacheService.clearRunwaysCache();
            break;
          case 'frequencies':
            await _cacheService.clearFrequenciesCache();
            break;
          case 'airspaces':
            await _cacheService.clearAirspacesCache();
            break;
          case 'reporting points':
            await _cacheService.clearReportingPointsCache();
            break;
          case 'weather':
            await _cacheService.clearWeatherCache();
            break;
          case 'map tiles':
            await _offlineMapService.clearCache();
            break;
        }
        
        await _loadAllCacheStats();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$cacheType cache cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing $cacheType cache: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllCaches() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Caches'),
        content: const Text('Are you sure you want to clear all cached data? This includes map tiles and all aviation data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _cacheService.clearAllCaches();
        await _offlineMapService.clearCache();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing caches: $e')),
          );
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
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onRefresh != null) 
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.blue),
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entries: $count',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated: $lastFetch',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
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
          setState(() {
            _currentTiles = current;
            _totalTiles = total;
            _skippedTiles = skipped;
            _downloadedTiles = downloaded;
            _downloadProgress = total > 0 ? current / total : 0.0;
          });

          // Update cache statistics periodically, preserving scroll position
          if (current % 50 == 0 || (total > 0 && (current / total * 100).round() % 5 == 0)) {
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
            content: Text(isUserCancelled ? 'Download cancelled' : 'Download failed: $e'),
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
        title: const Text('Offline Data Management'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadAllCacheStats(),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Data Caches Section
                    const Text(
                      'Aviation Data Caches',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Airports cache
                    _buildCacheCard(
                      title: 'Airports',
                      icon: Icons.flight_land,
                      count: _cacheStats['airports']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(_cacheStats['airports']?['lastFetch']),
                      onClear: () => _clearSpecificCache('Airports'),
                      subtitle: 'Airport information and details',
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Navaids cache
                    _buildCacheCard(
                      title: 'Navigation Aids',
                      icon: Icons.radar,
                      count: _cacheStats['navaids']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(_cacheStats['navaids']?['lastFetch']),
                      onClear: () => _clearSpecificCache('Navaids'),
                      subtitle: 'VOR, NDB, and other navigation aids',
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Runways cache
                    _buildCacheCard(
                      title: 'Runways',
                      icon: Icons.horizontal_rule,
                      count: _cacheStats['runways']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(_cacheStats['runways']?['lastFetch']),
                      onClear: () => _clearSpecificCache('Runways'),
                      subtitle: 'Runway information for airports',
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Frequencies cache
                    _buildCacheCard(
                      title: 'Frequencies',
                      icon: Icons.radio,
                      count: _cacheStats['frequencies']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(_cacheStats['frequencies']?['lastFetch']),
                      onClear: () => _clearSpecificCache('Frequencies'),
                      subtitle: 'Radio frequencies for airports',
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Airspaces cache
                    _buildCacheCard(
                      title: 'Airspaces',
                      icon: Icons.layers,
                      count: _cacheStats['airspaces']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(_cacheStats['airspaces']?['lastFetch']),
                      onClear: () => _clearSpecificCache('Airspaces'),
                      subtitle: 'Controlled airspaces and restricted areas',
                      onRefresh: _openAIPApiKey.isNotEmpty ? _refreshAirspaces : null,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Reporting points cache
                    _buildCacheCard(
                      title: 'Reporting Points',
                      icon: Icons.location_on,
                      count: _cacheStats['reportingPoints']?['count'] ?? 0,
                      lastFetch: _formatLastFetch(_cacheStats['reportingPoints']?['lastFetch']),
                      onClear: () => _clearSpecificCache('Reporting Points'),
                      subtitle: 'VFR reporting points for navigation',
                      onRefresh: _openAIPApiKey.isNotEmpty ? _refreshReportingPoints : null,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Weather cache
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.cloud, size: 24, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Weather Data',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.blue),
                                  onPressed: _isRefreshing ? null : () => _refreshWeatherData(),
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
                              'METAR and TAF weather reports',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'METARs: ${_cacheStats['weather']?['metars'] ?? 0}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  'TAFs: ${_cacheStats['weather']?['tafs'] ?? 0}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Updated: ${_formatLastFetch(_cacheStats['weather']?['lastFetch'])}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    
                    // OpenAIP API Configuration
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.key, size: 24, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'OpenAIP Configuration',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your OpenAIP API key to fetch airspaces data',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _apiKeyController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'API Key',
                                hintText: 'Enter your OpenAIP API key',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                // Auto-save when user types
                                _saveApiKey(value.trim());
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Get your API key from openaip.net',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_openAIPApiKey.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  // Test the API key by fetching some airspaces
                                  try {
                                    final airspaces = await _openAIPService.fetchAirspaces(limit: 1);
                                    if (!mounted) return;
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(airspaces.isNotEmpty 
                                            ? 'API key is valid and working!' 
                                            : 'API key seems valid but no airspaces found'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('API key validation failed. Please check your key.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check_circle, size: 16),
                                label: const Text('Test API Key'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // Map Tiles Section
                    const Text(
                      'Offline Map Tiles',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Map cache statistics
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.map, size: 24, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Map Tile Cache',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _clearSpecificCache('Map tiles'),
                                  tooltip: 'Clear cache',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_mapCacheStats != null) ...[
                              Text('Total Tiles: ${_mapCacheStats!['totalTiles']}'),
                              Text('Total Size: ${_mapCacheStats!['totalSizeMB']} MB'),
                              const SizedBox(height: 8),
                              const Text('Zoom Levels:'),
                              ...(_mapCacheStats!['zoomLevels'] as List).map(
                                (level) => Text(
                                  '  Level ${level['z']}: ${level['count']} tiles',
                                ),
                              ),
                            ] else
                              const Text('No cached tiles'),
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
                              Text('Progress: $_currentTiles / $_totalTiles tiles'),
                              const SizedBox(height: 4),
                              Text(
                                'Downloaded: $_downloadedTiles | Skipped (cached): $_skippedTiles',
                                style: const TextStyle(fontSize: 13),
                              ),
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
                              'Download Map Tiles',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Download tiles for current map area'),
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
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isDownloading ? null : _downloadCurrentArea,
                                child: const Text('Download Current Area'),
                              ),
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
                              'Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• All aviation data is cached for offline use\n'
                              '• Weather data is updated every 30 minutes when online\n'
                              '• Map tiles are cached automatically when viewed\n'
                              '• Download map areas before flights for offline navigation\n'
                              '• Use "Refresh all data" to update all caches from the internet',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }
}