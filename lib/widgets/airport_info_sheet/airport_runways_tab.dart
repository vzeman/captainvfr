import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/airport.dart';
import '../../models/runway.dart';
import '../../models/unified_runway.dart';
import '../../services/runway_service.dart';
import '../../services/settings_service.dart';
import '../../services/weather_service.dart';
import '../../utils/runway_wind_calculator.dart';
import '../common/loading_widget.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_colors.dart';
import '../common/error_widget.dart' as custom;
import '../common/status_chip.dart';

class AirportRunwaysTab extends StatefulWidget {
  final Airport airport;
  final bool isLoading;
  final String? error;
  final List<Runway> runways;
  final VoidCallback onRetry;
  final RunwayService runwayService;
  final WeatherService weatherService;

  const AirportRunwaysTab({
    super.key,
    required this.airport,
    required this.isLoading,
    this.error,
    required this.runways,
    required this.onRetry,
    required this.runwayService,
    required this.weatherService,
  });

  @override
  State<AirportRunwaysTab> createState() => _AirportRunwaysTabState();
}

class _AirportRunwaysTabState extends State<AirportRunwaysTab> {
  Map<String, double>? _windData;
  List<WindComponents>? _windComponents;
  String? _bestRunway;
  bool _isLoadingWind = true;
  String? _lastProcessedMetar;
  List<UnifiedRunway>? _unifiedRunways;
  bool _hasAttemptedWindFetch = false;
  int _windFetchAttempts = 0;
  Timer? _windDataCheckTimer;

  @override
  void initState() {
    super.initState();
    _fetchWindData();
    _fetchUnifiedRunways();
  }

