#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

/// Unified script to download, convert, split, and prepare all aviation data
/// This replaces multiple scripts with a single, efficient workflow
/// 
/// Usage: dart scripts/prepare_all_data.dart --api-key YOUR_API_KEY

const String _baseUrl = 'https://api.core.openaip.net/api';

// Tile configuration (10x10 degrees)
const int tilesX = 36; // 360 degrees / 10 degrees
const int tilesY = 18; // 180 degrees / 10 degrees
const double tileWidth = 10.0;
const double tileHeight = 10.0;

// Data types to process
const dataTypes = {
  'airports': {'endpoint': '/airports', 'hasCoordinates': true},
  'airspaces': {'endpoint': '/airspaces', 'hasCoordinates': true},
  'navaids': {'endpoint': '/navaids', 'hasCoordinates': true},
  // Runways and frequencies are typically part of airport data, not separate endpoints
  // 'runways': {'endpoint': '/runways', 'hasCoordinates': false},
  // 'frequencies': {'endpoint': '/frequencies', 'hasCoordinates': false},
  'reporting_points': {'endpoint': '/reporting-points', 'hasCoordinates': true},
  'obstacles': {'endpoint': '/obstacles', 'hasCoordinates': true},
  'hotspots': {'endpoint': '/hotspots', 'hasCoordinates': true},
};

void main(List<String> args) async {
  final stopwatch = Stopwatch()..start();
  
  // Parse command line arguments
  String? apiKey;
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--api-key' && i + 1 < args.length) {
      apiKey = args[i + 1];
    }
  }

  // Try to load from .env if not provided
  if (apiKey == null || apiKey.isEmpty) {
    final envFile = File('.env');
    if (await envFile.exists()) {
      final content = await envFile.readAsString();
      final match = RegExp(r'OPENAIP_API_KEY=(.+)').firstMatch(content);
      if (match != null) {
        apiKey = match.group(1);
      }
    }
  }

  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Error: API key is required');
    print('Usage: dart scripts/prepare_all_data.dart --api-key YOUR_API_KEY');
    print('Or set OPENAIP_API_KEY in .env file');
    exit(1);
  }

  print('🚀 Starting unified data preparation...');
  print('📍 API Key: ${apiKey.substring(0, 4)}... (${apiKey.length} chars)');
  print('');

  // Clean up old data directories
  await _cleanup();

  // Process each data type
  for (final entry in dataTypes.entries) {
    final dataType = entry.key;
    final config = entry.value;
    
    print('\n📊 Processing $dataType...');
    await _processDataType(
      apiKey: apiKey,
      dataType: dataType,
      endpoint: config['endpoint'] as String,
      hasCoordinates: config['hasCoordinates'] as bool,
    );
  }

  // Clean up temporary files
  await _finalCleanup();

  stopwatch.stop();
  print('\n✅ All data prepared successfully!');
  print('⏱️  Total time: ${stopwatch.elapsed.inMinutes}m ${stopwatch.elapsed.inSeconds % 60}s');
  print('');
  print('📁 Data is ready in: assets/data/tiles/');
  print('🚮 Temporary files have been cleaned up');
  print('');
  print('ℹ️  Note: This downloads global data. Some regions may have sparse coverage.');
  print('   If you need specific regions, consider filtering by bbox in the API calls.');
}

Future<void> _cleanup() async {
  print('\n🧹 Cleaning up old data...');
  
  // Remove old directories
  final oldDirs = [
    Directory('assets/data/tiles'),
    Directory('assets/data/tiles_csv'),
  ];
  
  for (final dir in oldDirs) {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      print('   ❌ Removed ${dir.path}');
    }
  }
  
  // Create fresh tiles directory
  final tilesDir = Directory('assets/data/tiles');
  await tilesDir.create(recursive: true);
  print('   ✅ Created fresh tiles directory');
}

