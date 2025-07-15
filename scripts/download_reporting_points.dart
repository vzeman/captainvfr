#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to download all reporting points from OpenAIP API and save to a JSON file
/// This file will be bundled with the app for offline use
/// 
/// Usage: dart scripts/download_reporting_points.dart [--api-key YOUR_API_KEY]

const String _baseUrl = 'https://api.core.openaip.net/api';
const String _reportingPointsEndpoint = '/reporting-points';

void main(List<String> args) async {
  // Default API key from app config
  const String defaultApiKey = '04cf90fde37c629b3cec5468572dd804';
  
  // Parse command line arguments
  String? apiKey = defaultApiKey;
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--api-key' && i + 1 < args.length) {
      apiKey = args[i + 1];
    }
  }

  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Error: API key is required');
    print('Usage: dart scripts/download_reporting_points.dart [--api-key YOUR_API_KEY]');
    print('Note: Using default API key if not specified');
    exit(1);
  }

  print('🚀 Starting reporting points download...');
  print('📍 API Key: ${apiKey.substring(0, 4)}... (${apiKey.length} chars)');

  final stopwatch = Stopwatch()..start();
  final allPoints = <Map<String, dynamic>>[];

  // Use the same tile grid as airspaces
  const int tilesX = 10;
  const int tilesY = 8;
  const double worldWidth = 360.0;
  const double worldHeight = 180.0;
  const double tileWidth = worldWidth / tilesX;
  const double tileHeight = worldHeight / tilesY;

  final totalTiles = tilesX * tilesY;
  int completedTiles = 0;
  int failedTiles = 0;

  print('📐 Using ${tilesX}x$tilesY grid ($totalTiles tiles)');
  print('📏 Tile size: ${tileWidth.toStringAsFixed(1)}° x ${tileHeight.toStringAsFixed(1)}°');
  print('');

  // Download progress file to resume if interrupted
  final progressFile = File('scripts/download_rp_progress.json');
  Map<String, dynamic> progress = {};
  if (await progressFile.exists()) {
    final content = await progressFile.readAsString();
    progress = json.decode(content);
    print('📊 Found existing progress file, resuming download...');
  }

  // Iterate through each tile
  for (int y = 0; y < tilesY; y++) {
    for (int x = 0; x < tilesX; x++) {
      final tileKey = '$x,$y';
      
      // Skip if already downloaded
      if (progress[tileKey] == true) {
        completedTiles++;
        continue;
      }

      // Calculate tile boundaries
      final minLon = -180.0 + (x * tileWidth);
      final maxLon = minLon + tileWidth;
      final minLat = -90.0 + (y * tileHeight);
      final maxLat = minLat + tileHeight;

      print('\n🗺️  Tile ${completedTiles + 1}/$totalTiles: [$minLon, $minLat, $maxLon, $maxLat]');

      try {
        final tilePoints = await _fetchTileReportingPoints(
          apiKey: apiKey,
          bbox: [minLon, minLat, maxLon, maxLat],
          tileNumber: completedTiles + 1,
        );

        allPoints.addAll(tilePoints);
        completedTiles++;
        
        // Mark tile as completed
        progress[tileKey] = true;
        await progressFile.writeAsString(json.encode(progress));

        print('   ✅ Got ${tilePoints.length} points (Total: ${allPoints.length})');

        // Small delay between tiles
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        print('   ❌ Error: $e');
        failedTiles++;
        completedTiles++;
        
        // Longer delay after error
        await Future.delayed(const Duration(seconds: 5));
      }

      // Show progress
      final percentComplete = (completedTiles / totalTiles * 100).toStringAsFixed(1);
      print('   📊 Progress: $percentComplete% ($completedTiles/$totalTiles tiles)');
    }
  }

  stopwatch.stop();

  print('\n${'=' * 60}');
  print('📊 DOWNLOAD COMPLETE');
  print('=' * 60);
  print('✅ Successfully downloaded tiles: ${completedTiles - failedTiles}');
  print('❌ Failed tiles: $failedTiles');
  print('📍 Total reporting points collected: ${allPoints.length}');
  print('⏱️  Time taken: ${stopwatch.elapsed.inMinutes}m ${stopwatch.elapsed.inSeconds % 60}s');

  // Remove duplicates based on ID
  print('\n🔍 Removing duplicates...');
  final uniquePoints = <String, Map<String, dynamic>>{};
  final duplicateCount = <String, int>{};
  
  for (final point in allPoints) {
    // Try multiple ID fields for better deduplication
    final id = point['_id']?.toString() ?? 
                point['id']?.toString() ?? 
                point['uuid']?.toString() ?? 
                'unknown_${uniquePoints.length}';
    
    if (uniquePoints.containsKey(id)) {
      duplicateCount[id] = (duplicateCount[id] ?? 1) + 1;
    } else {
      uniquePoints[id] = point;
    }
  }

  final totalDuplicates = allPoints.length - uniquePoints.length;
  print('✅ Unique reporting points: ${uniquePoints.length}');
  print('🔄 Duplicates removed: $totalDuplicates');
  
  if (duplicateCount.isNotEmpty) {
    final topDuplicates = duplicateCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    print('📊 Top duplicated reporting points:');
    for (var i = 0; i < 5 && i < topDuplicates.length; i++) {
      final entry = topDuplicates[i];
      final point = uniquePoints[entry.key];
      final name = point?['name'] ?? 'Unknown';
      print('   - $name (ID: ${entry.key}): ${entry.value} duplicates');
    }
  }

  // Save to file
  final outputFile = File('assets/data/reporting_points.json');
  await outputFile.parent.create(recursive: true);

  final outputData = {
    'version': 1,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'total_reporting_points': uniquePoints.length,
    'reporting_points': uniquePoints.values.toList(),
  };

  await outputFile.writeAsString(json.encode(outputData));
  print('\n💾 Saved to: ${outputFile.path}');

  // Calculate file size
  final fileSize = await outputFile.length();
  final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(2);
  print('📦 File size: $fileSizeMB MB');

  // Create compressed version
  final compressedFile = File('assets/data/reporting_points.json.gz');
  final gzipData = gzip.encode(utf8.encode(json.encode(outputData)));
  await compressedFile.writeAsBytes(gzipData);
  
  final compressedSize = await compressedFile.length();
  final compressedSizeMB = (compressedSize / 1024 / 1024).toStringAsFixed(2);
  print('🗜️  Compressed size: $compressedSizeMB MB (${(compressedSize / fileSize * 100).toStringAsFixed(1)}% of original)');

  // Clean up progress file
  if (await progressFile.exists()) {
    await progressFile.delete();
  }

  print('\n✅ Done! Reporting points are ready to be bundled with the app.');
  print('📝 Remember to add assets/data/reporting_points.json to pubspec.yaml');
  
  // Automatically run compression
  print('\n🗜️  Running compression script...');
  final compressResult = await Process.run('dart', ['scripts/prepare_compressed_data.dart']);
  
  if (compressResult.exitCode == 0) {
    print('✅ Compression complete! Compressed file ready at: assets/data/reporting_points_min.json.gz');
  } else {
    print('⚠️  Compression failed. Run manually: dart scripts/prepare_compressed_data.dart');
    print('Error: ${compressResult.stderr}');
  }
}

