import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../utils/spatial_index.dart';

part 'hotspot.g.dart';

@HiveType(typeId: 33)
class Hotspot extends HiveObject implements SpatialIndexable {
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
  final String? reliability;

  @HiveField(7)
  final String? occurrence;

  @HiveField(8)
  final String? conditions;

  @HiveField(9)
  final String? country;

  @HiveField(10)
  final String? description;

  Hotspot({
    required this.id,
    required this.name,
    this.type,
    required this.latitude,
    required this.longitude,
    this.elevationFt,
    this.reliability,
    this.occurrence,
    this.conditions,
    this.country,
    this.description,
  });

  LatLng get position => LatLng(latitude, longitude);

  String get elevationString {
    if (elevationFt == null) return '';
    return '$elevationFt ft MSL';
  }

  String get displayName {
    final typePrefix = type != null ? '[$type] ' : '';
    return '$typePrefix$name';
  }

  String get reliabilityString {
    if (reliability == null) return 'Unknown';
    switch (reliability?.toLowerCase()) {
      case 'high':
        return '⭐⭐⭐ High';
      case 'medium':
        return '⭐⭐ Medium';
      case 'low':
        return '⭐ Low';
      default:
        return reliability!;
    }
  }

  factory Hotspot.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] ?? {};
    final coordinates = geometry['coordinates'] ?? [0.0, 0.0];
    final properties = json['properties'] ?? json;

    return Hotspot(
      id: properties['_id']?.toString() ?? properties['id']?.toString() ?? '',
      name: properties['name']?.toString() ?? 'Unknown Hotspot',
      type: properties['type']?.toString(),
      latitude: (coordinates[1] ?? 0.0).toDouble(),
      longitude: (coordinates[0] ?? 0.0).toDouble(),
      elevationFt: properties['elevation'] != null 
          ? int.tryParse(properties['elevation'].toString()) 
          : null,
      reliability: properties['reliability']?.toString(),
      occurrence: properties['occurrence']?.toString(),
      conditions: properties['conditions']?.toString(),
      country: properties['country']?.toString(),
      description: properties['description']?.toString(),
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
      'reliability': reliability,
      'occurrence': occurrence,
      'conditions': conditions,
      'country': country,
      'description': description,
    };
  }

  @override
  String get uniqueId => id;

  @override
  LatLngBounds? get boundingBox {
    // Hotspots are points, so create a small bounding box around the position
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