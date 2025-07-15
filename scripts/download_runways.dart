#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to download all runways from OurAirports and save to a JSON file
/// This file will be bundled with the app for offline use
/// 
/// Usage: dart scripts/download_runways.dart

const String _runwaysUrl = 'https://davidmegginson.github.io/ourairports-data/runways.csv';

void main(List<String> args) async {
  print('🚀 Starting runways download...');
  print('📍 Source: OurAirports');

  final stopwatch = Stopwatch()..start();
  
  try {
    // Download CSV data
    print('\n📡 Fetching runways CSV...');
    final response = await http.get(Uri.parse(_runwaysUrl))
        .timeout(const Duration(seconds: 30));
    
    if (response.statusCode != 200) {
      throw Exception('Failed to download runways: ${response.statusCode}');
    }
    
    print('✅ Successfully downloaded runways CSV');
    
    // Parse CSV
    final lines = const LineSplitter().convert(response.body);
    print('📄 Parsed ${lines.length} lines from CSV');
    
    if (lines.isEmpty) {
      throw Exception('CSV file is empty');
    }
    
    // Get headers
    final headers = _parseCsvRow(lines[0]);
    print('📊 Headers: ${headers.join(", ")}');
    
    // Parse runways
    final runways = <Map<String, dynamic>>[];
    int invalidCount = 0;
    
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      
      try {
        final runway = _parseRunwayFromCsv(line, headers);
        if (runway != null) {
          runways.add(runway);
        } else {
          invalidCount++;
        }
      } catch (e) {
        invalidCount++;
        print('⚠️  Error parsing line $i: $e');
      }
    }
    
    print('\n📊 Parsing complete:');
    print('✅ Valid runways parsed: ${runways.length}');
    print('❌ Invalid entries: $invalidCount');
    
    // Remove duplicates based on combination of airport and runway designation
    print('\n🔍 Removing duplicates...');
    final uniqueRunways = <String, Map<String, dynamic>>{};
    final duplicateCount = <String, int>{};
    
    for (final runway in runways) {
      // Create unique key from airport and runway IDs
      final airportIdent = runway['airport_ident']?.toString() ?? '';
      final leIdent = runway['le_ident']?.toString() ?? '';
      final heIdent = runway['he_ident']?.toString() ?? '';
      final id = runway['id']?.toString() ?? '';
      
      // Use combination of fields as unique key
      final uniqueKey = '$airportIdent|$leIdent|$heIdent|$id';
      
      if (uniqueRunways.containsKey(uniqueKey)) {
        duplicateCount[uniqueKey] = (duplicateCount[uniqueKey] ?? 1) + 1;
      } else {
        uniqueRunways[uniqueKey] = runway;
      }
    }
    
    final totalDuplicates = runways.length - uniqueRunways.length;
    final uniqueRunwaysList = uniqueRunways.values.toList();
    
    print('✅ Unique runways: ${uniqueRunwaysList.length}');
    print('🔄 Duplicates removed: $totalDuplicates');
    
    if (duplicateCount.isNotEmpty && totalDuplicates > 0) {
      final topDuplicates = duplicateCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      print('📊 Top duplicated runways:');
      for (var i = 0; i < 5 && i < topDuplicates.length; i++) {
        final entry = topDuplicates[i];
        final parts = entry.key.split('|');
        if (parts.length >= 3) {
          print('   - ${parts[0]} ${parts[1]}/${parts[2]}: ${entry.value} duplicates');
        }
      }
    }
    
    // Group by airport for efficient lookup
    print('\n🗂️  Grouping runways by airport...');
    final runwaysByAirport = <String, List<Map<String, dynamic>>>{};
    for (final runway in uniqueRunwaysList) {
      final airportIdent = runway['airport_ident'] ?? '';
      if (airportIdent.isNotEmpty) {
        runwaysByAirport.putIfAbsent(airportIdent, () => []).add(runway);
      }
    }
    print('✅ Grouped into ${runwaysByAirport.length} airports');
    
    // Save to file
    final outputFile = File('assets/data/runways.json');
    await outputFile.parent.create(recursive: true);
    
    final outputData = {
      'version': 1,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'total_runways': uniqueRunwaysList.length,
      'total_airports': runwaysByAirport.length,
      'source': 'OurAirports',
      'runways': uniqueRunwaysList,
      'by_airport': runwaysByAirport,
    };
    
    await outputFile.writeAsString(json.encode(outputData));
    print('\n💾 Saved to: ${outputFile.path}');
    
    // Calculate file size
    final fileSize = await outputFile.length();
    final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(2);
    print('📦 File size: $fileSizeMB MB');
    
    // Create compressed version
    final compressedFile = File('assets/data/runways.json.gz');
    final gzipData = gzip.encode(utf8.encode(json.encode(outputData)));
    await compressedFile.writeAsBytes(gzipData);
    
    final compressedSize = await compressedFile.length();
    final compressedSizeMB = (compressedSize / 1024 / 1024).toStringAsFixed(2);
    print('🗜️  Compressed size: $compressedSizeMB MB (${(compressedSize / fileSize * 100).toStringAsFixed(1)}% of original)');
    
    stopwatch.stop();
    
    print('\n${'=' * 60}');
    print('📊 DOWNLOAD COMPLETE');
    print('=' * 60);
    print('✅ Total unique runways: ${uniqueRunwaysList.length}');
    print('✅ Airports with runways: ${runwaysByAirport.length}');
    print('⏱️  Time taken: ${stopwatch.elapsed.inSeconds}s');
    
    // Automatically run compression
    print('\n🗜️  Running compression script...');
    final compressResult = await Process.run('dart', ['scripts/prepare_compressed_data.dart']);
    
    if (compressResult.exitCode == 0) {
      print('✅ Compression complete! Compressed file ready at: assets/data/runways_min.json.gz');
    } else {
      print('⚠️  Compression failed. Run manually: dart scripts/prepare_compressed_data.dart');
      print('Error: ${compressResult.stderr}');
    }
    
    print('\n✅ Done! Runways are ready to be bundled with the app.');
    print('📝 Remember to add assets/data/runways.json to pubspec.yaml');
    
  } catch (e, stackTrace) {
    print('\n❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

Map<String, dynamic>? _parseRunwayFromCsv(String csvLine, List<String> headers) {
  final values = _parseCsvRow(csvLine);
  if (values.length < headers.length) {
    return null;
  }
  
  final runway = <String, dynamic>{};
  
  for (int i = 0; i < headers.length && i < values.length; i++) {
    final header = headers[i];
    final value = values[i];
    
    // Parse specific fields with correct types
    switch (header) {
      case 'id':
      case 'length_ft':
      case 'width_ft':
      case 'le_elevation_ft':
      case 'le_displaced_threshold_ft':
      case 'he_elevation_ft':
      case 'he_displaced_threshold_ft':
        runway[header] = value.isNotEmpty ? int.tryParse(value) : null;
        break;
      case 'le_latitude_deg':
      case 'le_longitude_deg':
      case 'le_heading_degT':
      case 'he_latitude_deg':
      case 'he_longitude_deg':
      case 'he_heading_degT':
        runway[header] = value.isNotEmpty ? double.tryParse(value) : null;
        break;
      case 'lighted':
      case 'closed':
        runway[header] = value == '1';
        break;
      default:
        runway[header] = value;
    }
  }
  
  // Skip runways without valid airport identifier
  if (runway['airport_ident'] == null || runway['airport_ident'].toString().isEmpty) {
    return null;
  }
  
  return runway;
}

List<String> _parseCsvRow(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  bool inQuotes = false;
  
  for (int i = 0; i < line.length; i++) {
    final char = line[i];
    
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  
  // Don't forget the last field
  fields.add(buffer.toString());
  
  return fields;
}