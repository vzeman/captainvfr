// import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/airport.dart';
import '../models/runway.dart';
import '../models/frequency.dart';
import '../services/weather_service.dart';
import '../services/weather_interpretation_service.dart';
import '../services/runway_service.dart';
import '../services/bundled_frequency_service.dart';
import 'airport_info_sheet/airport_info_tab.dart';
import 'airport_info_sheet/airport_weather_tab.dart';
import 'airport_info_sheet/airport_runways_tab.dart';
import 'airport_info_sheet/airport_frequencies_tab.dart';
import 'airport_info_sheet/airport_notams_tab.dart';
import 'airport_info_sheet/airport_data_fetcher.dart';
import '../constants/app_theme.dart';
import '../constants/app_colors.dart';

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

class _AirportInfoSheetState extends State<AirportInfoSheet>
    with SingleTickerProviderStateMixin {
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
    final frequencyService = Provider.of<BundledFrequencyService>(
      context,
      listen: false,
    );

    _dataFetcher = AirportDataFetcher(
      weatherService: widget.weatherService,
      runwayService: runwayService,
      frequencyService: frequencyService,
    );
    _weatherInterpretationService = WeatherInterpretationService();

    // log('✅ Services obtained from Provider - Runway: ${runwayService.runways.length}, Frequency: ${frequencyService.frequencies.length}');
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AirportInfoSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only reset state if the airport ICAO actually changed
    // Ignore changes to weather data to prevent buildScope issues
    if (oldWidget.airport.icao != widget.airport.icao) {
      // Schedule state reset after current build cycle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Airport changed, reset all tabs
            _weatherTabInitialized = false;
            _runwaysTabInitialized = false;
            _frequenciesTabInitialized = false;
            _isLoadingWeather = false;
            _isLoadingRunways = false;
            _isLoadingFrequencies = false;
            _weatherError = null;
            _runwaysError = null;
            _frequenciesError = null;
            _runways = [];
            _frequencies = [];
          });
        }
      });
    }
  }

  void _handleTabChange() {
    // Use scheduleMicrotask to defer execution and avoid buildScope issues
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      if (_tabController.index == 1 && !_weatherTabInitialized) {
        await _fetchWeather();
      } else if (_tabController.index == 2) {
        // For runways tab, ensure weather data is available for wind calculations
        final List<Future> futures = [];
        if (!_weatherTabInitialized) {
          futures.add(_fetchWeather());
        }
        if (!_runwaysTabInitialized) {
          futures.add(_fetchRunways());
        }
        // Wait for all operations to complete before proceeding
        if (futures.isNotEmpty) {
          await Future.wait(futures);
        }
      } else if (_tabController.index == 3 && !_frequenciesTabInitialized) {
        await _fetchFrequencies();
      }
    });
  }

  Future<void> _fetchWeather() async {
    // Check if this airport type should have weather data
    if (!_dataFetcher.shouldFetchWeatherForAirport(widget.airport)) {
      if (mounted) {
        setState(() {
          _weatherTabInitialized = true;
          _isLoadingWeather = false;
          _weatherError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingWeather = true;
        _weatherError = null;
        _weatherTabInitialized = true;
      });
    }

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
      final runways = await _dataFetcher.fetchRunways(widget.airport);
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
      final frequencies = await _dataFetcher.fetchFrequencies(widget.airport);
      if (mounted) {
        setState(() {
          _frequencies = frequencies;
        });
        // log('🔧 DEBUG: Updated UI state with ${frequencies.length} frequencies');
      }
    } catch (e) {
      // log('❌ Error fetching frequencies: $e');
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
        color: AppColors.dialogBackgroundColor, // Use explicit black background
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusDefault)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sectionBackgroundColor, // Use explicit dark color
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.borderRadiusDefault),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3), // 30% opacity for visibility
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
                          color: AppColors.primaryTextColor, // Explicit white
                        ),
                      ),
                      Text(
                        widget.airport.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryTextColor, // Explicit light gray
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
          Container(
            color: AppColors.backgroundColor, // Black background for tabs
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primaryTextColor,
              unselectedLabelColor: AppColors.secondaryTextColor,
              indicatorColor: AppColors.primaryAccent,
              tabs: const [
              Tab(text: 'Info', icon: Icon(Icons.info_outline)),
              Tab(text: 'Weather', icon: Icon(Icons.cloud_outlined)),
              Tab(text: 'Runways', icon: Icon(Icons.straighten)),
              Tab(text: 'Frequencies', icon: Icon(Icons.radio)),
              Tab(text: 'NOTAMs', icon: Icon(Icons.description)),
            ],
            ),
          ),

          // Tab Content
          Expanded(
            child: Container(
              color: AppColors.backgroundColor, // Black background for content
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
                  weatherService: widget.weatherService,
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
          ),
        ],
      ),
    );
  }
}
