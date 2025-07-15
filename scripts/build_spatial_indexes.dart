#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

/// Spatial index builder
class SpatialIndexBuilder {
  static const double gridSize = 0.1;
  final Map<String, List<String>> _gridIndex = {};
  final Map<String, List<double>> _boundingBoxes = {};
  final Map<String, Map<String, dynamic>> _metadata = {};
  
  void addItem({
    required String id,
    required List<double> boundingBox,
    Map<String, dynamic>? metadata,
  }) {
    _boundingBoxes[id] = boundingBox;
    if (metadata != null) {
      _metadata[id] = metadata;
    }
    
    final cells = _getCellsForBoundingBox(boundingBox);
    for (final cell in cells) {
      _gridIndex.putIfAbsent(cell, () => []).add(id);
    }
  }
  
  Map<String, dynamic> build() {
    print('📊 Grid cells: ${_gridIndex.length}');
    print('📊 Total items: ${_boundingBoxes.length}');
    
    // Calculate statistics
    int totalReferences = 0;
    int maxReferences = 0;
    _gridIndex.forEach((cell, items) {
      totalReferences += items.length;
      if (items.length > maxReferences) {
        maxReferences = items.length;
      }
    });
    
    print('📊 Average items per cell: ${(totalReferences / _gridIndex.length).toStringAsFixed(1)}');
    print('📊 Max items in a cell: $maxReferences');
    
    return {
      'version': 1,
      'gridSize': gridSize,
      'gridIndex': _gridIndex,
      'boundingBoxes': _boundingBoxes,
      'metadata': _metadata,
    };
  }
  
  List<String> _getCellsForBoundingBox(List<double> bbox) {
    final cells = <String>[];
    
    final startLat = (bbox[0] / gridSize).floor();
    final endLat = (bbox[2] / gridSize).ceil();
    final startLng = (bbox[1] / gridSize).floor();
    final endLng = (bbox[3] / gridSize).ceil();
    
    for (int lat = startLat; lat <= endLat; lat++) {
      for (int lng = startLng; lng <= endLng; lng++) {
        cells.add('${lat}_$lng');
      }
    }
    
    return cells;
  }
}

/// Calculate bounding box from geometry
List<double> calculateBoundingBox(dynamic geometry) {
  double minLat = 90;
  double maxLat = -90;
  double minLon = 180;
  double maxLon = -180;
  
  if (geometry is Map && geometry['type'] == 'Polygon') {
    final coordinates = geometry['coordinates'] as List;
    for (final ring in coordinates) {
      for (final point in ring) {
        final lon = point[0].toDouble();
        final lat = point[1].toDouble();
        
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lon < minLon) minLon = lon;
        if (lon > maxLon) maxLon = lon;
      }
    }
  } else if (geometry is Map && geometry['type'] == 'Point') {
    final coords = geometry['coordinates'] as List;
    minLon = maxLon = coords[0].toDouble();
    minLat = maxLat = coords[1].toDouble();
  }
  
  return [minLat, minLon, maxLat, maxLon];
}

/// Build spatial index for airspaces
Future<void> buildAirspaceIndex() async {
  print('\n🌍 Building airspace spatial index...');
  
  final inputFile = File('assets/data/airspaces_min.json.gz');
  if (!await inputFile.exists()) {
    print('❌ Airspaces data not found. Run download scripts first.');
    return;
  }
  
  // Read and decompress
  final compressed = await inputFile.readAsBytes();
  final decompressed = gzip.decode(compressed);
  final data = json.decode(utf8.decode(decompressed));
  
  final builder = SpatialIndexBuilder();
  final airspaces = data['airspaces'] as List;
  
  print('📍 Processing ${airspaces.length} airspaces...');
  
  for (final airspace in airspaces) {
    final id = airspace['_id'] ?? '';
    final geometry = airspace['geometry'];
    
    if (geometry != null) {
      final bbox = calculateBoundingBox(geometry);
      
      builder.addItem(
        id: id,
        boundingBox: bbox,
        metadata: {
          'type': airspace['type'],
          'icaoClass': airspace['icaoClass'],
          'activity': airspace['activity'],
        },
      );
    }
  }
  
  final index = builder.build();
  
  // Save the index
  final outputFile = File('assets/data/airspaces_index.json.gz');
  final indexJson = json.encode(index);
  final compressedIndex = gzip.encode(utf8.encode(indexJson));
  await outputFile.writeAsBytes(compressedIndex);
  
  final originalSize = indexJson.length;
  final compressedSize = compressedIndex.length;
  print('✅ Spatial index saved: ${(compressedSize / 1024).toStringAsFixed(1)} KB');
  print('   Compression: ${(100 - (compressedSize / originalSize * 100)).toStringAsFixed(1)}%');
}