Future<void> _processDataType({
  required String apiKey,
  required String dataType,
  required String endpoint,
  required bool hasCoordinates,
}) async {
  final allItems = <Map<String, dynamic>>[];
  
  // Download data from API
  print('   📥 Downloading from API...');
  
  if (hasCoordinates) {
    // Download by tiles for data with coordinates
    await _downloadByTiles(
      apiKey: apiKey,
      endpoint: endpoint,
      allItems: allItems,
    );
  } else {
    // Download all at once for data without coordinates
    await _downloadAll(
      apiKey: apiKey,
      endpoint: endpoint,
      allItems: allItems,
    );
  }
  
  print('   📊 Downloaded ${allItems.length} items');
  
  if (allItems.isEmpty) {
    print('   ⚠️  No data found, skipping...');
    return;
  }
  
  // Split into tiles and save as CSV
  if (hasCoordinates) {
    await _splitAndSaveAsCsv(dataType, allItems);
  } else {
    // For data without coordinates, save as single compressed CSV
    await _saveAsCompressedCsv(dataType, allItems);
  }
}

Future<void> _downloadByTiles({
  required String apiKey,
  required String endpoint,
  required List<Map<String, dynamic>> allItems,
}) async {
  const int totalTiles = tilesX * tilesY;
  int completedTiles = 0;
  
  for (int y = 0; y < tilesY; y++) {
    for (int x = 0; x < tilesX; x++) {
      // Calculate tile boundaries
      final minLon = -180.0 + (x * tileWidth);
      final maxLon = minLon + tileWidth;
      final minLat = -90.0 + (y * tileHeight);
      final maxLat = minLat + tileHeight;
      
      completedTiles++;
      
      try {
        final items = await _fetchTile(
          apiKey: apiKey,
          endpoint: endpoint,
          bbox: [minLon, minLat, maxLon, maxLat],
        );
        
        allItems.addAll(items);
        
        // Progress indicator
        if (completedTiles % 10 == 0) {
          stdout.write('\r   📍 Progress: $completedTiles/$totalTiles tiles');
        }
      } catch (e) {
        // Continue on error
      }
      
      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  stdout.write('\r   ✅ Downloaded all tiles                    \n');
}

Future<List<Map<String, dynamic>>> _fetchTile({
  required String apiKey,
  required String endpoint,
  required List<double> bbox,
}) async {
  final items = <Map<String, dynamic>>[];
  int page = 1;
  bool hasMore = true;
  
  while (hasMore) {
    final queryParams = {
      'page': page.toString(),
      'limit': '1000',
      'bbox': bbox.join(','),
    };
    
    final uri = Uri.parse('$_baseUrl$endpoint')
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
      final List<dynamic> pageItems = data['items'] ?? data['data'] ?? data ?? [];
      
      if (pageItems.isEmpty || pageItems.length < 1000) {
        hasMore = false;
      }
      
      items.addAll(pageItems.cast<Map<String, dynamic>>());
      page++;
    } else if (response.statusCode == 429) {
      // Rate limit - wait and retry
      await Future.delayed(const Duration(seconds: 60));
    } else {
      hasMore = false;
    }
  }
  
  return items;
}

Future<void> _downloadAll({
  required String apiKey,
  required String endpoint,
  required List<Map<String, dynamic>> allItems,
}) async {
  int page = 1;
  bool hasMore = true;
  
  while (hasMore) {
    final queryParams = {
      'page': page.toString(),
      'limit': '1000',
    };
    
    final uri = Uri.parse('$_baseUrl$endpoint')
        .replace(queryParameters: queryParams);
    
    stdout.write('\r   📄 Downloading page $page...');
    
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
      
      if (items.isEmpty || items.length < 1000) {
        hasMore = false;
      }
      
      allItems.addAll(items.cast<Map<String, dynamic>>());
      page++;
      
      await Future.delayed(const Duration(milliseconds: 500));
    } else if (response.statusCode == 429) {
      stdout.write('\r   ⏳ Rate limit hit, waiting...     ');
      await Future.delayed(const Duration(seconds: 60));
    } else {
      hasMore = false;
    }
  }
  stdout.write('\r                                        \r');
}