  @override
  void dispose() {
    _windDataCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(AirportRunwaysTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset attempt counter if airport changed
    if (oldWidget.airport.icao != widget.airport.icao) {
      _windFetchAttempts = 0;
      _hasAttemptedWindFetch = false;
      _windData = null;
      _lastProcessedMetar = null;
    }
    
    // Schedule state updates after the current build cycle to avoid buildScope issues
    // Use a debounced approach to prevent rapid successive calls
    _windDataCheckTimer?.cancel();
    _windDataCheckTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _checkAndRefetchWindData();
      }
    });
  }

  void _checkAndRefetchWindData() {
    // Don't proceed if widget is being disposed or not mounted
    if (!mounted) return;
    
    // Check if we have new METAR data that we haven't processed yet
    final currentMetar = widget.airport.rawMetar;
    if (currentMetar != null && 
        currentMetar.isNotEmpty && 
        currentMetar != _lastProcessedMetar) {
      debugPrint('New METAR data detected, refetching wind data');
      _fetchWindData();
    } else if (_windData == null && !_isLoadingWind && !_hasAttemptedWindFetch) {
      // If we don't have wind data and aren't loading, try to fetch ONCE
      debugPrint('No wind data present, attempting to fetch (one time only)');
      _fetchWindData();
    }
  }
  
  Future<void> _fetchUnifiedRunways() async {
    try {
      // Get OpenAIP runways from the airport object
      final openAIPRunways = widget.airport.openAIPRunways;
      
      if (widget.airport.icao == 'LZDV') {
        debugPrint('LZDV: Fetching unified runways');
        debugPrint('LZDV: OpenAIP runways from airport: ${openAIPRunways.length}');
      }
      
      _unifiedRunways = widget.runwayService.getUnifiedRunwaysForAirport(
        widget.airport.icao,
        openAIPRunways: openAIPRunways.isNotEmpty ? openAIPRunways : null,
        airportLat: widget.airport.position.latitude,
        airportLon: widget.airport.position.longitude,
      );
      
      if (widget.airport.icao == 'LZDV' && _unifiedRunways != null) {
        debugPrint('LZDV: Got ${_unifiedRunways!.length} unified runways');
      }
    } catch (e) {
      if (widget.airport.icao == 'LZDV') {
        debugPrint('LZDV: Error fetching unified runways: $e');
      }
    }
  }

  Future<void> _fetchWindData() async {
    if (!mounted) return;
    
    // Prevent excessive retries
    if (_windFetchAttempts >= 2) {
      debugPrint('Maximum wind fetch attempts reached, stopping');
      setState(() {
        _isLoadingWind = false;
        _hasAttemptedWindFetch = true;
      });
      return;
    }
    
    _windFetchAttempts++;
    debugPrint('Wind fetch attempt $_windFetchAttempts');
    
    setState(() {
      _isLoadingWind = true;
      _hasAttemptedWindFetch = true;
    });
    
    try {
      String? metar;
      
      // First check if the airport already has METAR data (from weather tab)
      if (widget.airport.rawMetar != null && widget.airport.rawMetar!.isNotEmpty) {
        metar = widget.airport.rawMetar;
        debugPrint('Using existing METAR from airport data');
      } else {
        // If not, fetch it ourselves
        metar = await widget.weatherService.getMetar(widget.airport.icao);
        debugPrint('Fetched new METAR data: ${metar != null ? 'success' : 'null'}');
        
        // If still no data, stop trying
        if (metar == null || metar.isEmpty) {
          debugPrint('No METAR data available for ${widget.airport.icao}');
        }
      }
      
      if (metar != null && metar.isNotEmpty) {
        // Extract wind data from METAR
        final windMatch = RegExp(r'(\d{3}|VRB)(\d{2,3})(G\d{2,3})?KT').firstMatch(metar);
        if (windMatch != null) {
          final windString = windMatch.group(0)!;
          final windData = RunwayWindCalculator.parseMetarWind(windString);
          
          if (windData != null && windData['direction'] != -1 && widget.runways.isNotEmpty) {
            if (mounted) {
              setState(() {
                _windData = windData;
                _windComponents = RunwayWindCalculator.calculateWindComponentsForRunways(
                  widget.runways,
                  windData['direction']!,
                  windData['gust'] ?? windData['speed']!, // Use gust speed if available
                );
                _bestRunway = _windComponents?.first.runwayDesignation;
                _isLoadingWind = false;
                _lastProcessedMetar = metar; // Track the processed METAR
              });
            }
            return;
          }
        }
      }
      
      // No wind data available
      if (mounted) {
        setState(() {
          _isLoadingWind = false;
        });
      }
    } catch (e) {
      // Silently fail - wind data is optional enhancement
      debugPrint('Failed to fetch wind data: $e');
      if (mounted) {
        setState(() {
          _isLoadingWind = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const LoadingWidget(message: 'Loading runway data...');
    }

    if (widget.error != null) {
      return custom.ErrorWidget(error: widget.error!, onRetry: widget.onRetry);
    }

    // Check both OurAirports runways and unified runways
    final hasOurAirportsRunways = widget.runways.isNotEmpty;
    final hasUnifiedRunways = _unifiedRunways != null && _unifiedRunways!.isNotEmpty;
    
    if (!hasOurAirportsRunways && !hasUnifiedRunways) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.airplanemode_off, size: 48, color: AppColors.secondaryTextColor),
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
          // Wind Information (if available or loading)
          if (_isLoadingWind) ...[
            _buildWindLoadingIndicator(context),
            const SizedBox(height: 16),
          ],

          // Individual Runways
          Row(
            children: [
              Text(
                'Runways (${widget.runways.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show OurAirports runways if available
          if (widget.runways.isNotEmpty)
            ...widget.runways.map((runway) => RunwayCard(
              runway: runway,
              windComponents: _getWindComponentsForRunway(runway),
              isBestRunway: _isBestRunway(runway),
              windData: _windData,
            ))
          // Otherwise show unified runways (OpenAIP data)
          else if (_unifiedRunways != null && _unifiedRunways!.isNotEmpty)
            ..._unifiedRunways!.map((unifiedRunway) => UnifiedRunwayCard(
              runway: unifiedRunway,
              windComponents: _getWindComponentsForUnifiedRunway(unifiedRunway),
              isBestRunway: _isBestUnifiedRunway(unifiedRunway),
              windData: _windData,
            )),
        ],
      ),
    );
  }

  List<WindComponents>? _getWindComponentsForRunway(Runway runway) {
    if (_windComponents == null) return null;
    
    return _windComponents!.where((component) {
      // Match by runway designation
      final runwayDesignations = runway.designation.split('/');
      return runwayDesignations.contains(component.runwayDesignation);
    }).toList();
  }
  
  bool _isBestRunway(Runway runway) {
    if (_bestRunway == null) return false;
    
    final runwayDesignations = runway.designation.split('/');
    return runwayDesignations.contains(_bestRunway);
  }
  
  List<WindComponents>? _getWindComponentsForUnifiedRunway(UnifiedRunway runway) {
    if (_windComponents == null) return null;
    
    return _windComponents!.where((component) {
      // Match by runway designation
      return component.runwayDesignation == runway.leIdent || 
             component.runwayDesignation == runway.heIdent;
    }).toList();
  }
  
  bool _isBestUnifiedRunway(UnifiedRunway runway) {
    if (_bestRunway == null) return false;
    
    return runway.leIdent == _bestRunway || runway.heIdent == _bestRunway;
  }
  
  
  Widget _buildWindLoadingIndicator(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      color: AppColors.sectionBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading wind data...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }


}

class RunwayCard extends StatelessWidget {
  final Runway runway;
  final List<WindComponents>? windComponents;
  final bool isBestRunway;
  final Map<String, double>? windData;

  const RunwayCard({
    super.key,
    required this.runway,
    this.windComponents,
    this.isBestRunway = false,
    this.windData,
  });
  
  static Color _getCrosswindColor(double crosswind) {
    const double crosswindCautionThreshold = 5.0; // knots
    const double crosswindDangerThreshold = 10.0; // knots
    
    if (crosswind > crosswindDangerThreshold) {
      return Colors.red;
    } else if (crosswind > crosswindCautionThreshold) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';

        // Format length based on units
        final lengthStr = isMetric
            ? '${runway.lengthM.toStringAsFixed(0)} m'
            : runway.lengthFormatted;

        // Format width based on units
        final widthStr = runway.widthFt != null
            ? isMetric
                  ? '${runway.widthM!.toStringAsFixed(0)} m'
                  : '${runway.widthFt} ft'
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isBestRunway ? AppColors.primaryAccent.withValues(alpha: 0.2) : AppColors.sectionBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row - designation with visualization in top right
                Row(
                  children: [
                    // Left side - runway designation and basic info
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isBestRunway 
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.3), // 30% opacity
                              borderRadius: AppTheme.smallRadius,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isBestRunway) ...[
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  runway.designation,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isBestRunway 
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isBestRunway)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: AppTheme.extraLargeRadius,
                              ),
                              child: const Text(
                                'BEST',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (runway.lighted)
                            Icon(
                              Icons.lightbulb,
                              size: 16,
                              color: Colors.yellow[700],
                            ),
                          if (runway.closed)
                            Icon(Icons.block, size: 16, color: Colors.red[700]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Runway details
                Row(
                  children: [
                    Expanded(
                      child: _buildRunwayDetail(context, 'Length', lengthStr),
                    ),
                    if (widthStr != null)
                      Expanded(
                        child: _buildRunwayDetail(context, 'Width', widthStr),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildRunwayDetail(
                        context,
                        'Surface',
                        runway.surfaceFormatted,
                      ),
                    ),
                    if (runway.leHeadingDegT != null ||
                        runway.heHeadingDegT != null)
                      Expanded(
                        child: _buildRunwayDetail(
                          context,
                          'Heading',
                          '${runway.leHeadingDegT?.toStringAsFixed(0) ?? 'N/A'}°/${runway.heHeadingDegT?.toStringAsFixed(0) ?? 'N/A'}°',
                        ),
                      ),
                  ],
                ),

                // Wind Components (if available)
                if (windComponents != null && windComponents!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Wind Components',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Visualization + Wind Speed
                      Row(
                        children: [
                          // Runway visualization
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: _buildRunwayVisualization(context, runway),
                          ),
                          const SizedBox(width: 16),
                          // Wind speed from METAR
                          if (windData != null) ...[
                            Text(
                              '${windData!['direction']?.toInt() ?? 0}°${windData!['speed']?.toInt() ?? 0}${windData!['gust'] != null ? 'G${windData!['gust']?.toInt()}' : ''}kt',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Row 2: Wind components per runway
                      ...windComponents!.map((component) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              'RW ${component.runwayDesignation}:',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTextColor,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${component.headwindAbs.toStringAsFixed(0)} ${component.isHeadwind ? "Headwind" : "Tailwind"}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: component.isHeadwind ? Colors.green : Colors.orange,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${component.crosswind.toStringAsFixed(0)} Crosswind',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _getCrosswindColor(component.crosswind),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ],

                // Status indicators
                if (runway.closed || runway.lighted) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (runway.lighted)
                        StatusChip(
                          label: 'Lighted',
                          color: Colors.yellow[700]!,
                        ),
                      if (runway.closed)
                        StatusChip(label: 'Closed', color: Colors.red[700]!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRunwayDetail(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondaryTextColor),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRunwayVisualization(BuildContext context, Runway runway) {
    return CustomPaint(
      size: const Size(60, 80),
      painter: _CompactRunwayPainter(
        leHeading: runway.leHeadingDegT,
        heHeading: runway.heHeadingDegT,
        windData: windData,
        leDesignation: runway.designation.split('/').first,
        heDesignation: runway.designation.split('/').last,
      ),
    );
  }
}

/// Card widget for unified runway data (supports OpenAIP runways)
class UnifiedRunwayCard extends StatelessWidget {
  final UnifiedRunway runway;
  final List<WindComponents>? windComponents;
  final bool isBestRunway;
  final Map<String, double>? windData;

  const UnifiedRunwayCard({
    super.key,
    required this.runway,
    this.windComponents,
    this.isBestRunway = false,
    this.windData,
  });

  static Color _getCrosswindColor(double crosswind) {
    const double crosswindCautionThreshold = 5.0; // knots
    const double crosswindDangerThreshold = 10.0; // knots
    
    if (crosswind > crosswindDangerThreshold) {
      return Colors.red;
    } else if (crosswind > crosswindCautionThreshold) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';

        // Format length based on units
        final lengthStr = isMetric
            ? '${(runway.lengthFt / 3.28084).toStringAsFixed(0)} m'
            : '${runway.lengthFt} ft';

        // Format width based on units
        final widthStr = runway.widthFt != null
            ? isMetric
                  ? '${(runway.widthFt! / 3.28084).toStringAsFixed(0)} m'
                  : '${runway.widthFt} ft'
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isBestRunway ? AppColors.primaryAccent.withValues(alpha: 0.2) : AppColors.sectionBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row - designation with visualization in top right
                Row(
                  children: [
                    // Left side - runway designation and basic info
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isBestRunway 
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.3),
                              borderRadius: AppTheme.smallRadius,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isBestRunway) ...[
                                  Icon(
                                    Icons.star,
                                    size: 14,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  runway.designation,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isBestRunway 
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Data source indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: AppTheme.smallRadius,
                            ),
                            child: Text(
                              runway.dataSource.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          if (isBestRunway) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: AppTheme.extraLargeRadius,
                              ),
                              child: const Text(
                                'BEST',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          if (runway.lighted)
                            Icon(
                              Icons.lightbulb,
                              size: 14,
                              color: Colors.yellow[700],
                            ),
                          if (runway.closed)
                            Icon(Icons.block, size: 14, color: Colors.red[700]),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Runway details
                Row(
                  children: [
                    Expanded(
                      child: _buildRunwayDetail(context, 'Length', lengthStr),
                    ),
                    if (widthStr != null)
                      Expanded(
                        child: _buildRunwayDetail(context, 'Width', widthStr),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildRunwayDetail(
                        context,
                        'Surface',
                        runway.surfaceDescription,
                      ),
                    ),
                    if (runway.leHeadingDegT != null ||
                        runway.heHeadingDegT != null)
                      Expanded(
                        child: _buildRunwayDetail(
                          context,
                          'Heading',
                          '${runway.leHeadingDegT?.toStringAsFixed(0) ?? 'N/A'}°/${runway.heHeadingDegT?.toStringAsFixed(0) ?? 'N/A'}°',
                        ),
                      ),
                  ],
                ),

                // Wind Components (if available)
                if (windComponents != null && windComponents!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Wind Components',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Visualization + Wind Speed
                      Row(
                        children: [
                          // Runway visualization
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: _buildUnifiedRunwayVisualization(context, runway),
                          ),
                          const SizedBox(width: 16),
                          // Wind speed from METAR
                          if (windData != null) ...[
                            Text(
                              '${windData!['direction']?.toInt() ?? 0}°${windData!['speed']?.toInt() ?? 0}${windData!['gust'] != null ? 'G${windData!['gust']?.toInt()}' : ''}kt',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Row 2: Wind components per runway
                      ...windComponents!.map((component) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              'RW ${component.runwayDesignation}:',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTextColor,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${component.headwindAbs.toStringAsFixed(0)} ${component.isHeadwind ? "Headwind" : "Tailwind"}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: component.isHeadwind ? Colors.green : Colors.orange,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${component.crosswind.toStringAsFixed(0)} Crosswind',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _getCrosswindColor(component.crosswind),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ],

                // Status indicators
                if (runway.closed || runway.lighted) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (runway.lighted)
                        StatusChip(
                          label: 'Lighted',
                          color: Colors.yellow[700]!,
                        ),
                      if (runway.closed)
                        StatusChip(label: 'Closed', color: Colors.red[700]!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRunwayDetail(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondaryTextColor),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedRunwayVisualization(BuildContext context, UnifiedRunway runway) {
    return CustomPaint(
      size: const Size(60, 80),
      painter: _CompactRunwayPainter(
        leHeading: runway.leHeadingDegT,
        heHeading: runway.heHeadingDegT,
        windData: windData,
        leDesignation: runway.leIdent,
        heDesignation: runway.heIdent,
      ),
    );
  }
}

/// Compact custom painter for drawing runway and wind indicators in a small space
class _CompactRunwayPainter extends CustomPainter {
  final double? leHeading;
  final double? heHeading;
  final Map<String, double>? windData;
  final String leDesignation;
  final String heDesignation;

  _CompactRunwayPainter({
    this.leHeading,
    this.heHeading,
    this.windData,
    required this.leDesignation,
    required this.heDesignation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 5); // Move center down slightly
    
    // Use available heading (prefer LE, fallback to HE)
    double? heading = leHeading ?? heHeading;
    if (heading == null) {
      // Draw placeholder circle if no heading data (smaller)
      final placeholderPaint = Paint()
        ..color = Colors.grey[600]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      
      canvas.drawCircle(center, 10, placeholderPaint);
      
      // Draw "N/A" text
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'N/A',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ));
      return;
    }

    // Convert heading to radians
    final angle = (heading - 90) * math.pi / 180; // -90 to align with visual orientation
    
    // Draw background circle (smaller - half size: 11px radius)
    final backgroundPaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 11, backgroundPaint);
    
    // Draw border circle
    final borderPaint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawCircle(center, 11, borderPaint);
    
    // Calculate runway endpoints - make runway line bigger relative to circle
    final runwayLength = 18.0; // Fits better in smaller circle
    final halfLength = runwayLength / 2;
    final startPoint = Offset(
      center.dx - halfLength * math.cos(angle),
      center.dy - halfLength * math.sin(angle),
    );
    final endPoint = Offset(
      center.dx + halfLength * math.cos(angle),
      center.dy + halfLength * math.sin(angle),
    );

    // Draw runway as thick black line (wider for better visibility)
    final runwayPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6 // Much thicker line for better visibility
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(startPoint, endPoint, runwayPaint);
    
    // Draw runway center line
    final centerLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(startPoint, endPoint, centerLinePaint);

    // Draw runway designations at the ends, positioned away from the runway line
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    // Calculate extended positions for runway labels (further from runway line to avoid wind arrow overlap)
    final extendedLength = runwayLength / 2 + 15; // 15 pixels beyond runway ends to avoid wind arrow
    final leExtendedPoint = Offset(
      center.dx - extendedLength * math.cos(angle),
      center.dy - extendedLength * math.sin(angle),
    );
    final heExtendedPoint = Offset(
      center.dx + extendedLength * math.cos(angle),
      center.dy + extendedLength * math.sin(angle),
    );

    // LE designation (start of runway)
    textPainter.text = TextSpan(
      text: leDesignation,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    final leTextOffset = Offset(
      leExtendedPoint.dx - textPainter.width / 2,
      leExtendedPoint.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, leTextOffset);

    // HE designation (end of runway)
    textPainter.text = TextSpan(
      text: heDesignation,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    final heTextOffset = Offset(
      heExtendedPoint.dx - textPainter.width / 2,
      heExtendedPoint.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, heTextOffset);

    // Draw wind arrow if wind data is available - through the middle of runway
    if (windData != null && windData!['direction'] != null) {
      final windDirection = windData!['direction']!;
      final windAngle = (windDirection - 90) * math.pi / 180; // -90 to align with visual orientation
      
      // Wind arrow goes through the center of the runway
      final arrowLength = 20.0; // Longer arrow to go through runway
      final windArrowStart = Offset(
        center.dx - arrowLength * math.cos(windAngle + math.pi), // Opposite direction for "from" wind
        center.dy - arrowLength * math.sin(windAngle + math.pi),
      );
      final windArrowEnd = Offset(
        center.dx + arrowLength * math.cos(windAngle + math.pi), // Through to other side
        center.dy + arrowLength * math.sin(windAngle + math.pi),
      );
      
      // Draw wind arrow (thicker green line through runway)
      final windPaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(windArrowStart, windArrowEnd, windPaint);
      
      // Draw arrowhead at the end
      final arrowSize = 5.0;
      final arrowAngle = math.pi / 6; // 30 degrees
      
      final arrowPoint1 = Offset(
        windArrowEnd.dx - arrowSize * math.cos(windAngle + math.pi + arrowAngle),
        windArrowEnd.dy - arrowSize * math.sin(windAngle + math.pi + arrowAngle),
      );
      final arrowPoint2 = Offset(
        windArrowEnd.dx - arrowSize * math.cos(windAngle + math.pi - arrowAngle),
        windArrowEnd.dy - arrowSize * math.sin(windAngle + math.pi - arrowAngle),
      );
      
      canvas.drawLine(windArrowEnd, arrowPoint1, windPaint);
      canvas.drawLine(windArrowEnd, arrowPoint2, windPaint);
      
      // Wind speed label positioned to the side
      final windSpeed = windData!['speed']?.toInt() ?? 0;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${windSpeed}kt',
          style: const TextStyle(
            color: Colors.green,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final windTextOffset = Offset(
        center.dx + 20,
        center.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, windTextOffset);
    }
    
    // Draw compass rose (N indicator) - positioned relative to smaller circle
    final northPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    
    final northStart = Offset(center.dx, center.dy - 11);
    final northEnd = Offset(center.dx, center.dy - 8);
    canvas.drawLine(northStart, northEnd, northPaint);
    
    // North "N" label
    final northTextPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    northTextPainter.layout();
    northTextPainter.paint(canvas, Offset(
      center.dx - northTextPainter.width / 2,
      center.dy - 18,
    ));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! _CompactRunwayPainter) return true;
    return oldDelegate.leHeading != leHeading ||
           oldDelegate.heHeading != heHeading ||
           oldDelegate.windData != windData;
  }
}
