// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manufacturer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ManufacturerAdapter extends TypeAdapter<Manufacturer> {
  @override
  final int typeId = 21;

  @override
  Manufacturer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Manufacturer(
      id: fields[0] as String,
      name: fields[1] as String,
      website: fields[3] as String?,
      description: fields[5] as String?,
      models: (fields[4] as List?)?.cast<String>(),
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Manufacturer obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.website)
      ..writeByte(4)
      ..write(obj.models)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManufacturerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
