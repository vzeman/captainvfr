import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

/// Script to generate runway and frequency tiles from OpenAIP airport data
/// This fetches airports in bulk and extracts their runway/frequency data

class OpenAIPRunwayTileGenerator {
  static const int TILE_SIZE = 10; // degrees per tile
  late final String OPENAIP_API_KEY;
  static const String RUNWAY_OUTPUT_DIR = 'assets/data/tiles/openaip_runways';
  static const String FREQUENCY_OUTPUT_DIR = 'assets/data/tiles/openaip_frequencies';
  
  // OpenAIP API endpoint
  static const String OPENAIP_BASE_URL = 'https://api.core.openaip.net/api';
  
  // Tile configuration (10x10 degrees)
  static const int tilesX = 36; // 360 degrees / 10 degrees
  static const int tilesY = 18; // 180 degrees / 10 degrees
  static const double tileWidth = 10.0;
  static const double tileHeight = 10.0;
  
  // Data structures
  final Map<String, List<Map<String, dynamic>>> runwayTileData = {};
  final Map<String, List<Map<String, dynamic>>> frequencyTileData = {};
  int totalRunways = 0;
  int totalFrequencies = 0;
  int totalAirports = 0;
  
  // Rate limiting
  DateTime? lastApiCall;
  static const Duration minTimeBetweenCalls = Duration(milliseconds: 200);
  
  Future<void> generate(String apiKey) async {
    print('🚀 Starting OpenAIP runway/frequency tile generation...');
    
    OPENAIP_API_KEY = apiKey;
    
    if (OPENAIP_API_KEY.isEmpty) {
      print('❌ API key is required');
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
    
    // Download airports by tiles and extract runway/frequency data
    await downloadAirportsByTiles();
    
    // Write tiles
    await writeTiles();
    
    print('✅ Generated:');
    print('  - Processed $totalAirports airports');
    print('  - ${runwayTileData.length} runway tiles with $totalRunways runways');
    print('  - ${frequencyTileData.length} frequency tiles with $totalFrequencies frequencies');
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
  
  Future<void> downloadAirportsByTiles() async {
    print('\n📥 Downloading airports by geographic tiles...');
    
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
        
        // Progress indicator
        if (completedTiles % 10 == 0) {
          stdout.write('\r   📍 Progress: $completedTiles/$totalTiles tiles');
        }
        
        await fetchTileAirports(
          bbox: [minLon, minLat, maxLon, maxLat],
          tileX: x,
          tileY: y,
        );
      }
    }
    stdout.write('\r   ✅ Downloaded all tiles                    \n');
  }
  
