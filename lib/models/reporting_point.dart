import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

part 'reporting_point.g.dart';

@HiveType(typeId: 31)
class ReportingPoint extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? type;

  @HiveField(3)
  final String? country;

  @HiveField(4)
  final String? state;

  @HiveField(5)
  final double latitude;

  @HiveField(6)
  final double longitude;

  @HiveField(7)
  final double? elevationM;

  @HiveField(8)
  final String? elevationUnit;

  @HiveField(9)
  final String? elevationReference;

  @HiveField(10)
  final List<String>? tags;

  @HiveField(11)
  final String? description;

  @HiveField(12)
  final String? remarks;

  @HiveField(13)
  final String? airportId;

  @HiveField(14)
  final String? airportName;

  ReportingPoint({
    required this.id,
    required this.name,
    this.type,
    this.country,
    this.state,
    required this.latitude,
    required this.longitude,
    this.elevationM,
    this.elevationUnit,
    this.elevationReference,
    this.tags,
    this.description,
    this.remarks,
    this.airportId,
    this.airportName,
  });

  LatLng get position => LatLng(latitude, longitude);

  String get elevationString {
    if (elevationM == null) return '';

    final value = elevationUnit == 'ft'
        ? elevationM!.round().toString()
        : (elevationM! * 3.28084).round().toString();

    final reference = elevationReference ?? 'MSL';
    return '$value ft $reference';
  }

  String get displayName {
    final typePrefix = type != null ? '[$type] ' : '';
    return '$typePrefix$name';
  }

  factory ReportingPoint.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] ?? {};
    final coordinates = geometry['coordinates'] ?? [0.0, 0.0];
    final elevation = json['elevation'] ?? {};

    return ReportingPoint(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      type: json['type']?.toString(),
      country: json['country']?.toString(),
      state: json['state']?.toString(),
      latitude: (coordinates[1] ?? 0.0).toDouble(),
      longitude: (coordinates[0] ?? 0.0).toDouble(),
      elevationM: elevation['value']?.toDouble(),
      elevationUnit: elevation['unit']?.toString(),
      elevationReference:
          (elevation['referenceDatum'] ?? elevation['reference'])?.toString(),
      tags: json['tags'] != null
          ? (json['tags'] as List).map((tag) => tag.toString()).toList()
          : null,
      description: json['description']?.toString(),
      remarks: json['remarks']?.toString(),
      airportId: (json['airportId'] ?? json['airport'])?.toString(),
      airportName: json['airportName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'type': type,
      'country': country,
      'state': state,
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'elevation': elevationM != null
          ? {
              'value': elevationM,
              'unit': elevationUnit ?? 'm',
              'referenceDatum': elevationReference ?? 'MSL',
            }
          : null,
      'tags': tags,
      'description': description,
      'remarks': remarks,
      'airportId': airportId,
      'airportName': airportName,
    };
  }
}
