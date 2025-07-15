#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

/// Script to prepare highly compressed data files for distribution
/// This reduces the bundled data size significantly

void main() async {
  print('🗜️  Preparing compressed data for distribution...\n');

  // Process airports
  await processDataFile(
    'assets/data/airports.json',
    'assets/data/airports_min.json.gz',
    'airports',
  );

  // Process airspaces
  await processDataFile(
    'assets/data/airspaces.json',
    'assets/data/airspaces_min.json.gz',
    'airspaces',
  );

  // Process reporting points
  await processDataFile(
    'assets/data/reporting_points.json',
    'assets/data/reporting_points_min.json.gz',
    'reporting_points',
  );

  // Process frequencies
  await processDataFile(
    'assets/data/frequencies.json',
    'assets/data/frequencies_min.json.gz',
    'frequencies',
  );

  // Process navaids
  await processDataFile(
    'assets/data/navaids.json',
    'assets/data/navaids_min.json.gz',
    'navaids',
  );

  // Process runways
  await processDataFile(
    'assets/data/runways.json',
    'assets/data/runways_min.json.gz',
    'runways',
  );

  print('');
  print('🏗️  Building spatial indexes...');
  final indexResult = await Process.run('dart', ['scripts/build_spatial_indexes.dart']);
  if (indexResult.exitCode == 0) {
    print('✅ Spatial indexes built successfully');
  } else {
    print('❌ Failed to build spatial indexes');
    print(indexResult.stderr);
  }
  
  print('');
  print('✅ Data preparation complete!');
  print('📝 Update pubspec.yaml to use the _min.json.gz files');
}

