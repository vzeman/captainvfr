// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moving_segment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MovingSegmentAdapter extends TypeAdapter<MovingSegment> {
  @override
  final int typeId = 3;

  @override
  MovingSegment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MovingSegment(
      start: fields[0] as DateTime,
      end: fields[1] as DateTime,
      duration: fields[2] as Duration,
      distance: fields[3] as double,
      averageSpeed: fields[4] as double,
      averageHeading: fields[5] as double,
      startAltitude: fields[6] as double,
      endAltitude: fields[7] as double,
      averageAltitude: fields[8] as double,
      maxAltitude: fields[9] as double,
      minAltitude: fields[10] as double,
    );
  }

  @override
  void write(BinaryWriter writer, MovingSegment obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.start)
      ..writeByte(1)
      ..write(obj.end)
      ..writeByte(2)
      ..write(obj.duration)
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
      ..write(obj.minAltitude);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovingSegmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
