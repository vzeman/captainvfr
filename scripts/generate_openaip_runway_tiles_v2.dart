import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

/// Enhanced script to generate runway and frequency tiles from OpenAIP data
/// This fetches data for airports we already know about (from OurAirports)
/// to supplement missing runway and frequency information

class OpenAIPDataTileGenerator {
  static const int TILE_SIZE = 10; // degrees per tile
  static const String OPENAIP_API_KEY = String.fromEnvironment('OPENAIP_API_KEY');
  static const String RUNWAY_OUTPUT_DIR = 'assets/data/tiles/openaip_runways';
  static const String FREQUENCY_OUTPUT_DIR = 'assets/data/tiles/openaip_frequencies';
  
  // OpenAIP API endpoint
  static const String OPENAIP_BASE_URL = 'https://api.openaip.net';
  
  // Data structures
  final Map<String, List<Map<String, dynamic>>> runwayTileData = {};
  final Map<String, List<Map<String, dynamic>>> frequencyTileData = {};
  int totalRunways = 0;
  int totalFrequencies = 0;
  final Set<String> processedAirports = {};
  
  // Rate limiting
  DateTime? lastApiCall;
  static const Duration minTimeBetweenCalls = Duration(milliseconds: 200);
  
  Future<void> generate() async {
    print('🚀 Starting OpenAIP data tile generation...');
    
    if (OPENAIP_API_KEY.isEmpty) {
      print('❌ OPENAIP_API_KEY environment variable not set');
      print('Set it with: export OPENAIP_API_KEY=your_api_key');
      exit(1);
    }
    
    // Create output directories
    final runwayDir = Directory(RUNWAY_OUTPUT_DIR);
    final frequencyDir = Directory(FREQUENCY_OUTPUT_DIR);
    if (!runwayDir.existsSync()) {
      runwayDir.createSync(recursive: true);
    }
    if (!frequencyDir.existsSync()) {
      frequencyDir.createSync(recursive: true);
    }
    
    // Load airport list from OurAirports data
    final airports = await loadAirportList();
    print('📋 Loaded ${airports.length} airports to process');
    
    // Process airports in batches
    await processAirports(airports);
    
    // Write tiles
    await writeTiles();
    
    print('✅ Generated:');
    print('  - ${runwayTileData.length} runway tiles with $totalRunways runways');
    print('  - ${frequencyTileData.length} frequency tiles with $totalFrequencies frequencies');
  }
  
  Future<List<Map<String, dynamic>>> loadAirportList() async {
    // Load airports from OurAirports CSV or existing tiles
    // For now, we'll use a sample list for testing
    // In production, this would read from the actual OurAirports data
    
    try {
      final file = File('assets/data/raw/airports.csv');
      if (file.existsSync()) {
        final lines = await file.readAsLines();
        final airports = <Map<String, dynamic>>[];
        
        // Skip header
        for (int i = 1; i < lines.length && i < 1000; i++) { // Limit for testing
          final parts = lines[i].split(',');
          if (parts.length > 13) {
            final ident = parts[1].replaceAll('"', '').trim();
            final lat = double.tryParse(parts[4]) ?? 0.0;
            final lon = double.tryParse(parts[5]) ?? 0.0;
            
            if (ident.isNotEmpty && lat != 0 && lon != 0) {
              airports.add({
                'ident': ident,
                'latitude': lat,
                'longitude': lon,
              });
            }
          }
        }
        
        return airports;
      }
    } catch (e) {
      print('⚠️ Could not load airport list: $e');
    }
    
    // Return a test set of major airports
    return [
      {'ident': 'KJFK', 'latitude': 40.6398, 'longitude': -73.7789},
      {'ident': 'EGLL', 'latitude': 51.4706, 'longitude': -0.4619},
      {'ident': 'LFPG', 'latitude': 49.0097, 'longitude': 2.5479},
      {'ident': 'EDDF', 'latitude': 50.0379, 'longitude': 8.5622},
      {'ident': 'LEMD', 'latitude': 40.4719, 'longitude': -3.5626},
      {'ident': 'LIRF', 'latitude': 41.8003, 'longitude': 12.2389},
      {'ident': 'EHAM', 'latitude': 52.3086, 'longitude': 4.7639},
      {'ident': 'LSZH', 'latitude': 47.4647, 'longitude': 8.5492},
      {'ident': 'LOWW', 'latitude': 48.1103, 'longitude': 16.5697},
      {'ident': 'EIDW', 'latitude': 53.4213, 'longitude': -6.2701},
    ];
  }
  
  Future<void> processAirports(List<Map<String, dynamic>> airports) async {
    int processed = 0;
    final total = airports.length;
    
    for (final airport in airports) {
      final ident = airport['ident'] as String;
      final lat = airport['latitude'] as double;
      final lon = airport['longitude'] as double;
      
      processed++;
      if (processed % 10 == 0) {
        print('  Progress: $processed/$total airports');
      }
      
      await processAirport(ident, lat, lon);
    }
  }
  
  Future<void> enforceRateLimit() async {
    if (lastApiCall != null) {
      final timeSinceLastCall = DateTime.now().difference(lastApiCall!);
      if (timeSinceLastCall < minTimeBetweenCalls) {
        await Future.delayed(minTimeBetweenCalls - timeSinceLastCall);
      }
    }
    lastApiCall = DateTime.now();
  }
  
