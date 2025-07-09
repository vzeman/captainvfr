import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/airport.dart';
import '../models/runway.dart';
import '../models/frequency.dart';
import '../services/weather_service.dart';
import '../services/weather_interpretation_service.dart';
import '../services/runway_service.dart';
import '../services/frequency_service.dart';
import 'airport_info_sheet/airport_info_tab.dart';
import 'airport_info_sheet/airport_weather_tab.dart';
import 'airport_info_sheet/airport_runways_tab.dart';
import 'airport_info_sheet/airport_frequencies_tab.dart';
import 'airport_info_sheet/airport_notams_tab.dart';
import 'airport_info_sheet/airport_data_fetcher.dart';

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
  bool _isLoadingFrequencies = false;
  String? _weatherError;
  String? _runwaysError;
  String? _frequenciesError;
  bool _weatherTabInitialized = false;
  bool _runwaysTabInitialized = false;
  bool _frequenciesTabInitialized = false;
  List<Runway> _runways = [];
  List<Frequency> _frequencies = [];

  // Services and data fetcher
  late final AirportDataFetcher _dataFetcher;
  late final WeatherInterpretationService _weatherInterpretationService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get services from Provider and initialize data fetcher
    final runwayService = Provider.of<RunwayService>(context, listen: false);
    final frequencyService = Provider.of<FrequencyService>(context, listen: false);

    _dataFetcher = AirportDataFetcher(
      weatherService: widget.weatherService,
      runwayService: runwayService,
      frequencyService: frequencyService,
    );
    _weatherInterpretationService = WeatherInterpretationService();

    log('✅ Services obtained from Provider - Runway: ${runwayService.runways.length}, Frequency: ${frequencyService.frequencies.length}');
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    log('🔧 DEBUG: Tab changed to index ${_tabController.index}');

    if (_tabController.index == 1 && !_weatherTabInitialized) {
      log('🔧 DEBUG: Initializing weather tab');
      _fetchWeather();
    } else if (_tabController.index == 2 && !_runwaysTabInitialized) {
      log('🔧 DEBUG: Initializing runways tab');
      _fetchRunways();
    } else if (_tabController.index == 3 && !_frequenciesTabInitialized) {
      log('🔧 DEBUG: Initializing frequencies tab');
      _fetchFrequencies();
    }
  }

  Future<void> _fetchWeather() async {
    // Check if this airport type should have weather data
    if (!_dataFetcher.shouldFetchWeatherForAirport(widget.airport)) {
      setState(() {
        _weatherTabInitialized = true;
        _isLoadingWeather = false;
        _weatherError = null;
      });
      return;
    }

    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
      _weatherTabInitialized = true;
    });

    try {
      await _dataFetcher.fetchWeather(widget.airport);
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
          _weatherError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
          // Only show error if we don't have any cached data to display
          if (widget.airport.rawMetar == null && widget.airport.taf == null) {
            _weatherError = 'Failed to load weather data: $e';
          }
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
      final runways = _dataFetcher.fetchRunways(widget.airport.icao);
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

  Future<void> _fetchFrequencies() async {
    if (_frequenciesTabInitialized) return;

    setState(() {
      _isLoadingFrequencies = true;
      _frequenciesError = null;
      _frequenciesTabInitialized = true;
    });

    try {
      final frequencies = _dataFetcher.fetchFrequencies(widget.airport);
      if (mounted) {
        setState(() {
          _frequencies = frequencies;
        });
        log('🔧 DEBUG: Updated UI state with ${frequencies.length} frequencies');
      }
    } catch (e) {
      log('❌ Error fetching frequencies: $e');
      if (mounted) {
        setState(() {
          _frequenciesError = 'Failed to load frequency data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFrequencies = false;
        });
      }
    }
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
            isScrollable: true,
            tabs: const [
              Tab(text: 'Info', icon: Icon(Icons.info_outline)),
              Tab(text: 'Weather', icon: Icon(Icons.cloud_outlined)),
              Tab(text: 'Runways', icon: Icon(Icons.straighten)),
              Tab(text: 'Frequencies', icon: Icon(Icons.radio)),
              Tab(text: 'NOTAMs', icon: Icon(Icons.description)),
            ],
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                AirportInfoTab(
                  airport: widget.airport,
                  onNavigate: widget.onNavigate,
                ),
                AirportWeatherTab(
                  airport: widget.airport,
                  isLoading: _isLoadingWeather,
                  error: _weatherError,
                  onRetry: () {
                    setState(() {
                      _weatherTabInitialized = false;
                    });
                    _fetchWeather();
                  },
                  weatherInterpretationService: _weatherInterpretationService,
                ),
                AirportRunwaysTab(
                  airport: widget.airport,
                  isLoading: _isLoadingRunways,
                  error: _runwaysError,
                  runways: _runways,
                  onRetry: () {
                    setState(() {
                      _runwaysTabInitialized = false;
                    });
                    _fetchRunways();
                  },
                  runwayService: _dataFetcher.runwayService,
                ),
                AirportFrequenciesTab(
                  airport: widget.airport,
                  isLoading: _isLoadingFrequencies,
                  error: _frequenciesError,
                  frequencies: _frequencies,
                  onRetry: () {
                    setState(() {
                      _frequenciesTabInitialized = false;
                    });
                    _fetchFrequencies();
                  },
                ),
                AirportNotamsTab(
                  key: ValueKey('notams_${widget.airport.icao}'),
                  airport: widget.airport,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
