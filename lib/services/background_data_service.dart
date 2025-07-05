import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'airport_service.dart';
import 'runway_service.dart';
import 'navaid_service.dart';
import 'frequency_service.dart';
import 'cache_service.dart';

class BackgroundDataService extends ChangeNotifier {
  static final BackgroundDataService _instance = BackgroundDataService._internal();
  factory BackgroundDataService() => _instance;
  BackgroundDataService._internal();

  // Loading status
  bool _isLoading = false;
  String _currentTask = '';
  double _progress = 0.0;
  final Map<String, bool> _loadedData = {
    'airports': false,
    'runways': false,
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
  late final FrequencyService _frequencyService;
  late final CacheService _cacheService;

  Future<void> initialize({
    required AirportService airportService,
    required RunwayService runwayService,
    required NavaidService navaidService,
    required FrequencyService frequencyService,
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
    
    final cachedAirports = await _cacheService.getCachedAirports();
    
    if (cachedAirports.isEmpty) {
      developer.log('📡 No cached airports, fetching from API...');
      await _airportService.fetchNearbyAirports();
    } else {
      developer.log('✅ Loaded ${cachedAirports.length} airports from cache');
      // Initialize the service with cached data
      await _airportService.initialize();
    }
  }

  Future<void> _loadRunways() async {
    developer.log('🛬 Loading runways from cache...');
    
    final cachedRunways = await _cacheService.getCachedRunways();
    
    if (cachedRunways.isEmpty) {
      developer.log('📡 No cached runways, fetching from API...');
      await _runwayService.fetchRunways();
    } else {
      developer.log('✅ Loaded ${cachedRunways.length} runways from cache');
      // Initialize the service with cached data
      await _runwayService.initialize();
    }
  }

  Future<void> _loadNavaids() async {
    developer.log('📡 Loading navaids from cache...');
    
    final cachedNavaids = await _cacheService.getCachedNavaids();
    
    if (cachedNavaids.isEmpty) {
      developer.log('📡 No cached navaids, fetching from API...');
      await _navaidService.fetchNavaids();
    } else {
      developer.log('✅ Loaded ${cachedNavaids.length} navaids from cache');
      // Initialize the service with cached data
      await _navaidService.initialize();
    }
  }

  Future<void> _loadFrequencies() async {
    developer.log('📻 Loading frequencies from cache...');
    
    final cachedFrequencies = await _cacheService.getCachedFrequencies();
    
    if (cachedFrequencies.isEmpty) {
      developer.log('📡 No cached frequencies, fetching from API...');
      await _frequencyService.fetchFrequencies();
    } else {
      developer.log('✅ Loaded ${cachedFrequencies.length} frequencies from cache');
      // Initialize the service with cached data
      await _frequencyService.initialize();
    }
  }
}

class _LoadTask {
  final String name;
  final String key;
  final Future<void> Function() loader;

  _LoadTask(this.name, this.key, this.loader);
}