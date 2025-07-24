import 'dart:developer' as developer;
import 'package:hive_flutter/hive_flutter.dart';
import '../../../models/reporting_point.dart';
import '../models/cache_constants.dart';
import 'base_cache_repository.dart';
import '../../../utils/performance_monitor.dart';

/// Repository for caching reporting point data
class ReportingPointCacheRepository extends BaseCacheRepository<ReportingPoint> {
  ReportingPointCacheRepository()
      : super(
          boxName: CacheConstants.reportingPointsBoxName,
          lastFetchKey: CacheConstants.reportingPointsLastFetchKey,
        );

  @override
  Map<String, dynamic> toMap(ReportingPoint point) {
    return point.toJson();
  }

  @override
  ReportingPoint fromMap(Map<dynamic, dynamic> map) {
    return ReportingPoint.fromJson(Map<String, dynamic>.from(map));
  }

  @override
  String getKey(ReportingPoint point) => point.id;

  /// Cache reporting points (replaces all existing data)
  Future<void> cacheReportingPoints(List<ReportingPoint> points) async {
    await cacheItems(points, clearExisting: true);
  }

  /// Append reporting points data (adds to existing data without clearing)
  Future<void> appendReportingPoints(List<ReportingPoint> points) async {
    try {
      // Track performance of this operation
      await PerformanceMonitor().measureAsync(
        'appendReportingPoints',
        () async {
          developer.log('💾 Appending ${points.length} reporting points...');
          developer.log(
            '📊 Current box status: isOpen=${box.isOpen}, length=${box.length}',
          );

          // Don't clear existing data - append mode
          int added = 0;
          int updated = 0;

          // Cache reporting points as maps
          for (final point in points) {
            try {
              final exists = box.containsKey(point.id);
              final json = point.toJson();
              await box.put(point.id, json);
              if (exists) {
                updated++;
              } else {
                added++;
              }
            } catch (e) {
              developer.log('⚠️ Error caching reporting point ${point.id}: $e');
            }
          }

          developer.log(
            '✅ Reporting points append complete: $added added, $updated updated, total in cache: ${box.length}',
          );
        },
        tags: {
          'count': points.length.toString(),
          'box_length_before': box.length.toString(),
        },
      );
    } catch (e) {
      developer.log('❌ Error appending reporting points: $e');
      developer.log('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Get all cached reporting points
  Future<List<ReportingPoint>> getCachedReportingPoints() async {
    return await getCachedItems();
  }
}