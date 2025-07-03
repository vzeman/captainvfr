// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChecklistAdapter extends TypeAdapter<Checklist> {
  @override
  final int typeId = 26;

  @override
  Checklist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Checklist(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      manufacturerId: fields[3] as String,
      modelId: fields[4] as String,
      items: (fields[5] as List?)?.cast<ChecklistItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, Checklist obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.manufacturerId)
      ..writeByte(4)
      ..write(obj.modelId)
      ..writeByte(5)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