  Future<void> fetchTileAirports({
    required List<double> bbox,
    required int tileX,
    required int tileY,
  }) async {
    int page = 1;
    bool hasMore = true;
    
    while (hasMore) {
      try {
        await enforceRateLimit();
        
        final queryParams = {
          'page': page.toString(),
          'limit': '100',
          'bbox': bbox.join(','),
        };
        
        final uri = Uri.parse('$OPENAIP_BASE_URL/airports')
            .replace(queryParameters: queryParams);
        
        final response = await http.get(
          uri,
          headers: {
            'x-openaip-api-key': OPENAIP_API_KEY,
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final List<dynamic> items = data['items'] ?? [];
          
          // Process each airport
          for (final airport in items) {
            processAirport(airport as Map<String, dynamic>);
          }
          
          // Check if there are more pages
          final totalPages = data['totalPages'] ?? 1;
          hasMore = page < totalPages;
          page++;
        } else if (response.statusCode == 429) {
          // Rate limit - wait and retry
          stdout.write('\r   ⏳ Rate limit hit, waiting...     ');
          await Future.delayed(const Duration(seconds: 60));
        } else {
          hasMore = false;
        }
      } catch (e) {
        // Continue on error
        hasMore = false;
      }
    }
  }
  
  void processAirport(Map<String, dynamic> airport) {
    totalAirports++;
    
    final icao = airport['icaoCode'] ?? '';
    final name = airport['name'] ?? '';
    
    // Get coordinates from geometry
    final geometry = airport['geometry'];
    if (geometry == null || geometry['coordinates'] == null) return;
    
    final coords = geometry['coordinates'] as List;
    if (coords.length < 2) return;
    
    final lon = coords[0] as num;
    final lat = coords[1] as num;
    
    // Process runways
    final runways = airport['runways'] as List? ?? [];
    if (runways.isNotEmpty) {
      for (final runway in runways) {
        final runwayData = parseRunway(runway, icao, name, lat.toDouble(), lon.toDouble());
        if (runwayData != null) {
          addRunwayToTile(runwayData, lat.toDouble(), lon.toDouble());
          totalRunways++;
        }
      }
    }
    
    // Process frequencies
    final frequencies = airport['frequencies'] as List? ?? [];
    if (frequencies.isNotEmpty) {
      for (final frequency in frequencies) {
        final frequencyData = parseFrequency(frequency, icao, name, lat.toDouble(), lon.toDouble());
        if (frequencyData != null) {
          addFrequencyToTile(frequencyData, lat.toDouble(), lon.toDouble());
          totalFrequencies++;
        }
      }
    }
  }
  
  Map<String, dynamic>? parseRunway(
    Map<String, dynamic> runway,
    String airportIcao,
    String airportName,
    double airportLat,
    double airportLon,
  ) {
    try {
      // Extract dimensions from nested structure
      double? length;
      double? width;
      
      final dimension = runway['dimension'] as Map<String, dynamic>?;
      if (dimension != null) {
        final lengthData = dimension['length'] as Map<String, dynamic>?;
        final widthData = dimension['width'] as Map<String, dynamic>?;
        
        if (lengthData != null && lengthData['value'] != null) {
          length = (lengthData['value'] as num).toDouble();
          // Convert to meters if needed (unit 0 seems to be meters already)
        }
        
        if (widthData != null && widthData['value'] != null) {
          width = (widthData['value'] as num).toDouble();
        }
      }
      
      // Extract surface information
      final surface = runway['surface'] as Map<String, dynamic>? ?? {};
      
      // OpenAIP runway structure from the API
      return {
        'airport_ident': airportIcao,
        'airport_name': airportName,
        'des': runway['designator'] ?? '', // Use 'des' to match expected format
        'len': length ?? 0, // Length in meters
        'wid': width ?? 0, // Width in meters
        'surf': surface, // Full surface information
        'trueHeading': runway['trueHeading'],
        'magneticHeading': runway['magneticHeading'],
        'operations': runway['operations'],
        'mainRunway': runway['mainRunway'] ?? false,
        'takeOffOnly': runway['takeOffOnly'] ?? false,
        'landingOnly': runway['landingOnly'] ?? false,
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
    String airportName,
    double airportLat,
    double airportLon,
  ) {
    try {
      // Parse frequency value
      dynamic value = frequency['value'];
      double frequencyMhz = 0.0;
      
      if (value is num) {
        frequencyMhz = value.toDouble();
      } else if (value is String) {
        frequencyMhz = double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
      }
      
      if (frequencyMhz == 0.0) return null;
      
      return {
        'airport_ident': airportIcao,
        'airport_name': airportName,
        'type': frequency['type'] ?? 'UNKNOWN',
        'name': frequency['name'] ?? '',
        'frequency_mhz': frequencyMhz,
        'unit': frequency['unit'] ?? '',
        'primary': frequency['primary'] ?? false,
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

void main(List<String> args) async {
  // Parse command line arguments
  String? apiKey;
  
  // Check for --api-key parameter
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--api-key' && i + 1 < args.length) {
      apiKey = args[i + 1];
      break;
    }
  }
  
  // If not provided via command line, try environment variable
  if (apiKey == null || apiKey.isEmpty) {
    apiKey = Platform.environment['OPENAIP_API_KEY'];
  }
  
  // Try to load from .env file if still not found
  if (apiKey == null || apiKey.isEmpty) {
    final envFile = File('.env');
    if (await envFile.exists()) {
      final content = await envFile.readAsString();
      final match = RegExp(r'OPENAIP_API_KEY=(.+)').firstMatch(content);
      if (match != null) {
        apiKey = match.group(1)?.trim();
      }
    }
  }
  
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ API key is required');
    print('Usage: dart generate_openaip_runway_tiles_v3.dart --api-key YOUR_API_KEY');
    print('Or set OPENAIP_API_KEY environment variable');
    print('Or add OPENAIP_API_KEY=your_key to .env file');
    exit(1);
  }
  
  final generator = OpenAIPRunwayTileGenerator();
  await generator.generate(apiKey);
}