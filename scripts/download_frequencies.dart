#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Script to download airport frequencies from OurAirports
/// 
/// This downloads the airport-frequencies.csv file and converts it to JSON

const String frequenciesUrl = 'https://davidmegginson.github.io/ourairports-data/airport-frequencies.csv';

void main() async {
  print('🚀 Starting frequencies download...');
  print('📍 Source: OurAirports');
  print('📏 Format: CSV');
  print('\n');

  final stopwatch = Stopwatch()..start();

  try {
    // Download CSV file
    print('📡 Downloading frequencies data...');
    final response = await http.get(
      Uri.parse(frequenciesUrl),
      headers: {'Accept': 'text/csv'},
    ).timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to download frequencies: HTTP ${response.statusCode}');
    }

    final csvData = response.body;
    print('✅ Downloaded CSV data: ${(csvData.length / 1024 / 1024).toStringAsFixed(2)} MB');

    // Parse CSV
    print('\n📊 Parsing CSV data...');
    final frequencies = _parseCsv(csvData);
    print('✅ Parsed ${frequencies.length} frequencies');

    // Remove duplicates based on combination of airport_ident, type, and frequency
    print('\n🔍 Removing duplicates...');
    final uniqueFrequencies = <String, Map<String, dynamic>>{};
    final duplicateCount = <String, int>{};
    
    for (final freq in frequencies) {
      // Create unique key from airport, type, and frequency
      final airportIdent = freq['airport_ident']?.toString() ?? '';
      final freqType = freq['type']?.toString() ?? '';
      final freqMhz = freq['frequency_mhz']?.toString() ?? '';
      final description = freq['description']?.toString() ?? '';
      
      // Use combination of fields as unique key
      final uniqueKey = '$airportIdent|$freqType|$freqMhz|$description';
      
      if (uniqueFrequencies.containsKey(uniqueKey)) {
        duplicateCount[uniqueKey] = (duplicateCount[uniqueKey] ?? 1) + 1;
      } else {
        uniqueFrequencies[uniqueKey] = freq;
      }
    }
    
    final totalDuplicates = frequencies.length - uniqueFrequencies.length;
    final uniqueFreqList = uniqueFrequencies.values.toList();
    
    print('✅ Unique frequencies: ${uniqueFreqList.length}');
    print('🔄 Duplicates removed: $totalDuplicates');
    
    if (duplicateCount.isNotEmpty && totalDuplicates > 0) {
      final topDuplicates = duplicateCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      print('📊 Top duplicated frequencies:');
      for (var i = 0; i < 5 && i < topDuplicates.length; i++) {
        final entry = topDuplicates[i];
        final parts = entry.key.split('|');
        if (parts.length >= 3) {
          print('   - ${parts[0]} ${parts[1]} ${parts[2]}MHz: ${entry.value} duplicates');
        }
      }
    }

    // Group by airport for efficient lookup
    print('\n🗂️  Grouping frequencies by airport...');
    final frequenciesByAirport = <String, List<Map<String, dynamic>>>{};
    for (final freq in uniqueFreqList) {
      final airportIdent = freq['airport_ident'] ?? '';
      if (airportIdent.isNotEmpty) {
        frequenciesByAirport.putIfAbsent(airportIdent, () => []).add(freq);
      }
    }
    print('✅ Grouped into ${frequenciesByAirport.length} airports');

    // Create output directory
    final outputDir = Directory('assets/data');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    // Save as JSON
    final outputFile = File('assets/data/frequencies.json');
    final jsonData = {
      'version': 1,
      'source': 'OurAirports',
      'generated': DateTime.now().toUtc().toIso8601String(),
      'total_frequencies': uniqueFreqList.length,
      'total_airports': frequenciesByAirport.length,
      'frequencies': uniqueFreqList,
      'by_airport': frequenciesByAirport,
    };

    await outputFile.writeAsString(json.encode(jsonData));
    
    final fileSize = await outputFile.length();
    print('\n💾 Saved to: assets/data/frequencies.json');
    print('📦 File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

    stopwatch.stop();
    print('\n✅ Done! Downloaded ${uniqueFreqList.length} unique frequencies in ${stopwatch.elapsed.inSeconds}s');

    // Run compression script
    print('\n🗜️  Running compression script...');
    final compressResult = await Process.run('dart', ['scripts/prepare_compressed_data.dart']);
    if (compressResult.exitCode == 0) {
      print('✅ Compression complete!');
    } else {
      print('❌ Compression failed');
      print(compressResult.stderr);
    }

  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}

List<Map<String, dynamic>> _parseCsv(String csvData) {
  final lines = csvData.split('\n');
  if (lines.isEmpty) return [];

  // Parse header
  final headers = _parseCsvRow(lines[0]);
  final frequencies = <Map<String, dynamic>>[];

  // Parse data rows
  for (int i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    try {
      final values = _parseCsvRow(line);
      if (values.length >= headers.length) {
        final frequency = <String, dynamic>{};
        for (int j = 0; j < headers.length; j++) {
          final header = headers[j];
          final value = values[j];
          
          // Convert numeric fields
          if (header == 'id' || header == 'airport_ref') {
            frequency[header] = int.tryParse(value) ?? 0;
          } else if (header == 'frequency_mhz') {
            frequency[header] = double.tryParse(value) ?? 0.0;
          } else {
            frequency[header] = value;
          }
        }
        
        // Only include frequencies with valid data
        if (frequency['frequency_mhz'] != null && 
            frequency['frequency_mhz'] > 0 &&
            frequency['airport_ident'] != null &&
            frequency['airport_ident'].toString().isNotEmpty) {
          frequencies.add(frequency);
        }
      }
    } catch (e) {
      // Skip malformed rows
      continue;
    }
  }

  return frequencies;
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

  // Add the last field
  fields.add(buffer.toString());

  return fields;
}