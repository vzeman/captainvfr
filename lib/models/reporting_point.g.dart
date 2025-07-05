// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reporting_point.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReportingPointAdapter extends TypeAdapter<ReportingPoint> {
  @override
  final int typeId = 31;

  @override
  ReportingPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportingPoint(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String?,
      country: fields[3] as String?,
      state: fields[4] as String?,
      latitude: fields[5] as double,
      longitude: fields[6] as double,
      elevationM: fields[7] as double?,
      elevationUnit: fields[8] as String?,
      elevationReference: fields[9] as String?,
      tags: (fields[10] as List?)?.cast<String>(),
      description: fields[11] as String?,
      remarks: fields[12] as String?,
      airportId: fields[13] as String?,
      airportName: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReportingPoint obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.country)
      ..writeByte(4)
      ..write(obj.state)
      ..writeByte(5)
      ..write(obj.latitude)
      ..writeByte(6)
      ..write(obj.longitude)
      ..writeByte(7)
      ..write(obj.elevationM)
      ..writeByte(8)
      ..write(obj.elevationUnit)
      ..writeByte(9)
      ..write(obj.elevationReference)
      ..writeByte(10)
      ..write(obj.tags)
      ..writeByte(11)
      ..write(obj.description)
      ..writeByte(12)
      ..write(obj.remarks)
      ..writeByte(13)
      ..write(obj.airportId)
      ..writeByte(14)
      ..write(obj.airportName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportingPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
