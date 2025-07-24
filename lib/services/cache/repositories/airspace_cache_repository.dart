import 'dart:developer' as developer;
import '../../../models/airspace.dart';
import '../models/cache_constants.dart';
import 'base_cache_repository.dart';
import '../../../utils/performance_monitor.dart';

/// Repository for caching airspace data
class AirspaceCacheRepository extends BaseCacheRepository<Airspace> {
  AirspaceCacheRepository()
      : super(
          boxName: CacheConstants.airspacesBoxName,
          lastFetchKey: CacheConstants.airspacesLastFetchKey,
        );

  @override
  Map<String, dynamic> toMap(Airspace airspace) {
    return airspace.toJson();
  }

  @override
  Airspace fromMap(Map<dynamic, dynamic> map) {
    return Airspace.fromJson(Map<String, dynamic>.from(map));
  }

  @override
  String getKey(Airspace airspace) => airspace.id;

  /// Cache airspaces with their data (replaces all existing data)
  Future<void> cacheAirspaces(List<Airspace> airspaces) async {
    await cacheItems(airspaces, clearExisting: true);
  }

  /// Append airspaces data (adds to existing data without clearing)
  Future<void> appendAirspaces(List<Airspace> airspaces) async {
    try {
      // Track performance of this operation
      await PerformanceMonitor().measureAsync(
        'appendAirspaces',
        () async {
          developer.log('💾 Appending ${airspaces.length} airspaces...');
          developer.log(
            '📊 Current box status: isOpen=${box.isOpen}, length=${box.length}',
          );

          // Don't clear existing data - append mode
          int added = 0;
          int updated = 0;

          // Cache airspaces as maps
          for (final airspace in airspaces) {
            try {
              final exists = box.containsKey(airspace.id);
              final json = airspace.toJson();
              await box.put(airspace.id, json);
              if (exists) {
                updated++;
              } else {
                added++;
              }
            } catch (e) {
              developer.log('⚠️ Error caching airspace ${airspace.id}: $e');
            }
          }

          developer.log(
            '✅ Airspace append complete: $added added, $updated updated, total in cache: ${box.length}',
          );
        },
      );
    } catch (e) {
      developer.log('❌ Error appending airspaces: $e');
      developer.log('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Get all cached airspaces
  Future<List<Airspace>> getCachedAirspaces() async {
    return await getCachedItems();
  }
}