Future<void> processDataFile(
  String inputPath,
  String outputPath,
  String dataKey,
) async {
  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    print('❌ Input file not found: $inputPath');
    print('   Run download scripts first!');
    return;
  }

  print('📂 Processing $inputPath...');
  final stopwatch = Stopwatch()..start();

  // Read and parse the original data
  final jsonString = await inputFile.readAsString();
  final data = json.decode(jsonString);
  final items = data[dataKey] as List;

  print('   📊 Original items: ${items.length}');

  // Remove unnecessary fields to reduce size
  final minifiedItems = items.map((item) {
    final minified = <String, dynamic>{};
    
    // Core fields needed for airports
    if (dataKey == 'airports') {
      minified['_id'] = item['_id'] ?? item['id'];
      minified['name'] = item['name'];
      minified['icao'] = item['icaoCode'] ?? item['icao'];
      minified['iata'] = item['iataCode'] ?? item['iata'];
      minified['type'] = item['type'];
      
      // Compress geometry to just lat/lon array
      if (item['geometry'] != null) {
        final coords = item['geometry']['coordinates'];
        if (coords != null && coords.length >= 2) {
          minified['g'] = [coords[0], coords[1]]; // [lon, lat]
        }
      }
      
      // Elevation
      if (item['elevation'] != null) {
        minified['elev'] = item['elevation'];
      }
      
      // Only include if present
      if (item['country'] != null) minified['country'] = item['country'];
      if (item['radio'] != null) minified['radio'] = item['radio'];
      
      // Runways - simplified
      if (item['runways'] != null) {
        final runways = item['runways'] as List;
        minified['rwy'] = runways.map((r) => {
          'des': r['designator'],
          'len': r['length'],
          'wid': r['width'],
          'surf': r['surface'],
        }).toList();
      }
    }
    
    // Core fields needed for airspaces
    else if (dataKey == 'airspaces') {
      minified['_id'] = item['_id'] ?? item['id'];
      minified['name'] = item['name'];
      minified['type'] = item['type'];
      minified['icaoClass'] = item['icaoClass'];
      minified['activity'] = item['activity'];
      minified['geometry'] = item['geometry'];
      
      // Altitude limits - compress format
      if (item['lowerLimit'] != null || item['upperLimit'] != null) {
        final lowerLimit = item['lowerLimit'];
        final upperLimit = item['upperLimit'];
        minified['altLimit'] = {
          'b': lowerLimit != null ? { // bottom
            'v': lowerLimit['value'],
            'u': lowerLimit['unit'],
            'r': lowerLimit['referenceDatum'],
          } : null,
          't': upperLimit != null ? { // top
            'v': upperLimit['value'],
            'u': upperLimit['unit'],
            'r': upperLimit['referenceDatum'],
          } : null,
        };
      }
      
      // Only include if present
      if (item['country'] != null) minified['country'] = item['country'];
      if (item['onDemand'] == true) minified['onDemand'] = true;
      if (item['onRequest'] == true) minified['onRequest'] = true;
      if (item['schedule'] != null) minified['schedule'] = item['schedule'];
    }
    
    // Core fields needed for reporting points
    else if (dataKey == 'reporting_points') {
      minified['_id'] = item['_id'] ?? item['id'];
      minified['name'] = item['name'];
      minified['type'] = item['type'];
      
      // Compress geometry to just lat/lon array
      if (item['geometry'] != null) {
        final coords = item['geometry']['coordinates'];
        if (coords != null && coords.length >= 2) {
          minified['g'] = [coords[0], coords[1]]; // [lon, lat]
        }
      }
      
      // Only include if present
      if (item['country'] != null) minified['country'] = item['country'];
      if (item['description'] != null) minified['desc'] = item['description'];
      if (item['airport'] != null) minified['airport'] = item['airport'];
    }
    
    // Core fields needed for frequencies
    else if (dataKey == 'frequencies') {
      minified['id'] = item['id'];
      minified['airport_ident'] = item['airport_ident'];
      minified['type'] = item['type'];
      minified['description'] = item['description'];
      minified['frequency_mhz'] = item['frequency_mhz'];
    }
    
    // Core fields needed for navaids
    else if (dataKey == 'navaids') {
      minified['id'] = item['id'];
      minified['ident'] = item['ident'];
      minified['name'] = item['name'];
      minified['type'] = item['type'];
      minified['frequency_khz'] = item['frequency_khz'];
      minified['latitude_deg'] = item['latitude_deg'];
      minified['longitude_deg'] = item['longitude_deg'];
      minified['elevation_ft'] = item['elevation_ft'];
      minified['iso_country'] = item['iso_country'];
      
      // Optional fields - only include if present and meaningful
      if (item['dme_frequency_khz'] != null && item['dme_frequency_khz'] > 0) {
        minified['dme_frequency_khz'] = item['dme_frequency_khz'];
      }
      if (item['dme_channel'] != null && item['dme_channel'] != '') {
        minified['dme_channel'] = item['dme_channel'];
      }
      if (item['associated_airport'] != null && item['associated_airport'] != '') {
        minified['associated_airport'] = item['associated_airport'];
      }
      
      // Skip rarely used fields to save space:
      // filename, dme_latitude_deg, dme_longitude_deg, dme_elevation_ft,
      // slaved_variation_deg, magnetic_variation_deg, usage_type, power
    }
    
    // Core fields needed for runways
    else if (dataKey == 'runways') {
      minified['id'] = item['id'];
      minified['airport_ref'] = item['airport_ref'];
      minified['airport_ident'] = item['airport_ident'];
      minified['length_ft'] = item['length_ft'];
      minified['width_ft'] = item['width_ft'];
      minified['surface'] = item['surface'];
      minified['lighted'] = item['lighted'];
      minified['closed'] = item['closed'];
      minified['le_ident'] = item['le_ident'];
      minified['he_ident'] = item['he_ident'];
      
      // Optional fields - only include if present
      if (item['le_latitude_deg'] != null) minified['le_latitude_deg'] = item['le_latitude_deg'];
      if (item['le_longitude_deg'] != null) minified['le_longitude_deg'] = item['le_longitude_deg'];
      if (item['le_elevation_ft'] != null) minified['le_elevation_ft'] = item['le_elevation_ft'];
      if (item['le_heading_degT'] != null) minified['le_heading_degT'] = item['le_heading_degT'];
      if (item['le_displaced_threshold_ft'] != null) minified['le_displaced_threshold_ft'] = item['le_displaced_threshold_ft'];
      
      if (item['he_latitude_deg'] != null) minified['he_latitude_deg'] = item['he_latitude_deg'];
      if (item['he_longitude_deg'] != null) minified['he_longitude_deg'] = item['he_longitude_deg'];
      if (item['he_elevation_ft'] != null) minified['he_elevation_ft'] = item['he_elevation_ft'];
      if (item['he_heading_degT'] != null) minified['he_heading_degT'] = item['he_heading_degT'];
      if (item['he_displaced_threshold_ft'] != null) minified['he_displaced_threshold_ft'] = item['he_displaced_threshold_ft'];
    }
    
    return minified;
  }).toList();

  // Create minified data structure
  final minifiedData = <String, dynamic>{
    'v': 2, // version
    'generated': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    'count': minifiedItems.length,
    dataKey: minifiedItems,
  };
  
  // For frequencies, also include the by_airport map
  if (dataKey == 'frequencies' && data['by_airport'] != null) {
    // Rebuild by_airport map with minified data
    final byAirport = <String, List<Map<String, dynamic>>>{};
    for (final freq in minifiedItems) {
      final airportIdent = freq['airport_ident'] as String?;
      if (airportIdent != null && airportIdent.isNotEmpty) {
        byAirport.putIfAbsent(airportIdent, () => []).add(freq);
      }
    }
    minifiedData['by_airport'] = byAirport;
  }
  
  // For runways, also include the by_airport map
  if (dataKey == 'runways' && data['by_airport'] != null) {
    // Rebuild by_airport map with minified data
    final byAirport = <String, List<Map<String, dynamic>>>{};
    for (final runway in minifiedItems) {
      final airportIdent = runway['airport_ident'] as String?;
      if (airportIdent != null && airportIdent.isNotEmpty) {
        byAirport.putIfAbsent(airportIdent, () => []).add(runway);
      }
    }
    minifiedData['by_airport'] = byAirport;
  }

  // Convert to JSON with no whitespace
  final minifiedJson = json.encode(minifiedData);

  // Compress with maximum compression
  final jsonBytes = utf8.encode(minifiedJson);
  final compressedBytes = gzip.encode(jsonBytes);

  // Save compressed file
  final outputFile = File(outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsBytes(compressedBytes);

  // Calculate sizes
  final originalSize = await inputFile.length();
  final minifiedSize = jsonBytes.length;
  final compressedSize = compressedBytes.length;

  stopwatch.stop();

  print('   ✅ Completed in ${stopwatch.elapsedMilliseconds}ms');
  print('   📏 Original size: ${_formatBytes(originalSize)}');
  print('   📏 Minified size: ${_formatBytes(minifiedSize)} (${(minifiedSize / originalSize * 100).toStringAsFixed(1)}%)');
  print('   📏 Compressed size: ${_formatBytes(compressedSize)} (${(compressedSize / originalSize * 100).toStringAsFixed(1)}%)');
  print('   💾 Saved to: $outputPath\n');
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}