Future<void> _splitAndSaveAsCsv(
  String dataType,
  List<Map<String, dynamic>> items,
) async {
  print('   🔄 Converting to CSV and splitting into tiles...');
  
  // Create output directory
  final outputDir = Directory('assets/data/tiles/$dataType');
  await outputDir.create(recursive: true);
  
  // Define CSV headers
  final headers = _getCsvHeaders(dataType);
  
  // Group items by tile
  final tileData = <String, List<List<dynamic>>>{};
  int skippedItems = 0;
  
  for (final item in items) {
    final coords = _getCoordinates(item, dataType);
    if (coords == null) {
      skippedItems++;
      continue;
    }
    
    final tileKey = _getTileKey(coords.latitude, coords.longitude);
    final csvRow = _convertToCsvRow(item, dataType);
    if (csvRow != null) {
      tileData.putIfAbsent(tileKey, () => []).add(csvRow);
    }
  }
  
  if (skippedItems > 0) {
    print('   ⚠️  Skipped $skippedItems items without coordinates');
  }
  
  // Save each tile
  int totalSaved = 0;
  for (final entry in tileData.entries) {
    final tileKey = entry.key;
    final tileRows = entry.value;
    
    // Create CSV content
    final csvData = [headers, ...tileRows];
    final csv = const ListToCsvConverter().convert(csvData);
    
    // Save compressed file
    final outputFile = File('${outputDir.path}/tile_$tileKey.csv.gz');
    final csvBytes = utf8.encode(csv);
    final gzipData = gzip.encode(csvBytes);
    await outputFile.writeAsBytes(gzipData);
    
    totalSaved += tileRows.length;
  }
  
  // Create index file
  final index = {
    'version': 1,
    'format': 'csv',
    'dataType': dataType,
    'headers': headers,
    'tileSize': {'width': tileWidth, 'height': tileHeight},
    'tilesX': tilesX,
    'tilesY': tilesY,
    'tiles': tileData.keys.toList()..sort(),
    'totalItems': totalSaved,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  };
  
  final indexFile = File('${outputDir.path}/index.json');
  await indexFile.writeAsString(json.encode(index));
  
  print('   ✅ Saved $totalSaved items in ${tileData.length} tiles');
}

Future<void> _saveAsCompressedCsv(
  String dataType,
  List<Map<String, dynamic>> items,
) async {
  print('   🔄 Converting to CSV...');
  
  // Create output directory
  final outputDir = Directory('assets/data/tiles/$dataType');
  await outputDir.create(recursive: true);
  
  // Define CSV headers
  final headers = _getCsvHeaders(dataType);
  
  // Convert items to CSV rows
  final csvRows = <List<dynamic>>[];
  for (final item in items) {
    final csvRow = _convertToCsvRow(item, dataType);
    if (csvRow != null) {
      csvRows.add(csvRow);
    }
  }
  
  // Create CSV content
  final csvData = [headers, ...csvRows];
  final csv = const ListToCsvConverter().convert(csvData);
  
  // Save compressed file
  final outputFile = File('${outputDir.path}/all_data.csv.gz');
  final csvBytes = utf8.encode(csv);
  final gzipData = gzip.encode(csvBytes);
  await outputFile.writeAsBytes(gzipData);
  
  // Create index file
  final index = {
    'version': 1,
    'format': 'csv',
    'dataType': dataType,
    'headers': headers,
    'singleFile': true,
    'totalItems': csvRows.length,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  };
  
  final indexFile = File('${outputDir.path}/index.json');
  await indexFile.writeAsString(json.encode(index));
  
  print('   ✅ Saved ${csvRows.length} items');
}

// Get CSV headers for each data type
List<String> _getCsvHeaders(String dataType) {
  switch (dataType) {
    case 'airports':
      return ['id', 'ident', 'type', 'name', 'lat', 'lon', 'elevation_ft', 
              'country', 'municipality', 'scheduled_service', 'gps_code', 
              'iata_code', 'local_code', 'home_link', 'wikipedia_link'];
    
    case 'navaids':
      return ['id', 'ident', 'name', 'type', 'frequency_khz', 'lat', 'lon', 
              'elevation_ft', 'country', 'dme_frequency_khz', 'dme_channel', 
              'magnetic_variation_deg', 'usage_type', 'filename', 
              'associated_airport'];
    
    case 'airspaces':
      return ['id', 'name', 'type', 'country', 'top_altitude_ft', 
              'bottom_altitude_ft', 'geometry_type', 'geometry'];
    
    // Runways and frequencies would be handled here if needed
    // case 'runways':
    //   return [...];
    // case 'frequencies':
    //   return [...];
    
    case 'reporting_points':
      return ['id', 'ident', 'name', 'type', 'lat', 'lon', 'country'];
    
    case 'obstacles':
      return ['id', 'name', 'type', 'lat', 'lon', 'elevation_ft', 'height_ft', 
              'lighted', 'marking', 'country'];
    
    case 'hotspots':
      return ['id', 'name', 'type', 'lat', 'lon', 'elevation_ft', 
              'reliability', 'occurrence', 'conditions', 'country'];
    
    default:
      return [];
  }
}

