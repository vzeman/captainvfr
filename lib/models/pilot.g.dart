// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pilot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PilotAdapter extends TypeAdapter<Pilot> {
  @override
  final int typeId = 51;

  @override
  Pilot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Pilot(
      id: fields[0] as String?,
      name: fields[1] as String,
      birthdate: fields[2] as DateTime?,
      endorsementIds: (fields[3] as List?)?.cast<String>(),
      licenseIds: (fields[4] as List?)?.cast<String>(),
      isCurrentUser: fields[5] as bool,
      email: fields[6] as String?,
      phone: fields[7] as String?,
      certificateNumber: fields[8] as String?,
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Pilot obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.birthdate)
      ..writeByte(3)
      ..write(obj.endorsementIds)
      ..writeByte(4)
      ..write(obj.licenseIds)
      ..writeByte(5)
      ..write(obj.isCurrentUser)
      ..writeByte(6)
      ..write(obj.email)
      ..writeByte(7)
      ..write(obj.phone)
      ..writeByte(8)
      ..write(obj.certificateNumber)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PilotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
