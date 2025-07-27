import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'flight_plan.dart' show FlightRules;

part 'logbook_entry.g.dart';

@HiveType(typeId: 52)
enum EngineType {
  @HiveField(0)
  singleEngine,
  @HiveField(1)
  multiEngine,
}

@HiveType(typeId: 53)
enum FlightCondition {
  @HiveField(0)
  day,
  @HiveField(1)
  night,
}

@HiveType(typeId: 54)
class LogBookEntry extends HiveObject {
  @HiveField(0)
  final String id;

  // Section Timing
  @HiveField(1)
  final DateTime dateTimeStarted;

  @HiveField(2)
  final DateTime? dateTimeStartedMoving;

  @HiveField(3)
  final String? departureAirport;

  @HiveField(4)
  final DateTime dateTimeFinished;

  @HiveField(5)
  final DateTime? dateTimeFinishedMoving;

  @HiveField(6)
  final String? arrivalAirport;

  // Aircraft
  @HiveField(7)
  final EngineType? engineType;

  @HiveField(8)
  final String? aircraftType;

  @HiveField(9)
  final String? aircraftIdentification;

  // Pilot Experience
  @HiveField(10)
  final String? pilotInCommandId;

  @HiveField(11)
  final String? secondInCommandId;

  @HiveField(12)
  final String? flightTrainingNote;

  @HiveField(13)
  final String? groundTrainingNote;

  @HiveField(14)
  final String? simulatorNote;

  @HiveField(15)
  final bool flightReview;

  @HiveField(16)
  final bool ipc;

  @HiveField(17)
  final bool checkRide;

  @HiveField(18)
  final bool faa6158;

  @HiveField(19)
  final bool nvgProficiency;

  // Conditions of flight
  @HiveField(20)
  final FlightCondition? flightCondition;

  @HiveField(21)
  final FlightRules? flightRules;

  @HiveField(22)
  final bool simulated;

  // Departures and Landings
  @HiveField(23)
  final int dayTakeoffs;

  @HiveField(24)
  final int nightTakeoffs;

  @HiveField(25)
  final int dayLandings;

  @HiveField(26)
  final int nightLandings;

  // Flight log
  @HiveField(27)
  final String? flightLogId;

  @HiveField(28)
  final String? note;

  // Pictures and Documents
  @HiveField(29)
  final List<String> imagePaths;

  @HiveField(30)
  final List<String> documentPaths;

  // Computed values (stored for efficiency)
  @HiveField(31)
  final Duration? trackingDuration;

  @HiveField(32)
  final Duration? movingDuration;

  @HiveField(33)
  final double? distance;

  @HiveField(34)
  final DateTime createdAt;

  @HiveField(35)
  final DateTime updatedAt;

