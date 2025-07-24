import '../../../models/runway.dart';
import '../models/cache_constants.dart';
import 'base_cache_repository.dart';

/// Repository for caching runway data
class RunwayCacheRepository extends BaseCacheRepository<Runway> {
  RunwayCacheRepository()
      : super(
          boxName: CacheConstants.runwaysBoxName,
          lastFetchKey: CacheConstants.runwaysLastFetchKey,
        );

  @override
  Map<String, dynamic> toMap(Runway runway) {
    return runway.toJson();
  }

  @override
  Runway fromMap(Map<dynamic, dynamic> map) {
    return Runway.fromJson(Map<String, dynamic>.from(map));
  }

  @override
  String getKey(Runway runway) => runway.id;

  /// Cache runways with their data
  Future<void> cacheRunways(List<Runway> runways) async {
    await cacheItems(runways);
  }

  /// Get all cached runways
  Future<List<Runway>> getCachedRunways() async {
    return await getCachedItems();
  }
}