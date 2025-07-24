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
      'icao': airport.icao,
      'iata': airport.iata,
      'name': airport.name,
      'city': airport.city,
      'country': airport.country,
      'latitude': airport.latitude,
      'longitude': airport.longitude,
      'elevation': airport.elevation,
      'type': airport.type,
      'municipality': airport.municipality,
    };
  }

  @override
  Airport fromMap(Map<dynamic, dynamic> map) {
    return Airport(
      icao: map['icao'] as String? ?? '',
      iata: map['iata'] as String?,
      name: map['name'] as String? ?? 'Unknown',
      city: map['city'] as String? ?? '',
      country: map['country'] as String? ?? '',
      position: LatLng(
        (map['latitude'] as num?)?.toDouble() ?? 0.0,
        (map['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      elevation: (map['elevation'] as num?)?.toInt() ?? 0,
      type: map['type'] as String? ?? 'small_airport',
      municipality: map['municipality'] as String?,
    );
  }

  @override
  String getKey(Airport airport) => airport.icao;

  /// Cache airports with their data
  Future<void> cacheAirports(List<Airport> airports) async {
    await cacheItems(airports);
  }

  /// Get all cached airports
  Future<List<Airport>> getCachedAirports() async {
    return await getCachedItems();
  }
}