// Convert item to CSV row
List<dynamic>? _convertToCsvRow(Map<String, dynamic> item, String dataType) {
  try {
    switch (dataType) {
      case 'airports':
        final geom = item['geometry'];
        final coords = geom?['coordinates'] ?? [];
        final props = item['properties'] ?? item;
        return [
          props['_id'] ?? '',
          props['ident'] ?? '',
          props['type'] ?? '',
          props['name'] ?? '',
          coords.length > 1 ? coords[1] : 0,
          coords.length > 0 ? coords[0] : 0,
          props['elevation'] ?? 0,
          props['iso_country'] ?? '',
          props['municipality'] ?? '',
          props['scheduled_service'] ?? 0,
          props['gps_code'] ?? '',
          props['iata_code'] ?? '',
          props['local_code'] ?? '',
          props['home_link'] ?? '',
          props['wikipedia_link'] ?? '',
        ];
      
      case 'navaids':
        return [
          item['id'] ?? '',
          item['ident'] ?? '',
          item['name'] ?? '',
          item['type'] ?? '',
          item['frequency_khz'] ?? 0,
          item['latitude_deg'] ?? 0,
          item['longitude_deg'] ?? 0,
          item['elevation_ft'] ?? 0,
          item['iso_country'] ?? '',
          item['dme_frequency_khz'] ?? 0,
          item['dme_channel'] ?? '',
          item['magnetic_variation_deg'] ?? 0,
          item['usage_type'] ?? '',
          item['filename'] ?? '',
          item['associated_airport'] ?? '',
        ];
      
      case 'airspaces':
        final geom = item['geometry'];
        final props = item['properties'] ?? item;
        final geometryStr = _encodeGeometry(geom);
        return [
          props['_id'] ?? '',
          props['name'] ?? '',
          props['type'] ?? '',
          props['country'] ?? '',
          props['top_altitude_value'] ?? 0,
          props['bottom_altitude_value'] ?? 0,
          geom?['type'] ?? '',
          geometryStr,
        ];
      
      // Runways and frequencies would be handled here if needed
      // case 'runways':
      //   return [...];
      // case 'frequencies':
      //   return [...];
      
      case 'reporting_points':
        final geom = item['geometry'];
        final coords = geom?['coordinates'] ?? [];
        final props = item['properties'] ?? item;
        return [
          props['_id'] ?? '',
          props['ident'] ?? '',
          props['name'] ?? '',
          props['type'] ?? '',
          coords.length > 1 ? coords[1] : 0,
          coords.length > 0 ? coords[0] : 0,
          props['country'] ?? '',
        ];
      
      case 'obstacles':
        final geom = item['geometry'];
        final coords = geom?['coordinates'] ?? [];
        final props = item['properties'] ?? item;
        return [
          props['_id'] ?? '',
          props['name'] ?? '',
          props['type'] ?? '',
          coords.length > 1 ? coords[1] : 0,
          coords.length > 0 ? coords[0] : 0,
          props['elevation'] ?? 0,
          props['height'] ?? 0,
          props['lighted'] ?? 0,
          props['marking'] ?? '',
          props['country'] ?? '',
        ];
      
      case 'hotspots':
        final geom = item['geometry'];
        final coords = geom?['coordinates'] ?? [];
        final props = item['properties'] ?? item;
        return [
          props['_id'] ?? '',
          props['name'] ?? '',
          props['type'] ?? '',
          coords.length > 1 ? coords[1] : 0,
          coords.length > 0 ? coords[0] : 0,
          props['elevation'] ?? 0,
          props['reliability'] ?? '',
          props['occurrence'] ?? '',
          props['conditions'] ?? '',
          props['country'] ?? '',
        ];
      
      default:
        return null;
    }
  } catch (e) {
    return null;
  }
}

