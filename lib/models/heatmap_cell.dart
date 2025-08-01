import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive/hive.dart';

part 'heatmap_cell.g.dart';

@HiveType(typeId: 55)
class HeatmapCell extends HiveObject {
  @HiveField(0)
  final String cellId;
  
  @HiveField(1)
  final int flightCount;
  
  @HiveField(2)
  final double intensity;
  
  @HiveField(3)
  final int zoomLevel;
  
  @HiveField(4)
  final double centerLat;
  
  @HiveField(5)
  final double centerLng;
  
  @HiveField(6)
  final double cellSize;
  
  @HiveField(7)
  final DateTime lastUpdate;
  
  @HiveField(8)
  final Set<String>? flightIds;

  HeatmapCell({
    required this.cellId,
    required this.flightCount,
    required this.intensity,
    required this.zoomLevel,
    required this.centerLat,
    required this.centerLng,
    required this.cellSize,
    required this.lastUpdate,
    this.flightIds,
  });

  LatLng get center => LatLng(centerLat, centerLng);
  
  LatLngBounds get bounds {
    final halfSize = cellSize / 2;
    return LatLngBounds(
      LatLng(centerLat - halfSize, centerLng - halfSize),
      LatLng(centerLat + halfSize, centerLng + halfSize),
    );
  }

  HeatmapCell copyWith({
    String? cellId,
    int? flightCount,
    double? intensity,
    int? zoomLevel,
    double? centerLat,
    double? centerLng,
    double? cellSize,
    DateTime? lastUpdate,
    Set<String>? flightIds,
  }) {
    return HeatmapCell(
      cellId: cellId ?? this.cellId,
      flightCount: flightCount ?? this.flightCount,
      intensity: intensity ?? this.intensity,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      cellSize: cellSize ?? this.cellSize,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      flightIds: flightIds ?? this.flightIds,
    );
  }
}