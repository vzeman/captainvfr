import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/logbook_entry.dart';
import '../models/flight.dart';
import '../models/flight_plan.dart' show FlightRules;
import 'pilot_service.dart';
import 'aircraft_settings_service.dart';

class LogBookStatistics {
  final Duration totalDuration;
  final Duration singleEngineDuration;
  final Duration multiEngineDuration;
  final Duration picDuration;
  final Duration sicDuration;
  final Duration soloDuration;
  final Duration vfrDuration;
  final Duration ifrDuration;
  final Duration dayDuration;
  final Duration nightDuration;
  final Duration simulatorVfrDuration;
  final Duration simulatorIfrDuration;
  final int totalTakeoffs;
  final int dayTakeoffs;
  final int nightTakeoffs;
  final int totalLandings;
  final int dayLandings;
  final int nightLandings;
  final Map<String, Duration> durationByAircraft;
  final Map<String, int> takeoffsByAircraft;
  final Map<String, int> landingsByAircraft;

  LogBookStatistics({
    required this.totalDuration,
    required this.singleEngineDuration,
    required this.multiEngineDuration,
    required this.picDuration,
    required this.sicDuration,
    required this.soloDuration,
    required this.vfrDuration,
    required this.ifrDuration,
    required this.dayDuration,
    required this.nightDuration,
    required this.simulatorVfrDuration,
    required this.simulatorIfrDuration,
    required this.totalTakeoffs,
    required this.dayTakeoffs,
    required this.nightTakeoffs,
    required this.totalLandings,
    required this.dayLandings,
    required this.nightLandings,
    required this.durationByAircraft,
    required this.takeoffsByAircraft,
    required this.landingsByAircraft,
  });
}

class LogBookService extends ChangeNotifier {
  static const String _entriesBoxName = 'logbook_entries';
  
  Box<LogBookEntry>? _entriesBox;
  final PilotService _pilotService;
  
  List<LogBookEntry> _entries = [];

  LogBookService({
    required PilotService pilotService,
    required AircraftSettingsService aircraftService,
  }) : _pilotService = pilotService;

  List<LogBookEntry> get entries => List.unmodifiable(_entries);

  Future<void> initialize() async {
    try {
      _entriesBox = await Hive.openBox<LogBookEntry>(_entriesBoxName);
      _loadEntries();
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing LogBookService: $e');
      throw Exception('Failed to initialize logbook service');
    }
  }

  void _loadEntries() {
    if (_entriesBox != null && _entriesBox!.isOpen) {
      _entries = _entriesBox!.values.toList()
        ..sort((a, b) => b.dateTimeStarted.compareTo(a.dateTimeStarted));
      
      // Migrate entries without engine type
      bool needsMigration = false;
      for (final entry in _entries) {
        if (entry.engineType == null) {
          needsMigration = true;
          // Update the entry with default engine type
          final updatedEntry = entry.copyWith(
            engineType: EngineType.singleEngine,
          );
          _entriesBox!.put(entry.id, updatedEntry);
        }
      }
      
      if (needsMigration) {
        // Reload entries after migration
        _entries = _entriesBox!.values.toList()
          ..sort((a, b) => b.dateTimeStarted.compareTo(a.dateTimeStarted));
      }
    }
  }

  // CRUD operations
  Future<LogBookEntry> addEntry(LogBookEntry entry) async {
    if (_entriesBox == null) throw Exception('Service not initialized');
    
    await _entriesBox!.put(entry.id, entry);
    _loadEntries();
    notifyListeners();
    return entry;
  }

  Future<void> updateEntry(LogBookEntry entry) async {
    if (_entriesBox == null) throw Exception('Service not initialized');
    
    await _entriesBox!.put(entry.id, entry);
    _loadEntries();
    notifyListeners();
  }

  Future<void> deleteEntry(String entryId) async {
    if (_entriesBox == null) throw Exception('Service not initialized');
    
    await _entriesBox!.delete(entryId);
    _loadEntries();
    notifyListeners();
  }

