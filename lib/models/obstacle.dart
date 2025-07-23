import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../utils/spatial_index.dart';

part 'obstacle.g.dart';

@HiveType(typeId: 32)
class Obstacle extends HiveObject implements SpatialIndexable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? type;

  @HiveField(3)
  final double latitude;

  @HiveField(4)
  final double longitude;

  @HiveField(5)
  final int? elevationFt;

  @HiveField(6)
  final int? heightFt;

  @HiveField(7)
  final bool lighted;

  @HiveField(8)
  final String? marking;

  @HiveField(9)
  final String? country;

  Obstacle({
    required this.id,
    required this.name,
    this.type,
    required this.latitude,
    required this.longitude,
    this.elevationFt,
    this.heightFt,
    this.lighted = false,
    this.marking,
    this.country,
  });

  LatLng get position => LatLng(latitude, longitude);

  int get totalHeightFt => (elevationFt ?? 0) + (heightFt ?? 0);

  String get heightString {
    if (heightFt == null && elevationFt == null) return '';
    
    final parts = <String>[];
    if (heightFt != null) parts.add('Height: $heightFt ft');
    if (elevationFt != null) parts.add('Elevation: $elevationFt ft');
    parts.add('Total: $totalHeightFt ft');
    
    return parts.join(' | ');
  }

  String get displayName {
    final typePrefix = type != null ? '[$type] ' : '';
    return '$typePrefix$name';
  }

  factory Obstacle.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] ?? {};
    final coordinates = geometry['coordinates'] ?? [0.0, 0.0];
    final properties = json['properties'] ?? json;

    return Obstacle(
      id: properties['_id']?.toString() ?? properties['id']?.toString() ?? '',
      name: properties['name']?.toString() ?? 'Unknown Obstacle',
      type: properties['type']?.toString(),
      latitude: (coordinates[1] ?? 0.0).toDouble(),
      longitude: (coordinates[0] ?? 0.0).toDouble(),
      elevationFt: properties['elevation'] != null 
          ? int.tryParse(properties['elevation'].toString()) 
          : null,
      heightFt: properties['height'] != null 
          ? int.tryParse(properties['height'].toString()) 
          : null,
      lighted: properties['lighted'] == 1 || properties['lighted'] == true,
      marking: properties['marking']?.toString(),
      country: properties['country']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'type': type,
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'elevation': elevationFt,
      'height': heightFt,
      'lighted': lighted ? 1 : 0,
      'marking': marking,
      'country': country,
    };
  }

  @override
  String get uniqueId => id;

  @override
  LatLngBounds? get boundingBox {
    // Obstacles are points, so create a small bounding box around the position
    const delta = 0.001; // Small delta for point features
    return LatLngBounds(
      LatLng(position.latitude - delta, position.longitude - delta),
      LatLng(position.latitude + delta, position.longitude + delta),
    );
  }

  @override
  bool containsPoint(LatLng point) {
    // For point features, check if the point is very close
    const tolerance = 0.001;
    return (point.latitude - position.latitude).abs() < tolerance &&
           (point.longitude - position.longitude).abs() < tolerance;
  }
}