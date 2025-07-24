import 'package:latlong2/latlong.dart';
import '../../../models/navaid.dart';
import '../models/cache_constants.dart';
import 'base_cache_repository.dart';

/// Repository for caching navaid data
class NavaidCacheRepository extends BaseCacheRepository<Navaid> {
  NavaidCacheRepository()
      : super(
          boxName: CacheConstants.navaidsBoxName,
          lastFetchKey: CacheConstants.navaidsLastFetchKey,
        );

  @override
  Map<String, dynamic> toMap(Navaid navaid) {
    return navaid.toMap();
  }

  @override
  Navaid fromMap(Map<dynamic, dynamic> map) {
    return Navaid(
      id: map['id'] as String,
      name: map['name'] as String,
      ident: map['ident'] as String,
      type: map['type'] as String,
      location: LatLng(
        map['latitude'] as double,
        map['longitude'] as double,
      ),
      elevation: (map['elevation'] as num?)?.toDouble(),
      frequency: (map['frequency'] as num?)?.toDouble(),
      channel: map['channel'] as String?,
      usage: map['usage'] as String?,
      remarks: map['remarks'] as String?,
      power: map['power'] as String?,
      magneticDeclination: (map['magneticDeclination'] as num?)?.toDouble(),
    );
  }

  @override
  String getKey(Navaid navaid) => navaid.id;

  /// Cache navaids with their data
  Future<void> cacheNavaids(List<Navaid> navaids) async {
    await cacheItems(navaids);
  }

  /// Get all cached navaids
  Future<List<Navaid>> getCachedNavaids() async {
    return await getCachedItems();
  }
}