  LogBookEntry? getEntryById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // Create entry from flight
  Future<LogBookEntry> createEntryFromFlight(Flight flight) async {
    // Determine departure and arrival airports
    // For now, we'll leave these empty as FlightSegment doesn't track airport names
    // In a future update, we might want to reverse geocode the coordinates
    String? departureAirport;
    String? arrivalAirport;

    // Get current pilot
    final currentPilot = _pilotService.currentPilot;
    
    // Get aircraft info - default to single engine
    // In a future update, we might want to add aircraft tracking to Flight model
    EngineType engineType = EngineType.singleEngine;

    // Determine flight conditions based on time
    final startHour = flight.startTime.hour;
    final endHour = flight.endTime?.hour ?? flight.startTime.hour;
    final isNight = startHour < 6 || startHour >= 18 || endHour < 6 || endHour >= 18;
    
    final entry = LogBookEntry(
      dateTimeStarted: flight.startTime,
      dateTimeStartedMoving: flight.movingSegments.isNotEmpty 
          ? flight.movingSegments.first.start 
          : null,
      departureAirport: departureAirport,
      dateTimeFinished: flight.endTime ?? DateTime.now(),
      dateTimeFinishedMoving: flight.movingSegments.isNotEmpty 
          ? flight.movingSegments.last.end 
          : null,
      arrivalAirport: arrivalAirport,
      engineType: engineType,
      aircraftType: null,
      aircraftIdentification: null,
      pilotInCommandId: currentPilot?.id,
      flightCondition: isNight ? FlightCondition.night : FlightCondition.day,
      flightRules: FlightRules.vfr, // Default to VFR
      flightLogId: flight.id,
      trackingDuration: flight.duration,
      movingDuration: flight.movingTime,
      distance: flight.distanceTraveled,
      dayTakeoffs: isNight ? 0 : 1,
      nightTakeoffs: isNight ? 1 : 0,
      dayLandings: isNight ? 0 : 1,
      nightLandings: isNight ? 1 : 0,
    );
    
    return await addEntry(entry);
  }

  // Get entries for a specific pilot
  List<LogBookEntry> getEntriesForPilot(String pilotId) {
    return _entries.where((e) => 
      e.pilotInCommandId == pilotId || e.secondInCommandId == pilotId
    ).toList();
  }

  // Get entries for a specific aircraft
  List<LogBookEntry> getEntriesForAircraft(String aircraftId) {
    return _entries.where((e) => e.aircraftIdentification == aircraftId).toList();
  }

  // Get entries within date range
  List<LogBookEntry> getEntriesInDateRange(DateTime start, DateTime end) {
    return _entries.where((e) => 
      e.dateTimeStarted.isAfter(start) && e.dateTimeStarted.isBefore(end)
    ).toList();
  }

