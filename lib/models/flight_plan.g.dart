// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flight_plan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlightPlanAdapter extends TypeAdapter<FlightPlan> {
  @override
  final int typeId = 10;

  @override
  FlightPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlightPlan(
      id: fields[0] as String,
      name: fields[1] as String,
      createdAt: fields[2] as DateTime,
      modifiedAt: fields[3] as DateTime?,
      waypoints: (fields[4] as List).cast<Waypoint>(),
      aircraftId: fields[5] as String?,
      cruiseSpeed: fields[6] as double?,
      flightRules: fields[7] as FlightRules?,
      fuelConsumptionRate: fields[8] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, FlightPlan obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.modifiedAt)
      ..writeByte(4)
      ..write(obj.waypoints)
      ..writeByte(5)
      ..write(obj.aircraftId)
      ..writeByte(6)
      ..write(obj.cruiseSpeed)
      ..writeByte(7)
      ..write(obj.flightRules)
      ..writeByte(8)
      ..write(obj.fuelConsumptionRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WaypointAdapter extends TypeAdapter<Waypoint> {
  @override
  final int typeId = 11;

  @override
  Waypoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Waypoint(
      id: fields[0] as String,
      latitude: fields[1] as double,
      longitude: fields[2] as double,
      altitude: fields[3] as double,
      name: fields[4] as String?,
      notes: fields[5] as String?,
      type: fields[6] as WaypointType,
    );
  }

  @override
  void write(BinaryWriter writer, Waypoint obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.latitude)
      ..writeByte(2)
      ..write(obj.longitude)
      ..writeByte(3)
      ..write(obj.altitude)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WaypointTypeAdapter extends TypeAdapter<WaypointType> {
  @override
  final int typeId = 12;

  @override
  WaypointType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WaypointType.user;
      case 1:
        return WaypointType.airport;
      case 2:
        return WaypointType.navaid;
      case 3:
        return WaypointType.fix;
      case 4:
        return WaypointType.reportingPoint;
      default:
        return WaypointType.user;
    }
  }

  @override
  void write(BinaryWriter writer, WaypointType obj) {
    switch (obj) {
      case WaypointType.user:
        writer.writeByte(0);
        break;
      case WaypointType.airport:
        writer.writeByte(1);
        break;
      case WaypointType.navaid:
        writer.writeByte(2);
        break;
      case WaypointType.fix:
        writer.writeByte(3);
        break;
      case WaypointType.reportingPoint:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FlightRulesAdapter extends TypeAdapter<FlightRules> {
  @override
  final int typeId = 13;

  @override
  FlightRules read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FlightRules.vfr;
      case 1:
        return FlightRules.ifr;
      default:
        return FlightRules.vfr;
    }
  }

  @override
  void write(BinaryWriter writer, FlightRules obj) {
    switch (obj) {
      case FlightRules.vfr:
        writer.writeByte(0);
        break;
      case FlightRules.ifr:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightRulesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
