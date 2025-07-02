// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'airplane.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AirplaneAdapter extends TypeAdapter<Airplane> {
  @override
  final int typeId = 23;

  @override
  Airplane read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Airplane(
      id: fields[0] as String,
      name: fields[1] as String,
      manufacturerId: fields[2] as String,
      airplaneTypeId: fields[3] as String,
      cruiseSpeed: fields[4] as double,
      fuelConsumption: fields[5] as double,
      maximumAltitude: fields[6] as double,
      maximumClimbRate: fields[7] as double,
      maximumDescentRate: fields[8] as double,
      maxTakeoffWeight: fields[9] as double,
      maxLandingWeight: fields[10] as double,
      fuelCapacity: fields[11] as double,
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
      registrationNumber: fields[12] as String?,
      description: fields[13] as String?,
      callSign: fields[16] as String?,
      registration: fields[17] as String?,
      manufacturer: fields[18] as String?,
      model: fields[19] as String?,
      category: fields[20] as AirplaneCategory?,
    );
  }

  @override
  void write(BinaryWriter writer, Airplane obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.manufacturerId)
      ..writeByte(3)
      ..write(obj.airplaneTypeId)
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
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AirplaneAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
