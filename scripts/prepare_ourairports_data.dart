#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

/// Script to download and prepare OurAirports runway and frequency data
/// This data supplements the OpenAIP data with detailed runway and frequency information
/// 
/// Usage: dart scripts/prepare_ourairports_data.dart

const String _baseUrl = 'https://davidmegginson.github.io/ourairports-data';

// Tile configuration (10x10 degrees)
const int tilesX = 36; // 360 degrees / 10 degrees
const int tilesY = 18; // 180 degrees / 10 degrees
const double tileWidth = 10.0;
const double tileHeight = 10.0;

void main(List<String> args) async {
  final stopwatch = Stopwatch()..start();
  
  print('🚀 Starting OurAirports data preparation...');
  print('');
  
  // Process runways
  print('📊 Processing runways...');
  await _processRunways();
  
  // Process frequencies
  print('\n📊 Processing frequencies...');
  await _processFrequencies();
  
  stopwatch.stop();
  print('\n✅ All data prepared successfully!');
  print('⏱️  Total time: ${stopwatch.elapsed.inMinutes}m ${stopwatch.elapsed.inSeconds % 60}s');
  print('');
  print('📁 Data is ready in: assets/data/tiles/runways/ and assets/data/tiles/frequencies/');
}

Future<void> _processRunways() async {
  // Download runways data
  print('   📥 Downloading runways from OurAirports...');
  
  final response = await http.get(
    Uri.parse('$_baseUrl/runways.csv'),
  ).timeout(const Duration(seconds: 60));
  
  if (response.statusCode != 200) {
    print('   ❌ Failed to download runways: ${response.statusCode}');
    return;
  }
  
  print('   ✅ Downloaded runways data');
  
  // Parse CSV
  final lines = const LineSplitter().convert(response.body);
  print('   📄 Parsed ${lines.length} lines from CSV');
  
  if (lines.length <= 1) {
    print('   ⚠️  No runway data found');
    return;
  }
  
  // Get header
  final header = lines[0].split(',');
  print('   📋 CSV Header: ${header.length} columns');
  
  // Create output directory
  final outputDir = Directory('assets/data/tiles/runways');
  await outputDir.create(recursive: true);
  
  // Group runways by airport for efficient storage
  final runwaysByAirport = <String, List<Map<String, dynamic>>>{};
  final airportCoordinates = <String, Coordinates>{};
  int totalRunways = 0;
  
  // Parse runways
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    
    // Parse CSV line properly handling quoted values
    final values = _parseCsvLine(line);
    if (values.length < 16) continue;
    
    try {
      // Extract runway data
      final airportIdent = values[2].replaceAll('"', '').trim();
      final lengthFt = int.tryParse(values[3]) ?? 0;
      final widthFt = int.tryParse(values[4]) ?? 0;
      final surface = values[5].replaceAll('"', '').trim();
      final lighted = values[6] == '1';
      final closed = values[7] == '1';
      final leIdent = values[8].replaceAll('"', '').trim();
      final leLat = double.tryParse(values[9]) ?? 0.0;
      final leLon = double.tryParse(values[10]) ?? 0.0;
      final leElevation = int.tryParse(values[11]) ?? 0;
      final heIdent = values[14].replaceAll('"', '').trim();
      
      // Skip if no valid coordinates
      if (leLat == 0.0 || leLon == 0.0) continue;
      
      // Store airport coordinates (use runway end coordinates as approximation)
      if (!airportCoordinates.containsKey(airportIdent)) {
        airportCoordinates[airportIdent] = Coordinates(
          latitude: leLat,
          longitude: leLon,
        );
      }
      
      // Create runway data
      final runwayData = {
        'airport_ident': airportIdent,
        'length_ft': lengthFt,
        'width_ft': widthFt,
        'surface': surface,
        'lighted': lighted ? 1 : 0,
        'closed': closed ? 1 : 0,
        'le_ident': leIdent,
        'le_latitude_deg': leLat,
        'le_longitude_deg': leLon,
        'le_elevation_ft': leElevation,
        'he_ident': heIdent,
      };
      
      runwaysByAirport.putIfAbsent(airportIdent, () => []).add(runwayData);
      totalRunways++;
    } catch (e) {
      // Skip invalid entries
    }
  }
  
  print('   📊 Parsed $totalRunways runways for ${runwaysByAirport.length} airports');
  
  // Split into tiles based on airport location
  final tileData = <String, List<List<dynamic>>>{};
  
  // Define CSV headers for runway tiles
  final headers = [
    'airport_ident', 'length_ft', 'width_ft', 'surface', 'lighted', 'closed',
    'le_ident', 'le_latitude_deg', 'le_longitude_deg', 'le_elevation_ft', 'he_ident'
  ];
  
  for (final entry in runwaysByAirport.entries) {
    final airportIdent = entry.key;
    final runways = entry.value;
    final coords = airportCoordinates[airportIdent];
    
    if (coords != null) {
      final tileKey = _getTileKey(coords.latitude, coords.longitude);
      
      for (final runway in runways) {
        final csvRow = [
          runway['airport_ident'],
          runway['length_ft'],
          runway['width_ft'],
          runway['surface'],
          runway['lighted'],
          runway['closed'],
          runway['le_ident'],
          runway['le_latitude_deg'],
          runway['le_longitude_deg'],
          runway['le_elevation_ft'],
          runway['he_ident'],
        ];
        tileData.putIfAbsent(tileKey, () => []).add(csvRow);
      }
    }
  }
  
  // Save each tile
  int savedCount = 0;
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
    
    savedCount += tileRows.length;
  }
  
  // Create index file
  final index = {
    'version': 1,
    'format': 'csv',
    'dataType': 'runways',
    'source': 'OurAirports',
    'headers': headers,
    'tileSize': {'width': tileWidth, 'height': tileHeight},
    'tilesX': tilesX,
    'tilesY': tilesY,
    'tiles': tileData.keys.toList()..sort(),
    'totalItems': savedCount,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  };
  
  final indexFile = File('${outputDir.path}/index.json');
  await indexFile.writeAsString(json.encode(index));
  
  print('   ✅ Saved $savedCount runways in ${tileData.length} tiles');
}

