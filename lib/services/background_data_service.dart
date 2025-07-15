import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:latlong2/latlong.dart';
import 'airport_service.dart';
import 'runway_service.dart';
import 'navaid_service.dart';
import 'bundled_frequency_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

class BackgroundDataService extends ChangeNotifier {
  static final BackgroundDataService _instance =
      BackgroundDataService._internal();
  factory BackgroundDataService() => _instance;
  BackgroundDataService._internal();

  // Loading status
  bool _isLoading = false;
  String _currentTask = '';
  double _progress = 0.0;
  final Map<String, bool> _loadedData = {
    'airports': false,
    // Runways are now bundled with airports
    'navaids': false,
    'frequencies': false,
  };

  // Getters
  bool get isLoading => _isLoading;
  String get currentTask => _currentTask;
  double get progress => _progress;
  Map<String, bool> get loadedData => Map.unmodifiable(_loadedData);
  bool get isFullyLoaded => _loadedData.values.every((loaded) => loaded);

  // Services
  late final AirportService _airportService;
  late final RunwayService _runwayService;
  late final NavaidService _navaidService;
  late final BundledFrequencyService _frequencyService;
  late final CacheService _cacheService;
  final ConnectivityService _connectivityService = ConnectivityService();

  Future<void> initialize({
    required AirportService airportService,
    required RunwayService runwayService,
    required NavaidService navaidService,
    required BundledFrequencyService frequencyService,
    required CacheService cacheService,
  }) async {
    _airportService = airportService;
    _runwayService = runwayService;
    _navaidService = navaidService;
    _frequencyService = frequencyService;
    _cacheService = cacheService;
  }

  Future<void> loadDataInBackground() async {
    if (_isLoading) return;

    _isLoading = true;
    _progress = 0.0;
    notifyListeners();

    try {
      final tasks = [
        _LoadTask('Loading airports...', 'airports', _loadAirports),
        _LoadTask('Loading runways...', 'runways', _loadRunways),
        _LoadTask('Loading navaids...', 'navaids', _loadNavaids),
        _LoadTask('Loading frequencies...', 'frequencies', _loadFrequencies),
      ];

      final totalTasks = tasks.length;
      var completedTasks = 0;

      for (final task in tasks) {
        _currentTask = task.name;
        notifyListeners();

        try {
          await task.loader();
          _loadedData[task.key] = true;
          completedTasks++;
        } catch (e) {
          developer.log('❌ Error during ${task.name}: $e');
          // Continue with other tasks even if one fails
        }

        _progress = completedTasks / totalTasks;
        notifyListeners();

        // Small delay between tasks
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _currentTask = 'Data loading complete';
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      _isLoading = false;
      _currentTask = '';
      notifyListeners();
    }
  }

  Future<void> _loadAirports() async {
    developer.log('🏛️ Loading airports from cache...');

    // First try to initialize from bundled data
    await _airportService.initialize();
    
    // Check if airports were loaded (either from bundled data or cache)
    final airports = await _airportService.getAirportsInBounds(
      const LatLng(-90, -180), 
      const LatLng(90, 180)
    );
    
    if (airports.isNotEmpty) {
      developer.log('✅ Airports already loaded: ${airports.length} airports available');
      return;
    }

    // If no airports loaded, try cache
    final cachedAirports = await _cacheService.getCachedAirports();

    if (cachedAirports.isEmpty) {
      // Only fetch from network if we have internet connection
      if (_connectivityService.hasInternetConnection) {
        await _airportService.fetchNearbyAirports();
      } else {
        developer.log('⚠️ No cached airports and no internet connection');
      }
    }
  }

  Future<void> _loadRunways() async {
    developer.log('🛬 Loading runways from bundled data...');
    
    // Initialize the runway service (loads bundled data)
    await _runwayService.initialize();
    
    final runwayCount = _runwayService.runways.length;
    developer.log('✅ Loaded $runwayCount runways from bundled data');
  }

  Future<void> _loadNavaids() async {

    final cachedNavaids = await _cacheService.getCachedNavaids();

    if (cachedNavaids.isEmpty) {
      if (_connectivityService.hasInternetConnection) {
        developer.log('📡 No cached navaids, fetching from API...');
        await _navaidService.fetchNavaids();
      } else {
        developer.log('⚠️ No cached navaids and no internet connection');
      }
    } else {
      developer.log('✅ Loaded ${cachedNavaids.length} navaids from cache');
      // Initialize the service with cached data
      await _navaidService.initialize();
    }
  }

  Future<void> _loadFrequencies() async {
    developer.log('📻 Loading frequencies from bundled data...');
    
    // Initialize the bundled frequency service
    await _frequencyService.initialize();
    
    final frequencyCount = _frequencyService.frequencies.length;
    developer.log('✅ Loaded $frequencyCount frequencies from bundled data');
  }
}

class _LoadTask {
  final String name;
  final String key;
  final Future<void> Function() loader;

  _LoadTask(this.name, this.key, this.loader);
}