/// Build spatial index for airports
Future<void> buildAirportIndex() async {
  print('\n✈️  Building airport spatial index...');
  
  final inputFile = File('assets/data/airports_min.json.gz');
  if (!await inputFile.exists()) {
    print('❌ Airports data not found. Run download scripts first.');
    return;
  }
  
  // Read and decompress
  final compressed = await inputFile.readAsBytes();
  final decompressed = gzip.decode(compressed);
  final data = json.decode(utf8.decode(decompressed));
  
  final builder = SpatialIndexBuilder();
  final airports = data['airports'] as List;
  
  print('📍 Processing ${airports.length} airports...');
  
  for (final airport in airports) {
    final id = airport['_id'] ?? airport['icao'] ?? '';
    final coords = airport['g'];
    
    if (coords != null && coords.length >= 2) {
      final lat = coords[1].toDouble();
      final lon = coords[0].toDouble();
      
      // Small bounding box for point data
      builder.addItem(
        id: id,
        boundingBox: [lat, lon, lat, lon],
        metadata: {
          'type': airport['type'],
          'icao': airport['icao'],
        },
      );
    }
  }
  
  final index = builder.build();
  
  // Save the index
  final outputFile = File('assets/data/airports_index.json.gz');
  final indexJson = json.encode(index);
  final compressedIndex = gzip.encode(utf8.encode(indexJson));
  await outputFile.writeAsBytes(compressedIndex);
  
  final originalSize = indexJson.length;
  final compressedSize = compressedIndex.length;
  print('✅ Spatial index saved: ${(compressedSize / 1024).toStringAsFixed(1)} KB');
  print('   Compression: ${(100 - (compressedSize / originalSize * 100)).toStringAsFixed(1)}%');
}

/// Build spatial index for reporting points
Future<void> buildReportingPointIndex() async {
  print('\n📍 Building reporting point spatial index...');
  
  final inputFile = File('assets/data/reporting_points_min.json.gz');
  if (!await inputFile.exists()) {
    print('❌ Reporting points data not found. Run download scripts first.');
    return;
  }
  
  // Read and decompress
  final compressed = await inputFile.readAsBytes();
  final decompressed = gzip.decode(compressed);
  final data = json.decode(utf8.decode(decompressed));
  
  final builder = SpatialIndexBuilder();
  final points = data['reporting_points'] as List;
  
  print('📍 Processing ${points.length} reporting points...');
  
  for (final point in points) {
    final id = point['_id'] ?? '';
    final coords = point['g'];
    
    if (coords != null && coords.length >= 2) {
      final lat = coords[1].toDouble();
      final lon = coords[0].toDouble();
      
      // Small bounding box for point data
      builder.addItem(
        id: id,
        boundingBox: [lat, lon, lat, lon],
        metadata: {
          'name': point['name'],
          'code': point['code'],
        },
      );
    }
  }
  
  final index = builder.build();
  
  // Save the index
  final outputFile = File('assets/data/reporting_points_index.json.gz');
  final indexJson = json.encode(index);
  final compressedIndex = gzip.encode(utf8.encode(indexJson));
  await outputFile.writeAsBytes(compressedIndex);
  
  final originalSize = indexJson.length;
  final compressedSize = compressedIndex.length;
  print('✅ Spatial index saved: ${(compressedSize / 1024).toStringAsFixed(1)} KB');
  print('   Compression: ${(100 - (compressedSize / originalSize * 100)).toStringAsFixed(1)}%');
}

void main() async {
  print('🚀 Building spatial indexes for bundled data...');
  print('=' * 60);
  
  final stopwatch = Stopwatch()..start();
  
  await buildAirspaceIndex();
  await buildAirportIndex();
  await buildReportingPointIndex();
  
  stopwatch.stop();
  
  print('\n${'=' * 60}');
  print('✅ All spatial indexes built successfully!');
  print('⏱️  Total time: ${stopwatch.elapsed.inSeconds}s');
  print('\n📝 Next steps:');
  print('1. Add the index files to pubspec.yaml:');
  print('   - assets/data/airspaces_index.json.gz');
  print('   - assets/data/airports_index.json.gz');
  print('   - assets/data/reporting_points_index.json.gz');
  print('2. Update the services to load pre-built indexes');
}