  LogBookEntry({
    String? id,
    required this.dateTimeStarted,
    this.dateTimeStartedMoving,
    this.departureAirport,
    required this.dateTimeFinished,
    this.dateTimeFinishedMoving,
    this.arrivalAirport,
    this.engineType,
    this.aircraftType,
    this.aircraftIdentification,
    this.pilotInCommandId,
    this.secondInCommandId,
    this.flightTrainingNote,
    this.groundTrainingNote,
    this.simulatorNote,
    this.flightReview = false,
    this.ipc = false,
    this.checkRide = false,
    this.faa6158 = false,
    this.nvgProficiency = false,
    this.flightCondition,
    this.flightRules,
    this.simulated = false,
    this.dayTakeoffs = 0,
    this.nightTakeoffs = 0,
    this.dayLandings = 0,
    this.nightLandings = 0,
    this.flightLogId,
    this.note,
    List<String>? imagePaths,
    List<String>? documentPaths,
    this.trackingDuration,
    this.movingDuration,
    this.distance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       imagePaths = imagePaths ?? [],
       documentPaths = documentPaths ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // Computed getters
  Duration get totalDuration => movingDuration ?? trackingDuration ?? Duration.zero;

  int get totalTakeoffs => dayTakeoffs + nightTakeoffs;
  int get totalLandings => dayLandings + nightLandings;

  bool get isSoloPilot => secondInCommandId == null;

  String get route {
    if (departureAirport != null && arrivalAirport != null) {
      return '$departureAirport - $arrivalAirport';
    }
    return 'Unknown route';
  }

  String formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }

  LogBookEntry copyWith({
    DateTime? dateTimeStarted,
    DateTime? dateTimeStartedMoving,
    String? departureAirport,
    DateTime? dateTimeFinished,
    DateTime? dateTimeFinishedMoving,
    String? arrivalAirport,
    EngineType? engineType,
    String? aircraftType,
    String? aircraftIdentification,
    String? pilotInCommandId,
    String? secondInCommandId,
    String? flightTrainingNote,
    String? groundTrainingNote,
    String? simulatorNote,
    bool? flightReview,
    bool? ipc,
    bool? checkRide,
    bool? faa6158,
    bool? nvgProficiency,
    FlightCondition? flightCondition,
    FlightRules? flightRules,
    bool? simulated,
    int? dayTakeoffs,
    int? nightTakeoffs,
    int? dayLandings,
    int? nightLandings,
    String? flightLogId,
    String? note,
    List<String>? imagePaths,
    List<String>? documentPaths,
    Duration? trackingDuration,
    Duration? movingDuration,
    double? distance,
  }) {
    return LogBookEntry(
      id: id,
      dateTimeStarted: dateTimeStarted ?? this.dateTimeStarted,
      dateTimeStartedMoving: dateTimeStartedMoving ?? this.dateTimeStartedMoving,
      departureAirport: departureAirport ?? this.departureAirport,
      dateTimeFinished: dateTimeFinished ?? this.dateTimeFinished,
      dateTimeFinishedMoving: dateTimeFinishedMoving ?? this.dateTimeFinishedMoving,
      arrivalAirport: arrivalAirport ?? this.arrivalAirport,
      engineType: engineType ?? this.engineType,
      aircraftType: aircraftType ?? this.aircraftType,
      aircraftIdentification: aircraftIdentification ?? this.aircraftIdentification,
      pilotInCommandId: pilotInCommandId ?? this.pilotInCommandId,
      secondInCommandId: secondInCommandId ?? this.secondInCommandId,
      flightTrainingNote: flightTrainingNote ?? this.flightTrainingNote,
      groundTrainingNote: groundTrainingNote ?? this.groundTrainingNote,
      simulatorNote: simulatorNote ?? this.simulatorNote,
      flightReview: flightReview ?? this.flightReview,
      ipc: ipc ?? this.ipc,
      checkRide: checkRide ?? this.checkRide,
      faa6158: faa6158 ?? this.faa6158,
      nvgProficiency: nvgProficiency ?? this.nvgProficiency,
      flightCondition: flightCondition ?? this.flightCondition,
      flightRules: flightRules ?? this.flightRules,
      simulated: simulated ?? this.simulated,
      dayTakeoffs: dayTakeoffs ?? this.dayTakeoffs,
      nightTakeoffs: nightTakeoffs ?? this.nightTakeoffs,
      dayLandings: dayLandings ?? this.dayLandings,
      nightLandings: nightLandings ?? this.nightLandings,
      flightLogId: flightLogId ?? this.flightLogId,
      note: note ?? this.note,
      imagePaths: imagePaths ?? this.imagePaths,
      documentPaths: documentPaths ?? this.documentPaths,
      trackingDuration: trackingDuration ?? this.trackingDuration,
      movingDuration: movingDuration ?? this.movingDuration,
      distance: distance ?? this.distance,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateTimeStarted': dateTimeStarted.toIso8601String(),
      'dateTimeStartedMoving': dateTimeStartedMoving?.toIso8601String(),
      'departureAirport': departureAirport,
      'dateTimeFinished': dateTimeFinished.toIso8601String(),
      'dateTimeFinishedMoving': dateTimeFinishedMoving?.toIso8601String(),
      'arrivalAirport': arrivalAirport,
      'engineType': engineType?.index,
      'aircraftType': aircraftType,
      'aircraftIdentification': aircraftIdentification,
      'pilotInCommandId': pilotInCommandId,
      'secondInCommandId': secondInCommandId,
      'flightTrainingNote': flightTrainingNote,
      'groundTrainingNote': groundTrainingNote,
      'simulatorNote': simulatorNote,
      'flightReview': flightReview,
      'ipc': ipc,
      'checkRide': checkRide,
      'faa6158': faa6158,
      'nvgProficiency': nvgProficiency,
      'flightCondition': flightCondition?.index,
      'flightRules': flightRules?.index,
      'simulated': simulated,
      'dayTakeoffs': dayTakeoffs,
      'nightTakeoffs': nightTakeoffs,
      'dayLandings': dayLandings,
      'nightLandings': nightLandings,
      'flightLogId': flightLogId,
      'note': note,
      'imagePaths': imagePaths,
      'documentPaths': documentPaths,
      'trackingDuration': trackingDuration?.inMilliseconds,
      'movingDuration': movingDuration?.inMilliseconds,
      'distance': distance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LogBookEntry.fromJson(Map<String, dynamic> json) {
    return LogBookEntry(
      id: json['id'],
      dateTimeStarted: DateTime.parse(json['dateTimeStarted']),
      dateTimeStartedMoving: json['dateTimeStartedMoving'] != null
          ? DateTime.parse(json['dateTimeStartedMoving'])
          : null,
      departureAirport: json['departureAirport'],
      dateTimeFinished: DateTime.parse(json['dateTimeFinished']),
      dateTimeFinishedMoving: json['dateTimeFinishedMoving'] != null
          ? DateTime.parse(json['dateTimeFinishedMoving'])
          : null,
      arrivalAirport: json['arrivalAirport'],
      engineType: json['engineType'] != null
          ? EngineType.values[json['engineType']]
          : null,
      aircraftType: json['aircraftType'],
      aircraftIdentification: json['aircraftIdentification'],
      pilotInCommandId: json['pilotInCommandId'],
      secondInCommandId: json['secondInCommandId'],
      flightTrainingNote: json['flightTrainingNote'],
      groundTrainingNote: json['groundTrainingNote'],
      simulatorNote: json['simulatorNote'],
      flightReview: json['flightReview'] ?? false,
      ipc: json['ipc'] ?? false,
      checkRide: json['checkRide'] ?? false,
      faa6158: json['faa6158'] ?? false,
      nvgProficiency: json['nvgProficiency'] ?? false,
      flightCondition: json['flightCondition'] != null
          ? FlightCondition.values[json['flightCondition']]
          : null,
      flightRules: json['flightRules'] != null
          ? FlightRules.values[json['flightRules']]
          : null,
      simulated: json['simulated'] ?? false,
      dayTakeoffs: json['dayTakeoffs'] ?? 0,
      nightTakeoffs: json['nightTakeoffs'] ?? 0,
      dayLandings: json['dayLandings'] ?? 0,
      nightLandings: json['nightLandings'] ?? 0,
      flightLogId: json['flightLogId'],
      note: json['note'],
      imagePaths: json['imagePaths'] != null
          ? List<String>.from(json['imagePaths'])
          : null,
      documentPaths: json['documentPaths'] != null
          ? List<String>.from(json['documentPaths'])
          : null,
      trackingDuration: json['trackingDuration'] != null
          ? Duration(milliseconds: json['trackingDuration'])
          : null,
      movingDuration: json['movingDuration'] != null
          ? Duration(milliseconds: json['movingDuration'])
          : null,
      distance: json['distance']?.toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}