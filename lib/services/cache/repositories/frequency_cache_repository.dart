import '../../../models/frequency.dart';
import '../models/cache_constants.dart';
import 'base_cache_repository.dart';

/// Repository for caching frequency data
class FrequencyCacheRepository extends BaseCacheRepository<Frequency> {
  FrequencyCacheRepository()
      : super(
          boxName: CacheConstants.frequenciesBoxName,
          lastFetchKey: CacheConstants.frequenciesLastFetchKey,
        );

  @override
  Map<String, dynamic> toMap(Frequency frequency) {
    return frequency.toMap();
  }

  @override
  Frequency fromMap(Map<dynamic, dynamic> map) {
    return Frequency.fromMap(Map<String, dynamic>.from(map));
  }

  @override
  String getKey(Frequency frequency) => frequency.id.toString();

  /// Cache frequencies with their data
  Future<void> cacheFrequencies(List<Frequency> frequencies) async {
    await cacheItems(frequencies);
  }

  /// Get all cached frequencies
  Future<List<Frequency>> getCachedFrequencies() async {
    return await getCachedItems();
  }
}