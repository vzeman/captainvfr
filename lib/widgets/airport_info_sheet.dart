import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/airport.dart';
import '../models/runway.dart';
import '../services/weather_service.dart';
import '../services/runway_service.dart';

// Key for testing
const Key kAirportInfoSheetKey = Key('airport_info_sheet');

class AirportInfoSheet extends StatefulWidget {
  final Airport airport;
  final VoidCallback onClose;
  final VoidCallback? onNavigate;
  final WeatherService weatherService;

  const AirportInfoSheet({
    super.key,
    required this.airport,
    required this.onClose,
    this.onNavigate,
    required this.weatherService,
  });

  @override
  State<AirportInfoSheet> createState() => _AirportInfoSheetState();
}

class _AirportInfoSheetState extends State<AirportInfoSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingWeather = false;
  bool _isLoadingRunways = false;
  String? _weatherError;
  String? _runwaysError;
  bool _weatherTabInitialized = false;
  bool _runwaysTabInitialized = false;
  List<Runway> _runways = [];
  final RunwayService _runwayService = RunwayService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initializeRunwayService();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeRunwayService() async {
    await _runwayService.initialize();
    await _runwayService.fetchRunways();
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && !_weatherTabInitialized) {
      _fetchWeather();
    } else if (_tabController.index == 2 && !_runwaysTabInitialized) {
      _fetchRunways();
    }
  }

  Future<void> _fetchWeather() async {
    if (widget.airport.rawMetar != null || _isLoadingWeather) return;

    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
      _weatherTabInitialized = true;
    });

    try {
      final metar = await widget.weatherService.fetchMetar(widget.airport.icao);
      final taf = await widget.weatherService.fetchTaf(widget.airport.icao);
      
      if (mounted) {
        setState(() {
          if (metar != null) {
            widget.airport.updateWeather(metar);
          }
          if (taf != null) {
            widget.airport.taf = taf;
            widget.airport.lastWeatherUpdate = DateTime.now().toUtc();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = 'Failed to load weather data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  Future<void> _fetchRunways() async {
    if (_runwaysTabInitialized) return;

    setState(() {
      _isLoadingRunways = true;
      _runwaysError = null;
      _runwaysTabInitialized = true;
    });

    try {
      final runways = _runwayService.getRunwaysForAirport(widget.airport.icao);

      if (mounted) {
        setState(() {
          _runways = runways;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _runwaysError = 'Failed to load runway data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRunways = false;
        });
      }
    }
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide(
            color: theme.colorScheme.outline.withAlpha(102), // 40% opacity
          ),
        ),
      ),
    );
  }

  /// Launches a URL in the default browser or phone app
  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = _parseUrl(url);
      
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      }
    } on FormatException {
      log('Invalid URL format: $url');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL format')),
        );
      }
    } catch (e) {
      log('Could not launch $url', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  /// Parses a URL string into a Uri object, handling various URL formats
  Uri _parseUrl(String url) {
    if (url.startsWith('http://') || 
        url.startsWith('https://') || 
        url.startsWith('tel:')) {
      return Uri.parse(url);
    } else if (url.startsWith('www.')) {
      return Uri.https(url.substring(4));
    } else if (url.contains('@')) {
      return Uri(scheme: 'mailto', path: url);
    } else {
      // Default to https if no scheme is provided
      return Uri.https(url);
    }
  }

  // Build the airport information tab content
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information
          _buildInfoRow(context, 'ICAO', widget.airport.icao),
          if (widget.airport.iata != null && widget.airport.iata!.isNotEmpty)
            _buildInfoRow(context, 'IATA', widget.airport.iata!),
          _buildInfoRow(context, 'Name', widget.airport.name),
          _buildInfoRow(context, 'City', widget.airport.city),
          _buildInfoRow(context, 'Country', widget.airport.country),
          _buildInfoRow(context, 'Type', widget.airport.type.replaceAll('_', ' ').toUpperCase()),
          _buildInfoRow(context, 'Elevation', '${widget.airport.elevation} ft'),
          _buildInfoRow(context, 'Coordinates',
            '${widget.airport.position.latitude.toStringAsFixed(6)}, ${widget.airport.position.longitude.toStringAsFixed(6)}'),

          const SizedBox(height: 16),

          // Action Buttons
          if (widget.airport.website != null && widget.airport.website!.isNotEmpty)
            _buildActionButton(
              context: context,
              icon: Icons.language,
              label: 'Visit Website',
              onPressed: () => _launchUrl(context, widget.airport.website!),
            ),

          if (widget.airport.phone != null && widget.airport.phone!.isNotEmpty)
            _buildActionButton(
              context: context,
              icon: Icons.phone,
              label: 'Call ${widget.airport.phone}',
              onPressed: () => _launchUrl(context, 'tel:${widget.airport.phone}'),
            ),

          if (widget.onNavigate != null)
            _buildActionButton(
              context: context,
              icon: Icons.navigation,
              label: 'Navigate to Airport',
              onPressed: widget.onNavigate!,
            ),
        ],
      ),
    );
  }

  // Build the runways tab content
  Widget _buildRunwaysTab() {
    if (_isLoadingRunways) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading runway data...'),
            ],
          ),
        ),
      );
    }

    if (_runwaysError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                _runwaysError!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _runwaysTabInitialized = false;
                  });
                  _fetchRunways();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_runways.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.airplanemode_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No runway data available for this airport',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Runway Summary
          _buildRunwaySummary(),
          const SizedBox(height: 16),

          // Individual Runways
          Text(
            'Runways (${_runways.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          ..._runways.map((runway) => _buildRunwayCard(runway)),
        ],
      ),
    );
  }

  Widget _buildRunwaySummary() {
    final stats = _runwayService.getAirportRunwayStats(widget.airport.icao);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Runway Summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Count', '${stats.count}', Icons.straighten),
                ),
                Expanded(
                  child: _buildStatItem('Longest', stats.longestFormatted, Icons.trending_up),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Lighted', stats.hasLightedRunways ? 'Yes' : 'No',
                    stats.hasLightedRunways ? Icons.lightbulb : Icons.lightbulb_outline),
                ),
                Expanded(
                  child: _buildStatItem('Hard Surface', stats.hasHardSurface ? 'Yes' : 'No',
                    stats.hasHardSurface ? Icons.check_circle : Icons.circle_outlined),
                ),
              ],
            ),
            if (stats.surfaces.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Surfaces', stats.surfacesFormatted),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.hintColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRunwayCard(Runway runway) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Runway designation and basic info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(51), // 20% opacity
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    runway.designation,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (runway.lighted)
                  Icon(Icons.lightbulb, size: 16, color: Colors.yellow[700]),
                if (runway.closed)
                  Icon(Icons.block, size: 16, color: Colors.red[700]),
              ],
            ),
            const SizedBox(height: 8),

            // Runway details
            Row(
              children: [
                Expanded(
                  child: _buildRunwayDetail('Length', runway.lengthFormatted),
                ),
                if (runway.widthFt != null)
                  Expanded(
                    child: _buildRunwayDetail('Width', '${runway.widthFt} ft'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _buildRunwayDetail('Surface', runway.surfaceFormatted),
                ),
                if (runway.leHeadingDegT != null || runway.heHeadingDegT != null)
                  Expanded(
                    child: _buildRunwayDetail('Heading',
                      '${runway.leHeadingDegT?.toStringAsFixed(0) ?? 'N/A'}°/${runway.heHeadingDegT?.toStringAsFixed(0) ?? 'N/A'}°'),
                  ),
              ],
            ),

            // Status indicators
            if (runway.closed || runway.lighted) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (runway.lighted)
                    _buildStatusChip('Lighted', Colors.yellow[700]!),
                  if (runway.closed)
                    _buildStatusChip('Closed', Colors.red[700]!),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRunwayDetail(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(51), // 20% opacity
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  // Build the weather tab content (existing weather implementation)
  Widget _buildWeatherTab() {
    if (_isLoadingWeather) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading weather data...'),
            ],
          ),
        ),
      );
    }

    if (_weatherError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                _weatherError!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _weatherTabInitialized = false;
                  });
                  _fetchWeather();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Display weather data if available
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // METAR Section
          if (widget.airport.rawMetar != null) ...[
            Text(
              'METAR',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Text(
                widget.airport.rawMetar!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // TAF Section
          if (widget.airport.taf != null) ...[
            Text(
              'TAF',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Text(
                widget.airport.taf!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Last updated info
          if (widget.airport.lastWeatherUpdate != null) ...[
            Text(
              'Last Updated',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.airport.lastWeatherUpdate!.toLocal().toString().substring(0, 19)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // No weather data message
          if (widget.airport.rawMetar == null && widget.airport.taf == null) ...[
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No weather data available for ${widget.airport.icao}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _weatherTabInitialized = false;
                      });
                      _fetchWeather();
                    },
                    child: const Text('Refresh Weather'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      key: kAirportInfoSheetKey,
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13), // 5% opacity
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.airport.icao,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.airport.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Info', icon: Icon(Icons.info_outline)),
              Tab(text: 'Weather', icon: Icon(Icons.cloud_outlined)),
              Tab(text: 'Runways', icon: Icon(Icons.straighten)),
            ],
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildWeatherTab(),
                _buildRunwaysTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
