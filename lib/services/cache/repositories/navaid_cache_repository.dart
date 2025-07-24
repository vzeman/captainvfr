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
    return Navaid.fromMap(Map<String, dynamic>.from(map));
  }

  @override
  String getKey(Navaid navaid) => navaid.id.toString();

  /// Cache navaids with their data
  Future<void> cacheNavaids(List<Navaid> navaids) async {
    await cacheItems(navaids);
  }

  /// Get all cached navaids
  Future<List<Navaid>> getCachedNavaids() async {
    return await getCachedItems();
  }
}