// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aircraft.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AircraftAdapter extends TypeAdapter<Aircraft> {
  @override
  final int typeId = 23;

  @override
  Aircraft read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Aircraft(
      id: fields[0] as String,
      name: fields[1] as String,
      manufacturerId: fields[2] as String,
      modelId: fields[3] as String,
      cruiseSpeed: fields[4] as int,
      fuelConsumption: fields[5] as double,
      maximumAltitude: fields[6] as int,
      maximumClimbRate: fields[7] as int,
      maximumDescentRate: fields[8] as int,
      maxTakeoffWeight: fields[9] as int,
      maxLandingWeight: fields[10] as int,
      fuelCapacity: fields[11] as int,
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
      registrationNumber: fields[12] as String?,
      description: fields[13] as String?,
      callSign: fields[16] as String?,
      registration: fields[17] as String?,
      manufacturer: fields[18] as String?,
      model: fields[19] as String?,
      category: fields[20] as AircraftCategory?,
      photosPaths: (fields[21] as List?)?.cast<String>(),
      documentsPaths: (fields[22] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Aircraft obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.manufacturerId)
      ..writeByte(3)
      ..write(obj.modelId)
      ..writeByte(4)
      ..write(obj.cruiseSpeed)
      ..writeByte(5)
      ..write(obj.fuelConsumption)
      ..writeByte(6)
      ..write(obj.maximumAltitude)
      ..writeByte(7)
      ..write(obj.maximumClimbRate)
      ..writeByte(8)
      ..write(obj.maximumDescentRate)
      ..writeByte(9)
      ..write(obj.maxTakeoffWeight)
      ..writeByte(10)
      ..write(obj.maxLandingWeight)
      ..writeByte(11)
      ..write(obj.fuelCapacity)
      ..writeByte(12)
      ..write(obj.registrationNumber)
      ..writeByte(13)
      ..write(obj.description)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt)
      ..writeByte(16)
      ..write(obj.callSign)
      ..writeByte(17)
      ..write(obj.registration)
      ..writeByte(18)
      ..write(obj.manufacturer)
      ..writeByte(19)
      ..write(obj.model)
      ..writeByte(20)
      ..write(obj.category)
      ..writeByte(21)
      ..write(obj.photosPaths)
      ..writeByte(22)
      ..write(obj.documentsPaths);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AircraftAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
