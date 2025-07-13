// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flight.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlightAdapter extends TypeAdapter<Flight> {
  @override
  final int typeId = 0;

  @override
  Flight read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Flight(
      id: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime?,
      path: (fields[3] as List).cast<FlightPoint>(),
      maxAltitude: fields[4] as double,
      distanceTraveled: fields[5] as double,
      movingTime: fields[6] as Duration,
      maxSpeed: fields[7] as double,
      averageSpeed: fields[8] as double,
      recordingStartedZulu: fields[9] as DateTime,
      recordingStoppedZulu: fields[10] as DateTime?,
      movingStartedZulu: fields[11] as DateTime?,
      movingStoppedZulu: fields[12] as DateTime?,
      movingSegments: (fields[13] as List?)?.cast<MovingSegment>(),
      flightSegments: (fields[14] as List?)?.cast<FlightSegment>(),
      flightRules: fields[15] as FlightRules?,
    );
  }

  @override
  void write(BinaryWriter writer, Flight obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.path)
      ..writeByte(4)
      ..write(obj.maxAltitude)
      ..writeByte(5)
      ..write(obj.distanceTraveled)
      ..writeByte(6)
      ..write(obj.movingTime)
      ..writeByte(7)
      ..write(obj.maxSpeed)
      ..writeByte(8)
      ..write(obj.averageSpeed)
      ..writeByte(9)
      ..write(obj.recordingStartedZulu)
      ..writeByte(10)
      ..write(obj.recordingStoppedZulu)
      ..writeByte(11)
      ..write(obj.movingStartedZulu)
      ..writeByte(12)
      ..write(obj.movingStoppedZulu)
      ..writeByte(13)
      ..write(obj.movingSegments)
      ..writeByte(14)
      ..write(obj.flightSegments)
      ..writeByte(15)
      ..write(obj.flightRules);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
