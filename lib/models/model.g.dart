// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ModelAdapter extends TypeAdapter<Model> {
  @override
  final int typeId = 24;

  @override
  Model read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Model(
      id: fields[0] as String,
      name: fields[1] as String,
      manufacturerId: fields[2] as String,
      category: fields[3] as AircraftCategory,
      engineCount: fields[4] as int,
      maxSeats: fields[5] as int,
      typicalCruiseSpeed: fields[6] as int,
      typicalServiceCeiling: fields[7] as int,
      description: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
      fuelConsumption: fields[11] as double?,
      maximumClimbRate: fields[12] as int?,
      maximumDescentRate: fields[13] as int?,
      maxTakeoffWeight: fields[14] as int?,
      maxLandingWeight: fields[15] as int?,
      fuelCapacity: fields[16] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Model obj) {
    writer
      ..writeByte(17)
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
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.fuelConsumption)
      ..writeByte(12)
      ..write(obj.maximumClimbRate)
      ..writeByte(13)
      ..write(obj.maximumDescentRate)
      ..writeByte(14)
      ..write(obj.maxTakeoffWeight)
      ..writeByte(15)
      ..write(obj.maxLandingWeight)
      ..writeByte(16)
      ..write(obj.fuelCapacity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AircraftCategoryAdapter extends TypeAdapter<AircraftCategory> {
  @override
  final int typeId = 22;

  @override
  AircraftCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AircraftCategory.singleEngine;
      case 1:
        return AircraftCategory.multiEngine;
      case 2:
        return AircraftCategory.jet;
      case 3:
        return AircraftCategory.helicopter;
      case 4:
        return AircraftCategory.glider;
      case 5:
        return AircraftCategory.turboprop;
      default:
        return AircraftCategory.singleEngine;
    }
  }

  @override
  void write(BinaryWriter writer, AircraftCategory obj) {
    switch (obj) {
      case AircraftCategory.singleEngine:
        writer.writeByte(0);
        break;
      case AircraftCategory.multiEngine:
        writer.writeByte(1);
        break;
      case AircraftCategory.jet:
        writer.writeByte(2);
        break;
      case AircraftCategory.helicopter:
        writer.writeByte(3);
        break;
      case AircraftCategory.glider:
        writer.writeByte(4);
        break;
      case AircraftCategory.turboprop:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AircraftCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
