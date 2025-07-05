// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'airspace.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AirspaceAdapter extends TypeAdapter<Airspace> {
  @override
  final int typeId = 30;

  @override
  Airspace read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Airspace(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String?,
      icaoClass: fields[3] as String?,
      activity: fields[4] as String?,
      lowerLimitFt: fields[5] as double?,
      upperLimitFt: fields[6] as double?,
      lowerLimitReference: fields[7] as String?,
      upperLimitReference: fields[8] as String?,
      geometry: (fields[9] as List).cast<LatLng>(),
      country: fields[10] as String?,
      onDemand: fields[11] as bool?,
      onRequest: fields[12] as bool?,
      byNotam: fields[13] as bool?,
      validFrom: fields[14] as DateTime?,
      validTo: fields[15] as DateTime?,
      remarks: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Airspace obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.icaoClass)
      ..writeByte(4)
      ..write(obj.activity)
      ..writeByte(5)
      ..write(obj.lowerLimitFt)
      ..writeByte(6)
      ..write(obj.upperLimitFt)
      ..writeByte(7)
      ..write(obj.lowerLimitReference)
      ..writeByte(8)
      ..write(obj.upperLimitReference)
      ..writeByte(9)
      ..write(obj.geometry)
      ..writeByte(10)
      ..write(obj.country)
      ..writeByte(11)
      ..write(obj.onDemand)
      ..writeByte(12)
      ..write(obj.onRequest)
      ..writeByte(13)
      ..write(obj.byNotam)
      ..writeByte(14)
      ..write(obj.validFrom)
      ..writeByte(15)
      ..write(obj.validTo)
      ..writeByte(16)
      ..write(obj.remarks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AirspaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
