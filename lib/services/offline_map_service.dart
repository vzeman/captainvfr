import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:logger/logger.dart';

/// Service for managing offline map tiles and caching
class OfflineMapService {
  static const String _dbName = 'map_tiles.db';
  static const String _tableName = 'tiles';

  final Logger _logger = Logger(
    level: Level.warning, // Only log warnings and errors in production
  );
  Database? _database;
  bool _isInitialized = false;
  bool _isCancelled = false; // Add cancellation flag

  /// Initialize the offline map service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Offline maps not supported on web
    if (kIsWeb) {
      _logger.i('Offline maps not supported on web platform');
      _isInitialized = true;
      return;
    }

    try {
      final dbPath = await _getDatabasePath();
      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createDatabase,
      );
      _isInitialized = true;
      _logger.i('📦 Offline map service initialized');
    } catch (e) {
      _logger.e('❌ Failed to initialize offline map service: $e');
      throw Exception('Failed to initialize offline map service: $e');
    }
  }

  /// Create the database schema
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        z INTEGER NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        tile_data BLOB NOT NULL,
        download_time INTEGER NOT NULL,
        UNIQUE(z, x, y)
      )
    ''');

    // Create index for faster lookups
    await db.execute('''
      CREATE INDEX idx_tile_coords ON $_tableName (z, x, y)
    ''');
  }

  /// Get the database path
  Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      throw UnsupportedError('Offline maps not supported on web');
    }
    final documentsDir = await getApplicationDocumentsDirectory();
    return path.join(documentsDir.path, _dbName);
  }

  /// Download and cache map tiles for a specific area
  Future<Map<String, int>> downloadAreaTiles({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    String tileServerUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    String userAgent = 'CaptainVFR/1.0',
    Function(int current, int total, int skipped, int downloaded)? onProgress,
  }) async {
    if (kIsWeb) {
      return {'downloaded': 0, 'failed': 0, 'skipped': 0};
    }
    
    if (!_isInitialized) await initialize();

    _isCancelled = false;
    int downloadedCount = 0;
    int failedCount = 0;
    int skippedCount = 0;

    // Calculate total tiles to download
    final totalTiles = _calculateTotalTiles(bounds, minZoom, maxZoom);
    int processedTiles = 0;

    _logger.i('📥 Starting download of $totalTiles tiles');

    for (int z = minZoom; z <= maxZoom; z++) {
      if (_isCancelled) break;

      final tileBounds = _getTileBounds(bounds, z);
      
      for (int x = tileBounds.minX; x <= tileBounds.maxX; x++) {
        if (_isCancelled) break;
        
        for (int y = tileBounds.minY; y <= tileBounds.maxY; y++) {
          if (_isCancelled) break;

          // Check if tile already exists
          if (await hasTile(z, x, y)) {
            skippedCount++;
          } else {
            // Download and save tile
            final success = await _downloadAndSaveTile(
              z: z,
              x: x,
              y: y,
              tileServerUrl: tileServerUrl,
              userAgent: userAgent,
            );
            
            if (success) {
              downloadedCount++;
            } else {
              failedCount++;
            }
          }

          processedTiles++;
          
          // Report progress
          if (onProgress != null) {
            onProgress(processedTiles, totalTiles, skippedCount, downloadedCount);
          }

          // Small delay to avoid overwhelming the server
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    }

    _logger.i(
      '✅ Download complete: $downloadedCount downloaded, '
      '$failedCount failed, $skippedCount skipped',
    );

    return {
      'downloaded': downloadedCount,
      'failed': failedCount,
      'skipped': skippedCount,
    };
  }

  /// Cancel ongoing download
  void cancelDownload() {
    _isCancelled = true;
    _logger.i('🛑 Download cancelled');
  }

  /// Download and save a single tile
  Future<bool> _downloadAndSaveTile({
    required int z,
    required int x,
    required int y,
    required String tileServerUrl,
    required String userAgent,
  }) async {
    try {
      final url = tileServerUrl
          .replaceAll('{z}', z.toString())
          .replaceAll('{x}', x.toString())
          .replaceAll('{y}', y.toString());

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await saveTile(z, x, y, response.bodyBytes);
        return true;
      } else {
        _logger.w('❌ Failed to download tile $z/$x/$y: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error downloading tile $z/$x/$y: $e');
      return false;
    }
  }

  /// Calculate total number of tiles for an area
  int _calculateTotalTiles(LatLngBounds bounds, int minZoom, int maxZoom) {
    int total = 0;
    for (int z = minZoom; z <= maxZoom; z++) {
      final tileBounds = _getTileBounds(bounds, z);
      final tilesX = tileBounds.maxX - tileBounds.minX + 1;
      final tilesY = tileBounds.maxY - tileBounds.minY + 1;
      total += tilesX * tilesY;
    }
    return total;
  }

  /// Get tile bounds for a geographic area at a specific zoom level
  _TileBounds _getTileBounds(LatLngBounds bounds, int zoom) {
    final minTile = _latLngToTile(bounds.southWest, zoom);
    final maxTile = _latLngToTile(bounds.northEast, zoom);
    
    return _TileBounds(
      minX: minTile.x.floor(),
      minY: maxTile.y.floor(),
      maxX: maxTile.x.floor(),
      maxY: minTile.y.floor(),
    );
  }

  /// Convert lat/lng to tile coordinates
  Point<double> _latLngToTile(LatLng latLng, int zoom) {
    final n = pow(2, zoom);
    final x = ((latLng.longitude + 180) / 360) * n;
    final latRad = latLng.latitude * pi / 180;
    final y = (1 - (log(tan(latRad) + (1 / cos(latRad))) / pi)) / 2 * n;
    return Point(x, y);
  }

  /// Save a tile to the database
  Future<void> saveTile(int z, int x, int y, Uint8List data) async {
    if (kIsWeb || _database == null) return;
    
    await _database!.insert(
      _tableName,
      {
        'z': z,
        'x': x,
        'y': y,
        'tile_data': data,
        'download_time': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a tile from the database
  Future<Uint8List?> getTile(int z, int x, int y) async {
    if (kIsWeb || _database == null) return null;
    
    final result = await _database!.query(
      _tableName,
      columns: ['tile_data'],
      where: 'z = ? AND x = ? AND y = ?',
      whereArgs: [z, x, y],
    );

    if (result.isNotEmpty) {
      return result.first['tile_data'] as Uint8List;
    }
    return null;
  }

  /// Check if a tile exists in the database
  Future<bool> hasTile(int z, int x, int y) async {
    if (kIsWeb || _database == null) return false;
    
    final result = await _database!.query(
      _tableName,
      columns: ['id'],
      where: 'z = ? AND x = ? AND y = ?',
      whereArgs: [z, x, y],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get statistics about cached tiles
  Future<Map<String, dynamic>> getCacheStatistics() async {
    if (kIsWeb || _database == null) {
      return {
        'totalTiles': 0,
        'totalSizeBytes': 0,
        'oldestTile': null,
        'newestTile': null,
      };
    }
    
    final countResult = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    final count = countResult.first['count'] as int;

    final sizeResult = await _database!.rawQuery(
      'SELECT SUM(LENGTH(tile_data)) as size FROM $_tableName',
    );
    final size = sizeResult.first['size'] as int? ?? 0;

    final oldestResult = await _database!.rawQuery(
      'SELECT MIN(download_time) as oldest FROM $_tableName',
    );
    final oldest = oldestResult.first['oldest'] as int?;

    final newestResult = await _database!.rawQuery(
      'SELECT MAX(download_time) as newest FROM $_tableName',
    );
    final newest = newestResult.first['newest'] as int?;

    return {
      'totalTiles': count,
      'totalSizeBytes': size,
      'oldestTile': oldest != null
          ? DateTime.fromMillisecondsSinceEpoch(oldest)
          : null,
      'newestTile': newest != null
          ? DateTime.fromMillisecondsSinceEpoch(newest)
          : null,
    };
  }

  /// Clear all cached tiles
  Future<void> clearCache() async {
    if (kIsWeb || _database == null) return;
    
    await _database!.delete(_tableName);
    _logger.i('🗑️ Cleared all cached tiles');
  }

  /// Clear old cached tiles
  Future<void> clearOldTiles(int daysOld) async {
    if (kIsWeb || _database == null) return;
    
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: daysOld))
        .millisecondsSinceEpoch;
    
    final deletedCount = await _database!.delete(
      _tableName,
      where: 'download_time < ?',
      whereArgs: [cutoffTime],
    );
    
    _logger.i('🗑️ Cleared $deletedCount old tiles (older than $daysOld days)');
  }

  /// Check if device has sufficient storage for download
  Future<bool> hasEnoughStorage(int estimatedTiles) async {
    if (kIsWeb) {
      return false; // No offline storage on web
    }
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stat = await dir.stat();
      
      // Estimate ~20KB per tile on average
      final estimatedSizeBytes = estimatedTiles * 20 * 1024;
      
      // Check if we have at least 2x the estimated size available
      return stat.size > estimatedSizeBytes * 2;
    } catch (e) {
      _logger.e('❌ Error checking storage: $e');
      return false;
    }
  }

  /// Get a cached tile (alias for getTile for compatibility)
  Future<Uint8List?> getCachedTile(int z, int x, int y) async {
    return getTile(z, x, y);
  }

  /// Store a tile directly (alias for saveTile for compatibility)
  Future<void> storeTileDirectly(int z, int x, int y, Uint8List data) async {
    await saveTile(z, x, y, data);
  }

  /// Close the database connection
  Future<void> dispose() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
    }
  }
}

/// Helper class for tile bounds
class _TileBounds {
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  _TileBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
}