Future<List<Map<String, dynamic>>> _fetchTileReportingPoints({
  required String apiKey,
  required List<double> bbox,
  required int tileNumber,
}) async {
  final tilePoints = <Map<String, dynamic>>[];
  int page = 1;
  bool hasMore = true;

  while (hasMore) {
    final queryParams = {
      'page': page.toString(),
      'limit': '1000',
      'bbox': bbox.join(','),
    };

    final uri = Uri.parse('$_baseUrl$_reportingPointsEndpoint')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'x-openaip-api-key': apiKey,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? data['data'] ?? data ?? [];

      if (items.isEmpty) {
        hasMore = false;
      } else {
        tilePoints.addAll(items.cast<Map<String, dynamic>>());
        
        print('   📄 Page $page: ${items.length} points');

        // Check if we got less than limit, indicating last page
        if (items.length < 1000) {
          hasMore = false;
        } else if (page >= 10) {
          // Safety limit to prevent infinite loops
          hasMore = false;
        } else {
          page++;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } else if (response.statusCode == 429) {
      print('   ⚠️  Rate limit hit, waiting 60 seconds...');
      await Future.delayed(const Duration(seconds: 60));
      // Retry same page
    } else {
      throw Exception('API error: ${response.statusCode} - ${response.body}');
    }
  }

  return tilePoints;
}