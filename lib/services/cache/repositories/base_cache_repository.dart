import 'dart:developer' as developer;
import 'package:hive_flutter/hive_flutter.dart';

/// Base repository class for common cache operations
abstract class BaseCacheRepository<T> {
  final String boxName;
  final String lastFetchKey;
  late Box<Map> _box;
  late Box<dynamic> _metadataBox;
  
  BaseCacheRepository({
    required this.boxName,
    required this.lastFetchKey,
  });

  /// Initialize the repository with the required boxes
  void initialize(Box<Map> box, Box<dynamic> metadataBox) {
    _box = box;
    _metadataBox = metadataBox;
  }

  /// Get the box for this repository
  Box<Map> get box => _box;

  /// Convert model to map for storage
  Map<String, dynamic> toMap(T item);

  /// Convert map back to model
  T fromMap(Map<dynamic, dynamic> map);

  /// Get unique key for the item
  String getKey(T item);

  /// Cache a list of items
  Future<void> cacheItems(List<T> items, {bool clearExisting = true}) async {
    try {
      developer.log('💾 Caching ${items.length} $T items...');

      if (clearExisting) {
        // Clear existing data
        await _box.clear();
      }

      // Cache items as maps
      for (final item in items) {
        await _box.put(getKey(item), toMap(item));
      }

      // Update last fetch timestamp
      await _metadataBox.put(
        lastFetchKey,
        DateTime.now().toIso8601String(),
      );

      developer.log('✅ Cached ${items.length} $T items successfully');
    } catch (e) {
      developer.log('❌ Error caching $T items: $e');
      rethrow;
    }
  }

  /// Get all cached items
  Future<List<T>> getCachedItems() async {
    try {
      final items = <T>[];
      
      // Check if box is open
      if (!_box.isOpen) {
        developer.log('⚠️ $boxName box is closed');
        return items;
      }

      for (final key in _box.keys) {
        final data = _box.get(key);
        if (data != null) {
          try {
            items.add(fromMap(data));
          } catch (e) {
            developer.log('⚠️ Error parsing $T from cache: $e');
          }
        }
      }

      return items;
    } catch (e) {
      developer.log('❌ Error getting cached $T items: $e');
      return [];
    }
  }

  /// Get last fetch timestamp
  Future<DateTime?> getLastFetch() async {
    try {
      final timestamp = _metadataBox.get(lastFetchKey);
      if (timestamp != null) {
        return DateTime.parse(timestamp as String);
      }
    } catch (e) {
      developer.log('⚠️ Error parsing last fetch timestamp: $e');
    }
    return null;
  }

  /// Set last fetch timestamp
  Future<void> setLastFetch(DateTime timestamp) async {
    await _metadataBox.put(lastFetchKey, timestamp.toIso8601String());
  }

  /// Clear the cache
  Future<void> clearCache() async {
    await _box.clear();
    await _metadataBox.delete(lastFetchKey);
  }

  /// Check if cache needs refresh (older than specified duration)
  Future<bool> needsRefresh(Duration maxAge) async {
    final lastFetch = await getLastFetch();
    if (lastFetch == null) return true;
    return DateTime.now().difference(lastFetch) > maxAge;
  }
}