import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';

/// Service for managing offline map tiles and caching
class OfflineMapService {
  static const String _dbName = 'map_tiles.db';
  static const String _tableName = 'tiles';
  static const int _maxZoomLevel = 16;
  static const int _minZoomLevel = 4;

  final Logger _logger = Logger(
    level: Level.warning, // Only log warnings and errors in production
  );
  Database? _database;
  bool _isInitialized = false;
  bool _isCancelled = false; // Add cancellation flag

  /// Initialize the offline map service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final dbPath = await _getDatabasePath();
      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: _createDatabase,
      );
      _isInitialized = true;
      _logger.i('🗺️ Offline map service initialized');
    } catch (e) {
      _logger.e('❌ Error initializing offline map service: $e');
      rethrow;
    }
  }

  /// Create the database table for storing tiles
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
    final documentsDir = await getApplicationDocumentsDirectory();
    return path.join(documentsDir.path, _dbName);
  }

  /// Download and cache map tiles for a specific area
  Future<Map<String, int>> downloadAreaTiles({
    required LatLng northEast,
    required LatLng southWest,
    required int minZoom,
    required int maxZoom,
    required Function(int current, int total, int skipped, int downloaded) onProgress,
    String tileServerUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  }) async {
    await initialize();
    
    // Reset cancellation flag at start of new download
    _resetCancellation();

    if (minZoom < _minZoomLevel) minZoom = _minZoomLevel;
    if (maxZoom > _maxZoomLevel) maxZoom = _maxZoomLevel;

    _logger.i('🔄 Starting tile download for area: $southWest to $northEast, zoom: $minZoom-$maxZoom');

    int totalTiles = 0;
    int processedTiles = 0;
    int skippedTiles = 0;
    int downloadedTiles = 0;

    // Calculate total number of tiles to download
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      final bounds = _getTileBounds(northEast, southWest, zoom);
      totalTiles += (bounds.maxX - bounds.minX + 1) * (bounds.maxY - bounds.minY + 1);
    }

    _logger.i('📊 Total tiles to process: $totalTiles');

    // Download tiles for each zoom level
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      // Check for cancellation at zoom level
      if (_isCancelled) {
        _logger.i('🛑 Download cancelled by user at zoom level $zoom');
        throw Exception('Download cancelled by user');
      }
      
      final bounds = _getTileBounds(northEast, southWest, zoom);

      for (int x = bounds.minX; x <= bounds.maxX; x++) {
        // Check for cancellation at row level for more responsive cancellation
        if (_isCancelled) {
          _logger.i('🛑 Download cancelled by user');
          throw Exception('Download cancelled by user');
        }
        
        for (int y = bounds.minY; y <= bounds.maxY; y++) {
          try {
            // Check if tile already exists
            if (await _tileExists(zoom, x, y)) {
              processedTiles++;
              skippedTiles++;
              onProgress(processedTiles, totalTiles, skippedTiles, downloadedTiles);
              // No delay needed for skipped tiles
              continue;
            }

            // Download and store tile
            await _downloadAndStoreTile(zoom, x, y, tileServerUrl);
            processedTiles++;
            downloadedTiles++;
            onProgress(processedTiles, totalTiles, skippedTiles, downloadedTiles);

            // Add small delay to avoid overwhelming the server (only for actual downloads)
            await Future.delayed(const Duration(milliseconds: 50));

          } catch (e) {
            _logger.w('⚠️ Failed to download tile $zoom/$x/$y: $e');
            processedTiles++;
            onProgress(processedTiles, totalTiles, skippedTiles, downloadedTiles);
          }
        }
      }
    }

    _logger.i('✅ Tile download completed: Downloaded $downloadedTiles, Skipped $skippedTiles (already cached), Total $processedTiles/$totalTiles');
    
    return {
      'total': totalTiles,
      'downloaded': downloadedTiles,
      'skipped': skippedTiles,
      'processed': processedTiles,
    };
  }

  /// Get tile bounds for a geographic area at a specific zoom level
  TileBounds _getTileBounds(LatLng northEast, LatLng southWest, int zoom) {
    final nePoint = _latLngToTileCoordinates(northEast.latitude, northEast.longitude, zoom);
    final swPoint = _latLngToTileCoordinates(southWest.latitude, southWest.longitude, zoom);

    return TileBounds(
      minX: swPoint.x.floor(),
      maxX: nePoint.x.floor(),
      minY: nePoint.y.floor(),
      maxY: swPoint.y.floor(),
    );
  }

  /// Convert latitude/longitude to tile coordinates
  TilePoint _latLngToTileCoordinates(double lat, double lng, int zoom) {
    final n = (1 << zoom).toDouble();
    final latRad = lat * (pi / 180);

    final x = ((lng + 180) / 360) * n;
    final y = (1 - (log(tan(latRad) + (1 / cos(latRad))) / pi)) / 2 * n;

    return TilePoint(x: x, y: y);
  }

  /// Check if a tile exists in the database
  Future<bool> _tileExists(int z, int x, int y) async {
    final result = await _database!.query(
      _tableName,
      where: 'z = ? AND x = ? AND y = ?',
      whereArgs: [z, x, y],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Download and store a single tile
  Future<void> _downloadAndStoreTile(int z, int x, int y, String urlTemplate) async {
    final url = urlTemplate
        .replaceAll('{z}', z.toString())
        .replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString());

    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'CaptainVFR/1.0.0'},
    );

    if (response.statusCode == 200) {
      await _database!.insert(
        _tableName,
        {
          'z': z,
          'x': x,
          'y': y,
          'tile_data': response.bodyBytes,
          'download_time': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      throw Exception('HTTP ${response.statusCode}: Failed to download tile');
    }
  }

  /// Store a tile directly (used by tile provider)
  Future<void> storeTileDirectly(int z, int x, int y, Uint8List tileData) async {
    await initialize();

    await _database!.insert(
      _tableName,
      {
        'z': z,
        'x': x,
        'y': y,
        'tile_data': tileData,
        'download_time': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a cached tile from the database
  Future<Uint8List?> getCachedTile(int z, int x, int y) async {
    await initialize();

    final result = await _database!.query(
      _tableName,
      columns: ['tile_data'],
      where: 'z = ? AND x = ? AND y = ?',
      whereArgs: [z, x, y],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['tile_data'] as Uint8List;
    }

    return null;
  }

  /// Get statistics about cached tiles
  Future<Map<String, dynamic>> getCacheStatistics() async {
    await initialize();

    final totalTiles = await _database!.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    final sizeResult = await _database!.rawQuery('SELECT SUM(LENGTH(tile_data)) as size FROM $_tableName');
    final zoomStats = await _database!.rawQuery('''
      SELECT z, COUNT(*) as count 
      FROM $_tableName 
      GROUP BY z 
      ORDER BY z
    ''');

    final totalCount = totalTiles.first['count'] as int;
    final totalSize = sizeResult.first['size'] as int? ?? 0;

    return {
      'totalTiles': totalCount,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      'zoomLevels': zoomStats,
    };
  }

  /// Clear all cached tiles
  Future<void> clearCache() async {
    await initialize();
    await _database!.delete(_tableName);
    _logger.i('🗑️ Map tile cache cleared');
  }

  /// Clear old tiles (older than specified days)
  Future<void> clearOldTiles(int daysOld) async {
    await initialize();

    final cutoffTime = DateTime.now().subtract(Duration(days: daysOld)).millisecondsSinceEpoch;
    final deletedCount = await _database!.delete(
      _tableName,
      where: 'download_time < ?',
      whereArgs: [cutoffTime],
    );

    _logger.i('🗑️ Cleared $deletedCount old tiles (older than $daysOld days)');
  }

  /// Check if device has sufficient storage for download
  Future<bool> hasEnoughStorage(int estimatedTiles) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stat = await dir.stat();

      // Estimate ~20KB per tile on average
      final estimatedSizeBytes = estimatedTiles * 20 * 1024;

      // Check if we have at least 2x the estimated size available
      return stat.size > estimatedSizeBytes * 2;
    } catch (e) {
      _logger.w('⚠️ Could not check storage: $e');
      return true; // Assume we have enough storage if we can't check
    }
  }

  /// Cancel the current download operation
  void cancelDownload() {
    _isCancelled = true;
    _logger.i('📊 Download cancellation requested');
  }

  /// Reset cancellation flag
  void _resetCancellation() {
    _isCancelled = false;
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
  }
}

/// Helper class for tile bounds
class TileBounds {
  final int minX;
  final int maxX;
  final int minY;
  final int maxY;

  TileBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });
}

/// Helper class for tile coordinates
class TilePoint {
  final double x;
  final double y;

  TilePoint({required this.x, required this.y});
}