Future<void> _processFrequencies() async {
  // Download frequencies data
  print('   📥 Downloading frequencies from OurAirports...');
  
  final response = await http.get(
    Uri.parse('$_baseUrl/airport-frequencies.csv'),
  ).timeout(const Duration(seconds: 60));
  
  if (response.statusCode != 200) {
    print('   ❌ Failed to download frequencies: ${response.statusCode}');
    return;
  }
  
  print('   ✅ Downloaded frequencies data');
  
  // Parse CSV
  final lines = const LineSplitter().convert(response.body);
  print('   📄 Parsed ${lines.length} lines from CSV');
  
  if (lines.length <= 1) {
    print('   ⚠️  No frequency data found');
    return;
  }
  
  // Get header
  final header = lines[0].split(',');
  print('   📋 CSV Header: ${header.length} columns');
  
  // Create output directory
  final outputDir = Directory('assets/data/tiles/frequencies');
  await outputDir.create(recursive: true);
  
  // First pass: get airport coordinates from airports.csv
  print('   📥 Loading airport coordinates...');
  final airportCoordinates = await _loadAirportCoordinates();
  print('   ✅ Loaded coordinates for ${airportCoordinates.length} airports');
  
  // Group frequencies by tile
  final tileData = <String, List<List<dynamic>>>{};
  int totalFrequencies = 0;
  int skippedNoCoords = 0;
  
  // Define CSV headers for frequency tiles
  final headers = [
    'airport_ident', 'type', 'description', 'frequency_mhz'
  ];
  
  // Parse frequencies
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    
    // Parse CSV line properly handling quoted values
    final values = _parseCsvLine(line);
    if (values.length < 6) continue;
    
    try {
      // Extract frequency data
      final airportIdent = values[2].replaceAll('"', '').trim();
      final type = values[3].replaceAll('"', '').trim();
      final description = values[4].replaceAll('"', '').trim();
      final frequencyMhz = double.tryParse(values[5]) ?? 0.0;
      
      // Skip if no frequency
      if (frequencyMhz == 0.0) continue;
      
      // Get airport coordinates
      final coords = airportCoordinates[airportIdent];
      if (coords == null) {
        skippedNoCoords++;
        continue;
      }
      
      // Determine tile
      final tileKey = _getTileKey(coords.latitude, coords.longitude);
      
      // Create CSV row
      final csvRow = [
        airportIdent,
        type,
        description,
        frequencyMhz,
      ];
      
      tileData.putIfAbsent(tileKey, () => []).add(csvRow);
      totalFrequencies++;
    } catch (e) {
      // Skip invalid entries
    }
  }
  
  print('   📊 Parsed $totalFrequencies frequencies');
  if (skippedNoCoords > 0) {
    print('   ⚠️  Skipped $skippedNoCoords frequencies (no airport coordinates)');
  }
  
  // Save each tile
  int savedCount = 0;
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
    
    savedCount += tileRows.length;
  }
  
  // Create index file
  final index = {
    'version': 1,
    'format': 'csv',
    'dataType': 'frequencies',
    'source': 'OurAirports',
    'headers': headers,
    'tileSize': {'width': tileWidth, 'height': tileHeight},
    'tilesX': tilesX,
    'tilesY': tilesY,
    'tiles': tileData.keys.toList()..sort(),
    'totalItems': savedCount,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  };
  
  final indexFile = File('${outputDir.path}/index.json');
  await indexFile.writeAsString(json.encode(index));
  
  print('   ✅ Saved $savedCount frequencies in ${tileData.length} tiles');
}

// Load airport coordinates from OurAirports data
Future<Map<String, Coordinates>> _loadAirportCoordinates() async {
  final coordinates = <String, Coordinates>{};
  
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/airports.csv'),
    ).timeout(const Duration(seconds: 60));
    
    if (response.statusCode == 200) {
      final lines = const LineSplitter().convert(response.body);
      
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().isEmpty) continue;
        
        final values = line.split(',');
        if (values.length >= 6) {
          final ident = values[1].replaceAll('"', '').trim();
          final lat = double.tryParse(values[4]) ?? 0.0;
          final lon = double.tryParse(values[5]) ?? 0.0;
          
          if (lat != 0.0 && lon != 0.0) {
            coordinates[ident] = Coordinates(latitude: lat, longitude: lon);
          }
        }
      }
    }
  } catch (e) {
    print('   ⚠️  Could not load airport coordinates: $e');
  }
  
  return coordinates;
}

// Parse CSV line handling quoted values
List<String> _parseCsvLine(String line) {
  final values = <String>[];
  var current = '';
  var inQuotes = false;
  
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      values.add(current);
      current = '';
    } else {
      current += char;
    }
  }
  
  values.add(current);
  return values;
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

class Coordinates {
  final double latitude;
  final double longitude;
  
  Coordinates({required this.latitude, required this.longitude});
}