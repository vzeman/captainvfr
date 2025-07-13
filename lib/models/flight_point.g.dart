// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flight_point.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlightPointAdapter extends TypeAdapter<FlightPoint> {
  @override
  final int typeId = 1;

  @override
  FlightPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlightPoint(
      latitude: fields[0] as double?,
      longitude: fields[1] as double?,
      altitude: fields[2] as double?,
      speed: fields[3] as double?,
      heading: fields[4] as double?,
      accuracy: fields[5] as double? ?? 0.0,
      verticalAccuracy: fields[6] as double? ?? 0.0,
      speedAccuracy: fields[7] as double? ?? 0.0,
      headingAccuracy: fields[8] as double? ?? 0.0,
      xAcceleration: fields[9] as double? ?? 0.0,
      yAcceleration: fields[10] as double? ?? 0.0,
      zAcceleration: fields[11] as double? ?? 0.0,
      xGyro: fields[12] as double? ?? 0.0,
      yGyro: fields[13] as double? ?? 0.0,
      zGyro: fields[14] as double? ?? 0.0,
      pressure: fields[15] as double? ?? 0.0,
      verticalSpeed: fields[17] as double? ?? 0.0,
      timestamp: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FlightPoint obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.altitude)
      ..writeByte(3)
      ..write(obj.speed)
      ..writeByte(4)
      ..write(obj.heading)
      ..writeByte(5)
      ..write(obj.accuracy)
      ..writeByte(6)
      ..write(obj.verticalAccuracy)
      ..writeByte(7)
      ..write(obj.speedAccuracy)
      ..writeByte(8)
      ..write(obj.headingAccuracy)
      ..writeByte(9)
      ..write(obj.xAcceleration)
      ..writeByte(10)
      ..write(obj.yAcceleration)
      ..writeByte(11)
      ..write(obj.zAcceleration)
      ..writeByte(12)
      ..write(obj.xGyro)
      ..writeByte(13)
      ..write(obj.yGyro)
      ..writeByte(14)
      ..write(obj.zGyro)
      ..writeByte(15)
      ..write(obj.pressure)
      ..writeByte(16)
      ..write(obj.timestamp)
      ..writeByte(17)
      ..write(obj.verticalSpeed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlightPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
