// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logbook_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LogBookEntryAdapter extends TypeAdapter<LogBookEntry> {
  @override
  final int typeId = 54;

  @override
  LogBookEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LogBookEntry(
      id: fields[0] as String?,
      dateTimeStarted: fields[1] as DateTime,
      dateTimeStartedMoving: fields[2] as DateTime?,
      departureAirport: fields[3] as String?,
      dateTimeFinished: fields[4] as DateTime,
      dateTimeFinishedMoving: fields[5] as DateTime?,
      arrivalAirport: fields[6] as String?,
      engineType: fields[7] as EngineType?,
      aircraftType: fields[8] as String?,
      aircraftIdentification: fields[9] as String?,
      pilotInCommandId: fields[10] as String?,
      secondInCommandId: fields[11] as String?,
      flightTrainingNote: fields[12] as String?,
      groundTrainingNote: fields[13] as String?,
      simulatorNote: fields[14] as String?,
      flightReview: fields[15] as bool,
      ipc: fields[16] as bool,
      checkRide: fields[17] as bool,
      faa6158: fields[18] as bool,
      nvgProficiency: fields[19] as bool,
      flightCondition: fields[20] as FlightCondition?,
      flightRules: fields[21] as FlightRules?,
      simulated: fields[22] as bool,
      dayTakeoffs: fields[23] as int,
      nightTakeoffs: fields[24] as int,
      dayLandings: fields[25] as int,
      nightLandings: fields[26] as int,
      flightLogId: fields[27] as String?,
      note: fields[28] as String?,
      imagePaths: (fields[29] as List?)?.cast<String>(),
      documentPaths: (fields[30] as List?)?.cast<String>(),
      trackingDuration: fields[31] as Duration?,
      movingDuration: fields[32] as Duration?,
      distance: fields[33] as double?,
      createdAt: fields[34] as DateTime?,
      updatedAt: fields[35] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LogBookEntry obj) {
    writer
      ..writeByte(36)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dateTimeStarted)
      ..writeByte(2)
      ..write(obj.dateTimeStartedMoving)
      ..writeByte(3)
      ..write(obj.departureAirport)
      ..writeByte(4)
      ..write(obj.dateTimeFinished)
      ..writeByte(5)
      ..write(obj.dateTimeFinishedMoving)
      ..writeByte(6)
      ..write(obj.arrivalAirport)
      ..writeByte(7)
      ..write(obj.engineType)
      ..writeByte(8)
      ..write(obj.aircraftType)
      ..writeByte(9)
      ..write(obj.aircraftIdentification)
      ..writeByte(10)
      ..write(obj.pilotInCommandId)
      ..writeByte(11)
      ..write(obj.secondInCommandId)
      ..writeByte(12)
      ..write(obj.flightTrainingNote)
      ..writeByte(13)
      ..write(obj.groundTrainingNote)
      ..writeByte(14)
      ..write(obj.simulatorNote)
      ..writeByte(15)
      ..write(obj.flightReview)
      ..writeByte(16)
      ..write(obj.ipc)
      ..writeByte(17)
      ..write(obj.checkRide)
      ..writeByte(18)
      ..write(obj.faa6158)
      ..writeByte(19)
      ..write(obj.nvgProficiency)
      ..writeByte(20)
      ..write(obj.flightCondition)
      ..writeByte(21)
      ..write(obj.flightRules)
      ..writeByte(22)
      ..write(obj.simulated)
      ..writeByte(23)
      ..write(obj.dayTakeoffs)
      ..writeByte(24)
      ..write(obj.nightTakeoffs)
      ..writeByte(25)
      ..write(obj.dayLandings)
      ..writeByte(26)
      ..write(obj.nightLandings)
      ..writeByte(27)
      ..write(obj.flightLogId)
      ..writeByte(28)
      ..write(obj.note)
      ..writeByte(29)
      ..write(obj.imagePaths)
      ..writeByte(30)
      ..write(obj.documentPaths)
      ..writeByte(31)
      ..write(obj.trackingDuration)
      ..writeByte(32)
      ..write(obj.movingDuration)
      ..writeByte(33)
      ..write(obj.distance)
      ..writeByte(34)
      ..write(obj.createdAt)
      ..writeByte(35)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogBookEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EngineTypeAdapter extends TypeAdapter<EngineType> {
  @override
  final int typeId = 52;

  @override
  EngineType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EngineType.singleEngine;
      case 1:
        return EngineType.multiEngine;
      default:
        return EngineType.singleEngine;
    }
  }

  @override
  void write(BinaryWriter writer, EngineType obj) {
    switch (obj) {
      case EngineType.singleEngine:
        writer.writeByte(0);
        break;
      case EngineType.multiEngine:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FlightConditionAdapter extends TypeAdapter<FlightCondition> {
  @override
  final int typeId = 53;

  @override
  FlightCondition read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FlightCondition.day;
      case 1:
        return FlightCondition.night;
      default:
        return FlightCondition.day;
    }
  }

  @override
  void write(BinaryWriter writer, FlightCondition obj) {
    switch (obj) {
      case FlightCondition.day:
        writer.writeByte(0);
        break;
      case FlightCondition.night:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightConditionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
