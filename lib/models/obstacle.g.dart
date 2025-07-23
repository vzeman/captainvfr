// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'obstacle.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ObstacleAdapter extends TypeAdapter<Obstacle> {
  @override
  final int typeId = 32;

  @override
  Obstacle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Obstacle(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String?,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      elevationFt: fields[5] as int?,
      heightFt: fields[6] as int?,
      lighted: fields[7] as bool,
      marking: fields[8] as String?,
      country: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Obstacle obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.latitude)
      ..writeByte(4)
      ..write(obj.longitude)
      ..writeByte(5)
      ..write(obj.elevationFt)
      ..writeByte(6)
      ..write(obj.heightFt)
      ..writeByte(7)
      ..write(obj.lighted)
      ..writeByte(8)
      ..write(obj.marking)
      ..writeByte(9)
      ..write(obj.country);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObstacleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
