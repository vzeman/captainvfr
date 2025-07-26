// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'endorsement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EndorsementAdapter extends TypeAdapter<Endorsement> {
  @override
  final int typeId = 50;

  @override
  Endorsement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Endorsement(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String,
      validFrom: fields[3] as DateTime,
      validTo: fields[4] as DateTime?,
      createdAt: fields[5] as DateTime?,
      updatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Endorsement obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.validFrom)
      ..writeByte(4)
      ..write(obj.validTo)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EndorsementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
