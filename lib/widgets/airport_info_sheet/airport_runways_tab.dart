import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/airport.dart';
import '../../models/runway.dart';
import '../../services/runway_service.dart';
import '../../services/settings_service.dart';
import '../../services/weather_service.dart';
import '../../utils/runway_wind_calculator.dart';
import '../common/loading_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchWindData();
  }

  @override
  void didUpdateWidget(AirportRunwaysTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always check if we need to refetch when widget updates
    _checkAndRefetchWindData();
  }

  void _checkAndRefetchWindData() {
    // Check if we have new METAR data that we haven't processed yet
    final currentMetar = widget.airport.rawMetar;
    if (currentMetar != null && 
        currentMetar.isNotEmpty && 
        currentMetar != _lastProcessedMetar) {
      debugPrint('New METAR data detected, refetching wind data');
      _fetchWindData();
    } else if (_windData == null && !_isLoadingWind) {
      // If we don't have wind data and aren't loading, try to fetch
      debugPrint('No wind data present, attempting to fetch');
      _fetchWindData();
    }
  }

  Future<void> _fetchWindData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingWind = true;
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
        
        // If still no data, try to force reload the weather service
        if (metar == null || metar.isEmpty) {
          debugPrint('No cached METAR found, forcing weather service reload...');
          await widget.weatherService.initialize();
          
          // Force reload to get fresh data
          await widget.weatherService.forceReload();
          
          // Try fetching again after force reload
          metar = await widget.weatherService.getMetar(widget.airport.icao);
          debugPrint('After force reload result: ${metar != null ? 'success' : 'null'}');
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
    // Check if we need to refetch wind data on every build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndRefetchWindData();
      }
    });

    if (widget.isLoading) {
      return const LoadingWidget(message: 'Loading runway data...');
    }

    if (widget.error != null) {
      return custom.ErrorWidget(error: widget.error!, onRetry: widget.onRetry);
    }

    if (widget.runways.isEmpty) {
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
          // Wind Information (if available or loading)
          if (_isLoadingWind) ...[
            _buildWindLoadingIndicator(context),
            const SizedBox(height: 16),
          ] else if (_windData != null) ...[
            _buildWindInfo(context),
            const SizedBox(height: 16),
          ],

          // Individual Runways
          Text(
            'Runways (${widget.runways.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...widget.runways.map((runway) => RunwayCard(
            runway: runway,
            windComponents: _getWindComponentsForRunway(runway),
            isBestRunway: _isBestRunway(runway),
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
  
  
  Widget _buildWindLoadingIndicator(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
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

  Widget _buildWindInfo(BuildContext context) {
    final theme = Theme.of(context);
    final windDirection = _windData!['direction']!.toInt();
    final windSpeed = _windData!['speed']!.toInt();
    final windGust = _windData!['gust']?.toInt();
    final hasGust = windGust != null && windGust > windSpeed;
    
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.air,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Wind Conditions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                // Wind direction arrow
                Transform.rotate(
                  angle: (windDirection * math.pi / 180) - math.pi, // Convert to radians and adjust for "from" direction
                  child: Icon(
                    Icons.arrow_downward,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Wind: ${windDirection.toString().padLeft(3, '0')}° at $windSpeed${hasGust ? ' G$windGust' : ''} knots',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                if (hasGust) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GUSTING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_bestRunway != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.flight_land,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Best runway for landing: $_bestRunway',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Selected based on maximum headwind and minimum crosswind',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
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

  const RunwayCard({
    super.key,
    required this.runway,
    this.windComponents,
    this.isBestRunway = false,
  });
  
  static Color _getCrosswindColor(double crosswind) {
    const double crosswindCautionThreshold = 10.0; // knots
    const double crosswindDangerThreshold = 15.0; // knots
    
    if (crosswind >= crosswindDangerThreshold) {
      return Colors.red;
    } else if (crosswind >= crosswindCautionThreshold) {
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
          color: isBestRunway ? theme.colorScheme.primaryContainer : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Runway designation and basic info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isBestRunway 
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.2), // 20% opacity
                        borderRadius: BorderRadius.circular(4),
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
                    const Spacer(),
                    if (isBestRunway)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wind Components',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...windComponents!.map((component) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  component.runwayDesignation,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                component.isHeadwind ? Icons.arrow_downward : Icons.arrow_upward,
                                size: 14,
                                color: component.isHeadwind ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${component.headwindAbs.toStringAsFixed(0)} kts ${component.isHeadwind ? "headwind" : "tailwind"}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: component.isHeadwind ? Colors.green : Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.compare_arrows,
                                size: 14,
                                color: _getCrosswindColor(component.crosswind),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${component.crosswind.toStringAsFixed(0)} kts crosswind',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _getCrosswindColor(component.crosswind),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
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
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
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
}
