import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'offline_map_service.dart';

/// Custom tile provider that supports both online and offline tiles
class OfflineTileProvider extends TileProvider {
  final String urlTemplate;
  final OfflineMapService offlineMapService;
  final String? userAgentPackageName;
  final Logger _logger = Logger();

  OfflineTileProvider({
    required this.urlTemplate,
    required this.offlineMapService,
    this.userAgentPackageName,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return OfflineTileImageProvider(
      coordinates: coordinates,
      urlTemplate: urlTemplate,
      offlineMapService: offlineMapService,
      userAgentPackageName: userAgentPackageName,
    );
  }
}

/// Custom image provider for offline tiles
class OfflineTileImageProvider extends ImageProvider<OfflineTileImageProvider> {
  final TileCoordinates coordinates;
  final String urlTemplate;
  final OfflineMapService offlineMapService;
  final String? userAgentPackageName;

  const OfflineTileImageProvider({
    required this.coordinates,
    required this.urlTemplate,
    required this.offlineMapService,
    this.userAgentPackageName,
  });

  @override
  Future<OfflineTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OfflineTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(OfflineTileImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAsync(OfflineTileImageProvider key, ImageDecoderCallback decode) async {
    final Logger logger = Logger();

    try {
      // First, try to get the tile from offline cache
      final cachedTile = await offlineMapService.getCachedTile(
        coordinates.z,
        coordinates.x,
        coordinates.y,
      );

      if (cachedTile != null) {
        logger.d('📱 Using cached tile: ${coordinates.z}/${coordinates.x}/${coordinates.y}');
        final buffer = await ImmutableBuffer.fromUint8List(cachedTile);
        return await decode(buffer);
      }

      // If not cached, try to download from online source
      logger.d('🌐 Downloading tile: ${coordinates.z}/${coordinates.x}/${coordinates.y}');
      final url = urlTemplate
          .replaceAll('{z}', coordinates.z.toString())
          .replaceAll('{x}', coordinates.x.toString())
          .replaceAll('{y}', coordinates.y.toString());

      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (userAgentPackageName != null) 'User-Agent': userAgentPackageName!,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        // Store the downloaded tile for future offline use
        _storeTileAsync(coordinates.z, coordinates.x, coordinates.y, bytes);

        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        return await decode(buffer);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      logger.w('⚠️ Failed to load tile ${coordinates.z}/${coordinates.x}/${coordinates.y}: $e');

      // Return a placeholder tile or rethrow the error
      throw Exception('Failed to load map tile: $e');
    }
  }

  /// Store tile asynchronously without blocking the UI
  void _storeTileAsync(int z, int x, int y, Uint8List tileData) {
    // Run in background without awaiting to avoid blocking tile loading
    () async {
      try {
        // Use the offline map service to store the tile
        await offlineMapService.storeTileDirectly(z, x, y, tileData);
      } catch (e) {
        Logger().w('⚠️ Failed to cache tile $z/$x/$y: $e');
      }
    }();
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is OfflineTileImageProvider &&
        other.coordinates == coordinates &&
        other.urlTemplate == urlTemplate;
  }

  @override
  int get hashCode => Object.hash(coordinates, urlTemplate);
}