  // Calculate statistics
  LogBookStatistics calculateStatistics({
    DateTime? startDate,
    DateTime? endDate,
    String? pilotId,
  }) {
    // Filter entries based on criteria
    var filteredEntries = _entries;
    
    if (startDate != null) {
      filteredEntries = filteredEntries.where((e) => 
        e.dateTimeStarted.isAfter(startDate)
      ).toList();
    }
    
    if (endDate != null) {
      filteredEntries = filteredEntries.where((e) => 
        e.dateTimeStarted.isBefore(endDate)
      ).toList();
    }
    
    if (pilotId != null) {
      filteredEntries = filteredEntries.where((e) => 
        e.pilotInCommandId == pilotId || e.secondInCommandId == pilotId
      ).toList();
    }

    // Calculate durations
    Duration totalDuration = Duration.zero;
    Duration singleEngineDuration = Duration.zero;
    Duration multiEngineDuration = Duration.zero;
    Duration picDuration = Duration.zero;
    Duration sicDuration = Duration.zero;
    Duration soloDuration = Duration.zero;
    Duration vfrDuration = Duration.zero;
    Duration ifrDuration = Duration.zero;
    Duration dayDuration = Duration.zero;
    Duration nightDuration = Duration.zero;
    Duration simulatorVfrDuration = Duration.zero;
    Duration simulatorIfrDuration = Duration.zero;
    
    // Calculate counts
    int totalTakeoffs = 0;
    int dayTakeoffs = 0;
    int nightTakeoffs = 0;
    int totalLandings = 0;
    int dayLandings = 0;
    int nightLandings = 0;
    
    // Maps for aircraft statistics
    Map<String, Duration> durationByAircraft = {};
    Map<String, int> takeoffsByAircraft = {};
    Map<String, int> landingsByAircraft = {};

    for (final entry in filteredEntries) {
      final duration = entry.totalDuration;
      totalDuration += duration;
      
      // Engine type
      if (entry.engineType == EngineType.singleEngine) {
        singleEngineDuration += duration;
      } else if (entry.engineType == EngineType.multiEngine) {
        multiEngineDuration += duration;
      }
      
      // Pilot role
      if (pilotId == null || entry.pilotInCommandId == pilotId) {
        picDuration += duration;
      } else if (entry.secondInCommandId == pilotId) {
        sicDuration += duration;
      }
      
      // Solo
      if (entry.isSoloPilot) {
        soloDuration += duration;
      }
      
      // Flight rules
      if (entry.simulated) {
        if (entry.flightRules == FlightRules.vfr) {
          simulatorVfrDuration += duration;
        } else if (entry.flightRules == FlightRules.ifr) {
          simulatorIfrDuration += duration;
        }
      } else {
        if (entry.flightRules == FlightRules.vfr) {
          vfrDuration += duration;
        } else if (entry.flightRules == FlightRules.ifr) {
          ifrDuration += duration;
        }
      }
      
      // Day/Night
      if (entry.flightCondition == FlightCondition.day) {
        dayDuration += duration;
      } else if (entry.flightCondition == FlightCondition.night) {
        nightDuration += duration;
      }
      
      // Takeoffs and landings
      totalTakeoffs += entry.totalTakeoffs;
      dayTakeoffs += entry.dayTakeoffs;
      nightTakeoffs += entry.nightTakeoffs;
      totalLandings += entry.totalLandings;
      dayLandings += entry.dayLandings;
      nightLandings += entry.nightLandings;
      
      // Aircraft statistics
      if (entry.aircraftType != null) {
        final aircraft = entry.aircraftType!;
        durationByAircraft[aircraft] = 
            (durationByAircraft[aircraft] ?? Duration.zero) + duration;
        takeoffsByAircraft[aircraft] = 
            (takeoffsByAircraft[aircraft] ?? 0) + entry.totalTakeoffs;
        landingsByAircraft[aircraft] = 
            (landingsByAircraft[aircraft] ?? 0) + entry.totalLandings;
      }
    }

    return LogBookStatistics(
      totalDuration: totalDuration,
      singleEngineDuration: singleEngineDuration,
      multiEngineDuration: multiEngineDuration,
      picDuration: picDuration,
      sicDuration: sicDuration,
      soloDuration: soloDuration,
      vfrDuration: vfrDuration,
      ifrDuration: ifrDuration,
      dayDuration: dayDuration,
      nightDuration: nightDuration,
      simulatorVfrDuration: simulatorVfrDuration,
      simulatorIfrDuration: simulatorIfrDuration,
      totalTakeoffs: totalTakeoffs,
      dayTakeoffs: dayTakeoffs,
      nightTakeoffs: nightTakeoffs,
      totalLandings: totalLandings,
      dayLandings: dayLandings,
      nightLandings: nightLandings,
      durationByAircraft: durationByAircraft,
      takeoffsByAircraft: takeoffsByAircraft,
      landingsByAircraft: landingsByAircraft,
    );
  }

  // Format duration for display
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _entriesBox?.close();
    super.dispose();
  }
}