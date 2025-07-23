// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hotspot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HotspotAdapter extends TypeAdapter<Hotspot> {
  @override
  final int typeId = 33;

  @override
  Hotspot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Hotspot(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String?,
      latitude: fields[3] as double,
      longitude: fields[4] as double,
      elevationFt: fields[5] as int?,
      reliability: fields[6] as String?,
      occurrence: fields[7] as String?,
      conditions: fields[8] as String?,
      country: fields[9] as String?,
      description: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Hotspot obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.reliability)
      ..writeByte(7)
      ..write(obj.occurrence)
      ..writeByte(8)
      ..write(obj.conditions)
      ..writeByte(9)
      ..write(obj.country)
      ..writeByte(10)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HotspotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
