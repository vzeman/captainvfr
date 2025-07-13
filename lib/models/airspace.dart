import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

part 'airspace.g.dart';

@HiveType(typeId: 30)
class Airspace extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? type;

  @HiveField(3)
  final String? icaoClass;

  @HiveField(4)
  final String? activity;

  @HiveField(5)
  final double? lowerLimitFt;

  @HiveField(6)
  final double? upperLimitFt;

  @HiveField(7)
  final String? lowerLimitReference;

  @HiveField(8)
  final String? upperLimitReference;

  @HiveField(9)
  final List<LatLng> geometry;

  @HiveField(10)
  final String? country;

  @HiveField(11)
  final bool? onDemand;

  @HiveField(12)
  final bool? onRequest;

  @HiveField(13)
  final bool? byNotam;

  @HiveField(14)
  final DateTime? validFrom;

  @HiveField(15)
  final DateTime? validTo;

  @HiveField(16)
  final String? remarks;

  Airspace({
    required this.id,
    required this.name,
    this.type,
    this.icaoClass,
    this.activity,
    this.lowerLimitFt,
    this.upperLimitFt,
    this.lowerLimitReference,
    this.upperLimitReference,
    required this.geometry,
    this.country,
    this.onDemand,
    this.onRequest,
    this.byNotam,
    this.validFrom,
    this.validTo,
    this.remarks,
  });

  factory Airspace.fromJson(Map<String, dynamic> json) {
    List<LatLng> parseGeometry(dynamic geometryData) {
      final List<LatLng> points = [];

      if (geometryData != null && geometryData['coordinates'] != null) {
        final coordinates = geometryData['coordinates'];

        if (geometryData['type'] == 'Polygon' && coordinates is List) {
          final ring = coordinates.first as List;
          for (final coord in ring) {
            if (coord is List && coord.length >= 2) {
              points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
            }
          }
        } else if (geometryData['type'] == 'MultiPolygon' &&
            coordinates is List) {
          for (final polygon in coordinates) {
            if (polygon is List && polygon.isNotEmpty) {
              final ring = polygon.first as List;
              for (final coord in ring) {
                if (coord is List && coord.length >= 2) {
                  points.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
                }
              }
            }
          }
        }
      }

      return points;
    }

    double? parseAltitude(dynamic limit) {
      if (limit == null) return null;
      if (limit is num) return limit.toDouble();
      if (limit is Map && limit['value'] != null) {
        return (limit['value'] as num).toDouble();
      }
      return null;
    }

    String? parseAltitudeReference(dynamic limit) {
      if (limit == null) return null;
      if (limit is Map && limit['reference'] != null) {
        return limit['reference'].toString();
      }
      return 'MSL';
    }

    // Generate a unique ID if none provided
    // Check both '_id' and 'id' fields - OpenAIP uses '_id' as the primary identifier
    String airspaceId = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    if (airspaceId.isEmpty) {
      // Create a unique ID based on name, type, and geometry hash
      final name = json['name']?.toString() ?? 'unknown';
      final type = json['type']?.toString() ?? 'unknown';
      final geometryHash = parseGeometry(json['geometry']).hashCode;
      airspaceId = 'generated_${name}_${type}_$geometryHash';
    }

    return Airspace(
      id: airspaceId,
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString(),
      icaoClass: json['icaoClass']?.toString(),
      activity: json['activity']?.toString(),
      lowerLimitFt: parseAltitude(json['lowerLimit']),
      upperLimitFt: parseAltitude(json['upperLimit']),
      lowerLimitReference: parseAltitudeReference(json['lowerLimit']),
      upperLimitReference: parseAltitudeReference(json['upperLimit']),
      geometry: parseGeometry(json['geometry']),
      country: json['country']?.toString(),
      onDemand: json['onDemand'] == true,
      onRequest: json['onRequest'] == true,
      byNotam: json['byNotam'] == true,
      validFrom: json['validFrom'] != null
          ? DateTime.tryParse(json['validFrom'])
          : null,
      validTo: json['validTo'] != null
          ? DateTime.tryParse(json['validTo'])
          : null,
      remarks: json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icaoClass': icaoClass,
      'activity': activity,
      'lowerLimit': lowerLimitFt != null
          ? {'value': lowerLimitFt, 'reference': lowerLimitReference ?? 'MSL'}
          : null,
      'upperLimit': upperLimitFt != null
          ? {'value': upperLimitFt, 'reference': upperLimitReference ?? 'MSL'}
          : null,
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          geometry.map((p) => [p.longitude, p.latitude]).toList(),
        ],
      },
      'country': country,
      'onDemand': onDemand,
      'onRequest': onRequest,
      'byNotam': byNotam,
      'validFrom': validFrom?.toIso8601String(),
      'validTo': validTo?.toIso8601String(),
      'remarks': remarks,
    };
  }

  String get formattedLowerLimit {
    if (lowerLimitFt == null) return 'GND';
    final ref = lowerLimitReference ?? 'MSL';
    return '${lowerLimitFt!.toStringAsFixed(0)} ft $ref';
  }

  String get formattedUpperLimit {
    if (upperLimitFt == null) return 'UNL';
    final ref = upperLimitReference ?? 'MSL';
    return '${upperLimitFt!.toStringAsFixed(0)} ft $ref';
  }

  String get altitudeRange => '$formattedLowerLimit - $formattedUpperLimit';

  // Cached bounding box for performance
  late final LatLngBounds? _boundingBox = _calculateBoundingBox();

  LatLngBounds? get boundingBox => _boundingBox;

  LatLngBounds? _calculateBoundingBox() {
    if (geometry.isEmpty) return null;

    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;

    for (final point in geometry) {
      minLat = minLat > point.latitude ? point.latitude : minLat;
      maxLat = maxLat < point.latitude ? point.latitude : maxLat;
      minLon = minLon > point.longitude ? point.longitude : minLon;
      maxLon = maxLon < point.longitude ? point.longitude : maxLon;
    }

    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }

  bool containsPoint(LatLng point) {
    if (geometry.isEmpty) return false;

    int intersections = 0;
    for (int i = 0; i < geometry.length; i++) {
      final p1 = geometry[i];
      final p2 = geometry[(i + 1) % geometry.length];

      if (p1.latitude <= point.latitude) {
        if (p2.latitude > point.latitude) {
          if (_isLeft(p1, p2, point) > 0) {
            intersections++;
          }
        }
      } else {
        if (p2.latitude <= point.latitude) {
          if (_isLeft(p1, p2, point) < 0) {
            intersections++;
          }
        }
      }
    }

    return intersections % 2 == 1;
  }

  double _isLeft(LatLng p0, LatLng p1, LatLng p2) {
    return ((p1.longitude - p0.longitude) * (p2.latitude - p0.latitude) -
        (p2.longitude - p0.longitude) * (p1.latitude - p0.latitude));
  }

  bool isActiveAt(DateTime dateTime) {
    if (validFrom != null && dateTime.isBefore(validFrom!)) return false;
    if (validTo != null && dateTime.isAfter(validTo!)) return false;
    return true;
  }

  bool isAtAltitude(double altitudeFt, {String reference = 'MSL'}) {
    if (lowerLimitFt != null && altitudeFt < lowerLimitFt!) return false;
    if (upperLimitFt != null && altitudeFt > upperLimitFt!) return false;
    return true;
  }

  Airspace copyWith({
    String? id,
    String? name,
    String? type,
    String? icaoClass,
    String? activity,
    double? lowerLimitFt,
    double? upperLimitFt,
    String? lowerLimitReference,
    String? upperLimitReference,
    List<LatLng>? geometry,
    String? country,
    bool? onDemand,
    bool? onRequest,
    bool? byNotam,
    DateTime? validFrom,
    DateTime? validTo,
    String? remarks,
  }) {
    return Airspace(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icaoClass: icaoClass ?? this.icaoClass,
      activity: activity ?? this.activity,
      lowerLimitFt: lowerLimitFt ?? this.lowerLimitFt,
      upperLimitFt: upperLimitFt ?? this.upperLimitFt,
      lowerLimitReference: lowerLimitReference ?? this.lowerLimitReference,
      upperLimitReference: upperLimitReference ?? this.upperLimitReference,
      geometry: geometry ?? this.geometry,
      country: country ?? this.country,
      onDemand: onDemand ?? this.onDemand,
      onRequest: onRequest ?? this.onRequest,
      byNotam: byNotam ?? this.byNotam,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      remarks: remarks ?? this.remarks,
    );
  }
}
