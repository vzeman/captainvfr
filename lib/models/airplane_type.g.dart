// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'airplane_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AirplaneTypeAdapter extends TypeAdapter<AirplaneType> {
  @override
  final int typeId = 22;

  @override
  AirplaneType read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AirplaneType(
      id: fields[0] as String,
      name: fields[1] as String,
      manufacturerId: fields[2] as String,
      category: fields[3] as AirplaneCategory,
      engineCount: fields[4] as int,
      maxSeats: fields[5] as int,
      typicalCruiseSpeed: fields[6] as double,
      typicalServiceCeiling: fields[7] as double,
      description: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AirplaneType obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.manufacturerId)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.engineCount)
      ..writeByte(5)
      ..write(obj.maxSeats)
      ..writeByte(6)
      ..write(obj.typicalCruiseSpeed)
      ..writeByte(7)
      ..write(obj.typicalServiceCeiling)
      ..writeByte(8)
      ..write(obj.description)
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
      other is AirplaneTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AirplaneCategoryAdapter extends TypeAdapter<AirplaneCategory> {
  @override
  final int typeId = 24;

  @override
  AirplaneCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AirplaneCategory.singleEngine;
      case 1:
        return AirplaneCategory.multiEngine;
      case 2:
        return AirplaneCategory.jet;
      case 3:
        return AirplaneCategory.helicopter;
      case 4:
        return AirplaneCategory.glider;
      case 5:
        return AirplaneCategory.turboprop;
      default:
        return AirplaneCategory.singleEngine;
    }
  }

  @override
  void write(BinaryWriter writer, AirplaneCategory obj) {
    switch (obj) {
      case AirplaneCategory.singleEngine:
        writer.writeByte(0);
        break;
      case AirplaneCategory.multiEngine:
        writer.writeByte(1);
        break;
      case AirplaneCategory.jet:
        writer.writeByte(2);
        break;
      case AirplaneCategory.helicopter:
        writer.writeByte(3);
        break;
      case AirplaneCategory.glider:
        writer.writeByte(4);
        break;
      case AirplaneCategory.turboprop:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AirplaneCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