  Future<void> processAirport(String icao, double lat, double lon) async {
    if (processedAirports.contains(icao)) {
      return;
    }
    
    processedAirports.add(icao);
    
    try {
      await enforceRateLimit();
      
      // Fetch airport details from OpenAIP
      final url = Uri.parse('$OPENAIP_BASE_URL/airports/$icao');
      
      final response = await http.get(
        url,
        headers: {
          'x-openaip-api-key': OPENAIP_API_KEY,
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Process runways
        final runways = data['runways'] as List? ?? [];
        if (runways.isNotEmpty) {
          for (final runway in runways) {
            final runwayData = parseRunway(runway, icao, lat, lon);
            if (runwayData != null) {
              addRunwayToTile(runwayData, lat, lon);
              totalRunways++;
            }
          }
        }
        
        // Process frequencies
        final frequencies = data['frequencies'] as List? ?? [];
        if (frequencies.isNotEmpty) {
          for (final frequency in frequencies) {
            final frequencyData = parseFrequency(frequency, icao, lat, lon);
            if (frequencyData != null) {
              addFrequencyToTile(frequencyData, lat, lon);
              totalFrequencies++;
            }
          }
        }
        
        if (runways.isNotEmpty || frequencies.isNotEmpty) {
          print('    ✓ $icao: ${runways.length} runways, ${frequencies.length} frequencies');
        }
      } else if (response.statusCode == 404) {
        // Airport not found in OpenAIP - this is okay
      } else {
        print('    ⚠️ $icao: API error ${response.statusCode}');
      }
    } catch (e) {
      print('    ❌ $icao: $e');
    }
  }
  
  Map<String, dynamic>? parseRunway(
    Map<String, dynamic> runway,
    String airportIcao,
    double airportLat,
    double airportLon,
  ) {
    try {
      // OpenAIP runway structure
      return {
        'airport_ident': airportIcao,
        'des': runway['des'] ?? '',
        'len': runway['len'], // Length in meters
        'wid': runway['wid'], // Width in meters
        'surf': runway['surf'], // Surface information
        'airport_lat': airportLat,
        'airport_lon': airportLon,
      };
    } catch (e) {
      return null;
    }
  }
  
  Map<String, dynamic>? parseFrequency(
    Map<String, dynamic> frequency,
    String airportIcao,
    double airportLat,
    double airportLon,
  ) {
    try {
      // Parse frequency value
      dynamic freq = frequency['frequency'];
      double frequencyMhz = 0.0;
      
      if (freq is num) {
        frequencyMhz = freq.toDouble();
      } else if (freq is String) {
        frequencyMhz = double.tryParse(freq.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
      }
      
      if (frequencyMhz == 0.0) return null;
      
      return {
        'airport_ident': airportIcao,
        'type': frequency['type'] ?? 'UNKNOWN',
        'description': frequency['name'] ?? frequency['description'],
        'frequency_mhz': frequencyMhz,
        'airport_lat': airportLat,
        'airport_lon': airportLon,
      };
    } catch (e) {
      return null;
    }
  }
  
  void addRunwayToTile(Map<String, dynamic> runway, double lat, double lon) {
    final tileX = (lon / TILE_SIZE).floor();
    final tileY = (lat / TILE_SIZE).floor();
    final tileKey = '${tileX}_${tileY}';
    
    runwayTileData.putIfAbsent(tileKey, () => []).add(runway);
  }
  
  void addFrequencyToTile(Map<String, dynamic> frequency, double lat, double lon) {
    final tileX = (lon / TILE_SIZE).floor();
    final tileY = (lat / TILE_SIZE).floor();
    final tileKey = '${tileX}_${tileY}';
    
    frequencyTileData.putIfAbsent(tileKey, () => []).add(frequency);
  }
  
  Future<void> writeTiles() async {
    print('\n📝 Writing tiles...');
    
    // Write runway tiles
    await writeTileSet(
      tileData: runwayTileData,
      outputDir: RUNWAY_OUTPUT_DIR,
      dataType: 'openaip_runways',
      itemsKey: 'runways',
      totalItems: totalRunways,
    );
    
    // Write frequency tiles
    await writeTileSet(
      tileData: frequencyTileData,
      outputDir: FREQUENCY_OUTPUT_DIR,
      dataType: 'openaip_frequencies',
      itemsKey: 'frequencies',
      totalItems: totalFrequencies,
    );
  }
  
  Future<void> writeTileSet({
    required Map<String, List<Map<String, dynamic>>> tileData,
    required String outputDir,
    required String dataType,
    required String itemsKey,
    required int totalItems,
  }) async {
    // Create index
    final index = {
      'version': 1,
      'format': 'json',
      'dataType': dataType,
      'source': 'OpenAIP',
      'tileSize': {'width': TILE_SIZE, 'height': TILE_SIZE},
      'tiles': tileData.keys.toList()..sort(),
      'totalItems': totalItems,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
    };
    
    // Write index
    final indexFile = File('$outputDir/index.json');
    await indexFile.writeAsString(JsonEncoder.withIndent('  ').convert(index));
    
    // Write tiles
    for (final entry in tileData.entries) {
      final tileKey = entry.key;
      final items = entry.value;
      
      final tileContent = {
        'tile': tileKey,
        itemsKey: items,
        'count': items.length,
      };
      
      // Write uncompressed
      final jsonStr = json.encode(tileContent);
      final jsonFile = File('$outputDir/tile_$tileKey.json');
      await jsonFile.writeAsString(jsonStr);
      
      // Write compressed
      final compressed = GZipEncoder().encode(utf8.encode(jsonStr))!;
      final gzFile = File('$outputDir/tile_$tileKey.json.gz');
      await gzFile.writeAsBytes(compressed);
    }
    
    print('  ✅ Wrote ${tileData.length} $dataType tiles');
  }
}

void main() async {
  final generator = OpenAIPDataTileGenerator();
  await generator.generate();
}