import 'package:latlong2/latlong.dart';
import '../../../models/airport.dart';
import '../models/cache_constants.dart';
import 'base_cache_repository.dart';

/// Repository for caching airport data
class AirportCacheRepository extends BaseCacheRepository<Airport> {
  AirportCacheRepository()
      : super(
          boxName: CacheConstants.airportsBoxName,
          lastFetchKey: CacheConstants.airportsLastFetchKey,
        );

  @override
  Map<String, dynamic> toMap(Airport airport) {
    return {
      'id': airport.id,
      'icao': airport.icao,
      'iata': airport.iata,
      'name': airport.name,
      'latitude': airport.latitude,
      'longitude': airport.longitude,
      'elevation': airport.elevation,
      'type': airport.type,
      'country': airport.country,
      'regionCode': airport.regionCode,
      'municipality': airport.municipality,
      'magneticDeclination': airport.magneticDeclination,
    };
  }

  @override
  Airport fromMap(Map<dynamic, dynamic> map) {
    return Airport(
      id: map['id'] as String,
      icao: map['icao'] as String?,
      iata: map['iata'] as String?,
      name: map['name'] as String,
      location: LatLng(
        map['latitude'] as double,
        map['longitude'] as double,
      ),
      elevation: (map['elevation'] as num?)?.toDouble(),
      type: map['type'] as String?,
      country: map['country'] as String?,
      regionCode: map['regionCode'] as String?,
      municipality: map['municipality'] as String?,
      magneticDeclination: (map['magneticDeclination'] as num?)?.toDouble(),
    );
  }

  @override
  String getKey(Airport airport) => airport.id;

  /// Cache airports with their data
  Future<void> cacheAirports(List<Airport> airports) async {
    await cacheItems(airports);
  }

  /// Get all cached airports
  Future<List<Airport>> getCachedAirports() async {
    return await getCachedItems();
  }
}