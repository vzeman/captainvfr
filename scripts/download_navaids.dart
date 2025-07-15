#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to download all navaids from OurAirports and save to a JSON file
/// This file will be bundled with the app for offline use
/// 
/// Usage: dart scripts/download_navaids.dart

const String _navaidsUrl = 'https://davidmegginson.github.io/ourairports-data/navaids.csv';

void main(List<String> args) async {
  print('🚀 Starting navaids download...');
  print('📍 Source: OurAirports');

  final stopwatch = Stopwatch()..start();
  
  try {
    // Download CSV data
    print('\n📡 Fetching navaids CSV...');
    final response = await http.get(Uri.parse(_navaidsUrl))
        .timeout(const Duration(seconds: 30));
    
    if (response.statusCode != 200) {
      throw Exception('Failed to download navaids: ${response.statusCode}');
    }
    
    print('✅ Successfully downloaded navaids CSV');
    
    // Parse CSV
    final lines = const LineSplitter().convert(response.body);
    print('📄 Parsed ${lines.length} lines from CSV');
    
    if (lines.isEmpty) {
      throw Exception('CSV file is empty');
    }
    
    // Skip header and parse navaids
    final navaids = <Map<String, dynamic>>[];
    int invalidCount = 0;
    
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      
      try {
        final navaid = _parseNavaidFromCsv(line);
        if (navaid != null) {
          navaids.add(navaid);
        } else {
          invalidCount++;
        }
      } catch (e) {
        invalidCount++;
        print('⚠️  Error parsing line $i: $e');
      }
    }
    
    print('\n📊 Parsing complete:');
    print('✅ Valid navaids parsed: ${navaids.length}');
    print('❌ Invalid entries: $invalidCount');
    
    // Remove duplicates based on combination of ident and type
    print('\n🔍 Removing duplicates...');
    final uniqueNavaids = <String, Map<String, dynamic>>{};
    final duplicateCount = <String, int>{};
    
    for (final navaid in navaids) {
      // Create unique key from ident and type (some navaids share location but different type)
      final ident = navaid['ident']?.toString() ?? '';
      final type = navaid['type']?.toString() ?? '';
      final lat = navaid['latitude_deg']?.toString() ?? '';
      final lon = navaid['longitude_deg']?.toString() ?? '';
      
      // Use combination of fields as unique key
      final uniqueKey = '$ident|$type|$lat|$lon';
      
      if (uniqueNavaids.containsKey(uniqueKey)) {
        duplicateCount[uniqueKey] = (duplicateCount[uniqueKey] ?? 1) + 1;
      } else {
        uniqueNavaids[uniqueKey] = navaid;
      }
    }
    
    final totalDuplicates = navaids.length - uniqueNavaids.length;
    final uniqueNavaidsList = uniqueNavaids.values.toList();
    
    print('✅ Unique navaids: ${uniqueNavaidsList.length}');
    print('🔄 Duplicates removed: $totalDuplicates');
    
    if (duplicateCount.isNotEmpty && totalDuplicates > 0) {
      final topDuplicates = duplicateCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      print('📊 Top duplicated navaids:');
      for (var i = 0; i < 5 && i < topDuplicates.length; i++) {
        final entry = topDuplicates[i];
        final parts = entry.key.split('|');
        if (parts.isNotEmpty) {
          print('   - ${parts[0]} (${parts.length > 1 ? parts[1] : ""}): ${entry.value} duplicates');
        }
      }
    }
    
    // Save to file
    final outputFile = File('assets/data/navaids.json');
    await outputFile.parent.create(recursive: true);
    
    final outputData = {
      'version': 1,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'total_navaids': uniqueNavaidsList.length,
      'source': 'OurAirports',
      'navaids': uniqueNavaidsList,
    };
    
    await outputFile.writeAsString(json.encode(outputData));
    print('\n💾 Saved to: ${outputFile.path}');
    
    // Calculate file size
    final fileSize = await outputFile.length();
    final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(2);
    print('📦 File size: $fileSizeMB MB');
    
    // Create compressed version
    final compressedFile = File('assets/data/navaids.json.gz');
    final gzipData = gzip.encode(utf8.encode(json.encode(outputData)));
    await compressedFile.writeAsBytes(gzipData);
    
    final compressedSize = await compressedFile.length();
    final compressedSizeMB = (compressedSize / 1024 / 1024).toStringAsFixed(2);
    print('🗜️  Compressed size: $compressedSizeMB MB (${(compressedSize / fileSize * 100).toStringAsFixed(1)}% of original)');
    
    stopwatch.stop();
    
    print('\n${'=' * 60}');
    print('📊 DOWNLOAD COMPLETE');
    print('=' * 60);
    print('✅ Total unique navaids: ${uniqueNavaidsList.length}');
    print('⏱️  Time taken: ${stopwatch.elapsed.inSeconds}s');
    
    // Automatically run compression
    print('\n🗜️  Running compression script...');
    final compressResult = await Process.run('dart', ['scripts/prepare_compressed_data.dart']);
    
    if (compressResult.exitCode == 0) {
      print('✅ Compression complete! Compressed file ready at: assets/data/navaids_min.json.gz');
    } else {
      print('⚠️  Compression failed. Run manually: dart scripts/prepare_compressed_data.dart');
      print('Error: ${compressResult.stderr}');
    }
    
    print('\n✅ Done! Navaids are ready to be bundled with the app.');
    print('📝 Remember to add assets/data/navaids.json to pubspec.yaml');
    
  } catch (e, stackTrace) {
    print('\n❌ Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

Map<String, dynamic>? _parseNavaidFromCsv(String csvLine) {
  final parts = csvLine.split(',');
  if (parts.length < 19) {
    return null;
  }
  
  // Parse values
  final lat = double.tryParse(parts[6]) ?? 0.0;
  final lon = double.tryParse(parts[7]) ?? 0.0;
  
  // Skip navaids without valid coordinates
  if (lat == 0.0 && lon == 0.0) {
    return null;
  }
  
  return {
    'id': int.tryParse(parts[0]) ?? 0,
    'filename': parts[1].replaceAll('"', '').trim(),
    'ident': parts[2].replaceAll('"', '').trim(),
    'name': parts[3].replaceAll('"', '').trim(),
    'type': parts[4].replaceAll('"', '').trim(),
    'frequency_khz': double.tryParse(parts[5]) ?? 0.0,
    'latitude_deg': lat,
    'longitude_deg': lon,
    'elevation_ft': int.tryParse(parts[8]) ?? 0,
    'iso_country': parts[9].replaceAll('"', '').trim(),
    'dme_frequency_khz': double.tryParse(parts[10]) ?? 0.0,
    'dme_channel': parts[11].replaceAll('"', '').trim(),
    'dme_latitude_deg': int.tryParse(parts[12]) ?? 0,
    'dme_longitude_deg': int.tryParse(parts[13]) ?? 0,
    'dme_elevation_ft': int.tryParse(parts[14]) ?? 0,
    'slaved_variation_deg': double.tryParse(parts[15]) ?? 0.0,
    'magnetic_variation_deg': double.tryParse(parts[16]) ?? 0.0,
    'usage_type': parts[17].replaceAll('"', '').trim(),
    'power': double.tryParse(parts[18]) ?? 0.0,
    'associated_airport': parts.length > 19
        ? parts[19].replaceAll('"', '').trim()
        : '',
  };
}