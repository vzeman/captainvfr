// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'heatmap_cell.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HeatmapCellAdapter extends TypeAdapter<HeatmapCell> {
  @override
  final int typeId = 55;

  @override
  HeatmapCell read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HeatmapCell(
      cellId: fields[0] as String,
      flightCount: fields[1] as int,
      intensity: fields[2] as double,
      zoomLevel: fields[3] as int,
      centerLat: fields[4] as double,
      centerLng: fields[5] as double,
      cellSize: fields[6] as double,
      lastUpdate: fields[7] as DateTime,
      flightIds: (fields[8] as Set?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, HeatmapCell obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.cellId)
      ..writeByte(1)
      ..write(obj.flightCount)
      ..writeByte(2)
      ..write(obj.intensity)
      ..writeByte(3)
      ..write(obj.zoomLevel)
      ..writeByte(4)
      ..write(obj.centerLat)
      ..writeByte(5)
      ..write(obj.centerLng)
      ..writeByte(6)
      ..write(obj.cellSize)
      ..writeByte(7)
      ..write(obj.lastUpdate)
      ..writeByte(8)
      ..write(obj.flightIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeatmapCellAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}