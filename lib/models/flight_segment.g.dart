// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flight_segment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlightSegmentAdapter extends TypeAdapter<FlightSegment> {
  @override
  final int typeId = 4;

  @override
  FlightSegment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlightSegment(
      startTime: fields[0] as DateTime,
      endTime: fields[1] as DateTime,
      points: (fields[2] as List).cast<FlightPoint>(),
      distance: fields[3] as double,
      averageSpeed: fields[4] as double,
      averageHeading: fields[5] as double,
      startAltitude: fields[6] as double,
      endAltitude: fields[7] as double,
      averageAltitude: fields[8] as double,
      maxAltitude: fields[9] as double,
      minAltitude: fields[10] as double,
      type: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FlightSegment obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.startTime)
      ..writeByte(1)
      ..write(obj.endTime)
      ..writeByte(2)
      ..write(obj.points)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.averageSpeed)
      ..writeByte(5)
      ..write(obj.averageHeading)
      ..writeByte(6)
      ..write(obj.startAltitude)
      ..writeByte(7)
      ..write(obj.endAltitude)
      ..writeByte(8)
      ..write(obj.averageAltitude)
      ..writeByte(9)
      ..write(obj.maxAltitude)
      ..writeByte(10)
      ..write(obj.minAltitude)
      ..writeByte(11)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightSegmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