// Encode geometry to a compact string format
String _encodeGeometry(Map<String, dynamic>? geometry) {
  if (geometry == null) return '';
  
  final type = geometry['type'];
  final coords = geometry['coordinates'];
  
  if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
    final ring = coords[0] as List;
    final pairs = ring.map((coord) {
      if (coord is List && coord.length >= 2) {
        return '${coord[0]},${coord[1]}';
      }
      return '';
    }).where((s) => s.isNotEmpty).join('|');
    return pairs;
  }
  
  return '';
}

// Get coordinates from item
Coordinates? _getCoordinates(Map<String, dynamic> item, String dataType) {
  switch (dataType) {
    case 'airports':
    case 'reporting_points':
    case 'obstacles':
    case 'hotspots':
      final geometry = item['geometry'];
      if (geometry is Map && geometry['coordinates'] is List) {
        final coords = geometry['coordinates'];
        if (coords.length >= 2) {
          return Coordinates(
            latitude: (coords[1] as num).toDouble(),
            longitude: (coords[0] as num).toDouble(),
          );
        }
      }
      break;
      
    case 'navaids':
      if (item.containsKey('latitude_deg') && item.containsKey('longitude_deg')) {
        final lat = item['latitude_deg'];
        final lon = item['longitude_deg'];
        if (lat != null && lon != null) {
          return Coordinates(
            latitude: (lat as num).toDouble(),
            longitude: (lon as num).toDouble(),
          );
        }
      }
      break;
      
    case 'airspaces':
      final geometry = item['geometry'];
      if (geometry is Map) {
        if (geometry['type'] == 'Polygon' && geometry['coordinates'] is List) {
          final rings = geometry['coordinates'] as List;
          if (rings.isNotEmpty && rings[0] is List && rings[0].isNotEmpty) {
            final firstCoord = rings[0][0];
            if (firstCoord is List && firstCoord.length >= 2) {
              return Coordinates(
                latitude: (firstCoord[1] as num).toDouble(),
                longitude: (firstCoord[0] as num).toDouble(),
              );
            }
          }
        }
      }
      break;
  }
  
  return null;
}

// Get tile key for given coordinates
String _getTileKey(double lat, double lon) {
  // Normalize longitude to [0, 360)
  while (lon < -180) {
    lon += 360;
  }
  while (lon >= 180) {
    lon -= 360;
  }
  
  // Calculate tile indices
  final x = ((lon + 180) / tileWidth).floor();
  final y = ((lat + 90) / tileHeight).floor();
  
  // Clamp to valid range
  final tileX = x.clamp(0, tilesX - 1);
  final tileY = y.clamp(0, tilesY - 1);
  
  return '${tileX}_$tileY';
}

Future<void> _finalCleanup() async {
  print('\n🧹 Final cleanup...');
  
  // Remove old JSON files
  final jsonFiles = [
    'assets/data/airports.json',
    'assets/data/airports.json.gz',
    'assets/data/airports_min.json.gz',
    'assets/data/airspaces.json',
    'assets/data/airspaces.json.gz',
    'assets/data/airspaces_min.json.gz',
    'assets/data/navaids.json',
    'assets/data/navaids.json.gz',
    'assets/data/navaids_min.json.gz',
    'assets/data/runways.json',
    'assets/data/runways.json.gz',
    'assets/data/runways_min.json.gz',
    'assets/data/frequencies.json',
    'assets/data/frequencies.json.gz',
    'assets/data/frequencies_min.json.gz',
    'assets/data/reporting_points.json',
    'assets/data/reporting_points.json.gz',
    'assets/data/reporting_points_min.json.gz',
  ];
  
  for (final path in jsonFiles) {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      print('   ❌ Removed $path');
    }
  }
  
  // Remove progress files
  final progressFiles = await Directory('scripts')
      .list()
      .where((entity) => entity.path.contains('_progress.json'))
      .toList();
  
  for (final file in progressFiles) {
    if (file is File) {
      await file.delete();
      print('   ❌ Removed ${file.path}');
    }
  }
  
  print('   ✅ Cleanup complete');
}

class Coordinates {
  final double latitude;
  final double longitude;
  
  Coordinates({required this.latitude, required this.longitude});
}