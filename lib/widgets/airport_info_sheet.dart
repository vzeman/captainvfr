import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/airport.dart';
import '../services/weather_service.dart';

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
  String? _weatherError;
  bool _weatherTabInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index == 1 && !_weatherTabInitialized) {
      _fetchWeather();
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
    final runways = widget.airport.runwaysList;
    final frequencies = widget.airport.frequenciesList;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Section
          _buildSectionHeader('Airport Information', icon: Icons.info_outline),
          _buildInfoRow(context, 'Name', widget.airport.name),
          if (widget.airport.municipality != null)
            _buildInfoRow(context, 'Location', widget.airport.municipality!),
          _buildInfoRow(context, 'Country', widget.airport.country),
          if (widget.airport.region != null)
            _buildInfoRow(context, 'Region', widget.airport.region!),
          _buildInfoRow(context, 'Type', widget.airport.typeDisplay ?? 'Unknown'),
          _buildInfoRow(context, 'Elevation', '${widget.airport.elevation} ft MSL'),
          
          // Coordinates
          _buildInfoRow(
            context, 
            'Coordinates', 
            '${widget.airport.latitude.toStringAsFixed(4)}°N, ${widget.airport.longitude.toStringAsFixed(4)}°E'
          ),
          
          // Runways Section
          if (runways.isNotEmpty) ...[
            _buildSectionHeader('Runways', icon: Icons.run_circle_outlined),
            ...runways.map((r) => _buildRunwayInfo(r)).toList(),
          ],
          
          // Frequencies Section
          if (frequencies.isNotEmpty) ...[
            _buildSectionHeader('Frequencies', icon: Icons.radio),
            ...frequencies.map((f) => _buildFrequencyInfo(f)).toList(),
          ],
          
          // Action Buttons
          if (widget.airport.website != null || widget.airport.phone != null) ...[
            _buildSectionHeader('Actions', icon: Icons.quick_contacts_dialer),
            if (widget.airport.phone != null) ...[
              _buildActionButton(
                context: context,
                icon: Icons.phone,
                label: 'Call ${widget.airport.phone}',
                onPressed: () => _launchUrl(context, 'tel:${widget.airport.phone}'),
              ),
            ],
            if (widget.airport.website != null) ...[
              _buildActionButton(
                context: context,
                icon: Icons.language,
                label: 'Visit Website',
                onPressed: () => _launchUrl(context, widget.airport.website!),
              ),
            ],
          ],
          
          // Navigation button
          if (widget.onNavigate != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onNavigate,
                icon: const Icon(Icons.navigation, size: 20),
                label: const Text('Navigate to Airport'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(51),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.flight_takeoff,
                  color: theme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.airport.icao} - ${widget.airport.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.airport.iata != null || widget.airport.icaoCode != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (widget.airport.icaoCode != null) 'ICAO: ${widget.airport.icaoCode}',
                            if (widget.airport.iata != null) 'IATA: ${widget.airport.iata}',
                          ].join(' • '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.hintColor,
            indicatorColor: theme.primaryColor,
            tabs: const [
              Tab(icon: Icon(Icons.info_outline), text: 'Info'),
              Tab(icon: Icon(Icons.cloud), text: 'Weather'),
            ],
          ),
          
          // Tab Bar View
          SizedBox(
            height: 300, // Fixed height for the tab content
            child: TabBarView(
              controller: _tabController,
              children: [
                // Info Tab
                _buildInfoTab(),
                
                // Weather Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildWeatherSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build a weather information row with icon and text
  Widget _buildWeatherInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, size: 16, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black, // Default text color
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // Build the weather section of the info sheet
  Widget _buildWeatherSection() {
    final airport = widget.airport;
    final weatherService = widget.weatherService;

    return FutureBuilder<Map<String, String?>>(
      future: _loadWeatherData(weatherService, airport.icao),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final lastFetch = weatherService.lastFetch;

        Map<String, String?>? weatherData;
        if (snapshot.hasData) {
          weatherData = snapshot.data;
        }

        final metar = weatherData?['metar'];
        final taf = weatherData?['taf'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Weather Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: !isLoading
                      ? () async {
                          await weatherService.forceReload();
                          setState(() {});
                        }
                      : null,
                  tooltip: 'Reload weather data',
                  iconSize: 20,
                ),
                if (isLoading) const SizedBox(width: 16),
                if (isLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            if (metar != null && metar.isNotEmpty)
              _buildWeatherInfoRow(Icons.cloud, 'METAR', metar)
            else if (isLoading)
              const Text('Loading weather...')
            else
              Text('No METAR data available for ${airport.icao}'),
            if (taf != null && taf.isNotEmpty)
              _buildWeatherInfoRow(Icons.description, 'TAF', taf)
            else if (!isLoading && metar != null)
              Text('No TAF data available for ${airport.icao}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (lastFetch != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Last update: '
                    '${lastFetch.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            // Debug info
            if (!isLoading && metar == null && taf == null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Debug: Searching for ICAO: ${airport.icao}',
                      style: const TextStyle(fontSize: 10, color: Colors.orange)),
                    FutureBuilder<String>(
                      future: _getDebugInfo(weatherService),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(snapshot.data!,
                            style: const TextStyle(fontSize: 10, color: Colors.orange));
                        }
                        return const Text('Loading debug info...',
                          style: TextStyle(fontSize: 10, color: Colors.orange));
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // Helper method to load weather data
  Future<Map<String, String?>> _loadWeatherData(WeatherService weatherService, String icao) async {
    final metar = await weatherService.getMetar(icao);
    final taf = await weatherService.getTaf(icao);
    return {
      'metar': metar,
      'taf': taf,
    };
  }

  // Helper method to get debug information
  Future<String> _getDebugInfo(WeatherService weatherService) async {
    // Try to get a sample of cached data to see what's available
    final metar = await weatherService.getMetar('KJFK'); // Try a well-known airport
    final taf = await weatherService.getTaf('KJFK');

    return 'Sample KJFK - METAR: ${metar != null ? 'Found' : 'Not found'}, TAF: ${taf != null ? 'Found' : 'Not found'}';
  }

  // Helper to get color for flight category
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'VFR':
        return Colors.green;
      case 'MVFR':
        return Colors.blue;
      case 'IFR':
        return Colors.red;
      case 'LIFR':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Build a section header
  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Build a runway information card
  Widget _buildRunwayInfo(Map<String, dynamic> runway) {
    final length = runway['length_ft']?.toString() ?? 'Unknown';
    final width = runway['width_ft']?.toString() ?? 'Unknown';
    final surface = runway['surface']?.toString().replaceAll('_', ' ').toLowerCase() ?? 'Unknown';
    final leIdent = runway['le_ident']?.toString() ?? '';
    final heIdent = runway['he_ident']?.toString() ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$leIdent / $heIdent',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('$length x $width ft'),
              ],
            ),
            const SizedBox(height: 4),
            Text('Surface: $surface'),
          ],
        ),
      ),
    );
  }

  // Build a frequency information row
  Widget _buildFrequencyInfo(Map<String, dynamic> freq) {
    final type = freq['type']?.toString() ?? 'Unknown';
    final mhz = double.tryParse(freq['frequency_mhz']?.toString() ?? '') ?? 0.0;
    final description = freq['description']?.toString() ?? '';
    
    // Format frequency to 3 decimal places with leading zeros
    final freqStr = mhz.toStringAsFixed(3).padLeft(7, '0');
    
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 80,
        alignment: Alignment.centerLeft,
        child: Text(
          type,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text('$freqStr MHz'),
      subtitle: description.isNotEmpty ? Text(description) : null,
    );
  }
}
