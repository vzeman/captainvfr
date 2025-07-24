import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

/// Script to generate runway tiles from OpenAIP data
/// This complements OurAirports runway data with additional runways from OpenAIP

class OpenAIPRunwayTileGenerator {
  static const int TILE_SIZE = 10; // degrees per tile
  static const String OPENAIP_API_KEY = String.fromEnvironment('OPENAIP_API_KEY');
  static const String OUTPUT_DIR = 'assets/data/tiles/openaip_runways';
  
  // OpenAIP API endpoint
  static const String OPENAIP_BASE_URL = 'https://api.core.openaip.net/api';
  
  // Structure to hold runway data
  final Map<String, List<Map<String, dynamic>>> tileData = {};
  int totalRunways = 0;
  final Set<String> processedAirports = {};
  
  Future<void> generate() async {
    print('🚀 Starting OpenAIP runway tile generation...');
    
    if (OPENAIP_API_KEY.isEmpty) {
      print('❌ OPENAIP_API_KEY environment variable not set');
      print('Set it with: export OPENAIP_API_KEY=your_api_key');
      exit(1);
    }
    
    // Create output directory
    final outputDir = Directory(OUTPUT_DIR);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }
    
    // Process airports by region
    await processAirportsInBounds();
    
    // Write tiles
    await writeTiles();
    
    print('✅ Generated ${tileData.length} tiles with $totalRunways runways');
  }
  
  Future<void> processAirportsInBounds() async {
    // Process the world in chunks to avoid overwhelming the API
    // Start with Europe as an example
    const regions = [
      {'name': 'Europe', 'minLat': 35.0, 'maxLat': 71.0, 'minLon': -25.0, 'maxLon': 45.0},
      {'name': 'North America', 'minLat': 15.0, 'maxLat': 72.0, 'minLon': -170.0, 'maxLon': -50.0},
      {'name': 'Asia', 'minLat': -10.0, 'maxLat': 75.0, 'minLon': 45.0, 'maxLon': 180.0},
      {'name': 'South America', 'minLat': -60.0, 'maxLat': 15.0, 'minLon': -90.0, 'maxLon': -30.0},
      {'name': 'Africa', 'minLat': -35.0, 'maxLat': 37.0, 'minLon': -20.0, 'maxLon': 55.0},
      {'name': 'Oceania', 'minLat': -50.0, 'maxLat': -10.0, 'minLon': 110.0, 'maxLon': 180.0},
    ];
    
    for (final region in regions) {
      print('\n📍 Processing ${region['name']}...');
      await fetchAirportsInRegion(
        region['minLat'] as double,
        region['maxLat'] as double,
        region['minLon'] as double,
        region['maxLon'] as double,
      );
      
      // Rate limiting
      await Future.delayed(Duration(seconds: 2));
    }
  }
  
  Future<void> fetchAirportsInRegion(
    double minLat,
    double maxLat,
    double minLon,
    double maxLon,
  ) async {
    try {
      // OpenAIP API endpoint for airports in bounds
      final url = Uri.parse('$OPENAIP_BASE_URL/airports')
          .replace(queryParameters: {
        'bbox': '$minLon,$minLat,$maxLon,$maxLat',
        'limit': '500',
      });
      
      final response = await http.get(
        url,
        headers: {
          'x-openaip-api-key': OPENAIP_API_KEY,
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];
        
        print('  Found ${items.length} airports in region');
        
        for (final airport in items) {
          await processAirport(airport);
          // Small delay to avoid rate limiting
          await Future.delayed(Duration(milliseconds: 100));
        }
      } else {
        print('  ⚠️ Failed to fetch airports: ${response.statusCode}');
      }
    } catch (e) {
      print('  ❌ Error fetching region: $e');
    }
  }
  
  Future<void> processAirport(Map<String, dynamic> airport) async {
    final airportId = airport['_id'] as String?;
    final icao = airport['icao'] as String? ?? '';
    
    if (airportId == null || processedAirports.contains(airportId)) {
      return;
    }
    
    processedAirports.add(airportId);
    
    try {
      // Fetch detailed airport data including runways
      final url = Uri.parse('$OPENAIP_BASE_URL/airports/$airportId');
      
      final response = await http.get(
        url,
        headers: {
          'x-openaip-api-key': OPENAIP_API_KEY,
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final detailData = json.decode(response.body);
        final runways = detailData['runways'] as List? ?? [];
        
        if (runways.isNotEmpty) {
          final geometry = detailData['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List?;
          
          if (coordinates != null && coordinates.length >= 2) {
            final lon = coordinates[0] as num;
            final lat = coordinates[1] as num;
            
            // Process each runway
            for (final runway in runways) {
              final runwayData = parseRunway(runway, icao, lat.toDouble(), lon.toDouble());
              if (runwayData != null) {
                addRunwayToTile(runwayData, lat.toDouble(), lon.toDouble());
                totalRunways++;
              }
            }
          }
        }
      }
    } catch (e) {
      print('    ⚠️ Error processing airport $icao: $e');
    }
  }
  
  Map<String, dynamic>? parseRunway(
    Map<String, dynamic> runway,
    String airportIcao,
    double airportLat,
    double airportLon,
  ) {
    try {
      // Extract runway operations (directions)
      final operations = runway['operations'] as List? ?? [];
      if (operations.isEmpty) return null;
      
      // Get the first operation for primary data
      final firstOp = operations[0] as Map<String, dynamic>;
      final designator = firstOp['des'] as String? ?? '';
      
      // Extract runway dimensions
      final lengthM = runway['dimension']?['length'] as int?;
      final widthM = runway['dimension']?['width'] as int?;
      
      // Extract surface information
      final surfaceData = runway['surface'] as Map<String, dynamic>?;
      
      // Get runway position if available
      double? leLat, leLon, heLat, heLon;
      
      // Try to get coordinates from operations
      for (final op in operations) {
        final position = op['position'] as Map<String, dynamic>?;
        if (position != null) {
          final coordinates = position['coordinates'] as List?;
          if (coordinates != null && coordinates.length >= 2) {
            final opDes = op['des'] as String? ?? '';
            final lon = coordinates[0] as num;
            final lat = coordinates[1] as num;
            
            // Determine if this is LE or HE based on designator number
            final desNum = int.tryParse(opDes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (desNum <= 18) {
              leLat = lat.toDouble();
              leLon = lon.toDouble();
            } else {
              heLat = lat.toDouble();
              heLon = lon.toDouble();
            }
          }
        }
      }
      
      // If no position data, use airport position as fallback
      leLat ??= airportLat;
      leLon ??= airportLon;
      
      return {
        'airport_ident': airportIcao,
        'designator': designator,
        'length_m': lengthM,
        'width_m': widthM,
        'surface': surfaceData,
        'le_latitude': leLat,
        'le_longitude': leLon,
        'he_latitude': heLat,
        'he_longitude': heLon,
        'operations': operations.map((op) => {
          'des': op['des'],
          'hdg': op['hdg'],  // Magnetic heading
        }).toList(),
      };
    } catch (e) {
      print('      ⚠️ Error parsing runway: $e');
      return null;
    }
  }
  
  void addRunwayToTile(Map<String, dynamic> runway, double lat, double lon) {
    final tileX = (lon / TILE_SIZE).floor();
    final tileY = (lat / TILE_SIZE).floor();
    final tileKey = '${tileX}_${tileY}';
    
    tileData.putIfAbsent(tileKey, () => []).add(runway);
  }
  
  Future<void> writeTiles() async {
    print('\n📝 Writing tiles...');
    
    // Create index
    final index = {
      'version': 1,
      'format': 'json',
      'dataType': 'openaip_runways',
      'source': 'OpenAIP',
      'tileSize': {'width': TILE_SIZE, 'height': TILE_SIZE},
      'tiles': tileData.keys.toList()..sort(),
      'totalItems': totalRunways,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
    };
    
    // Write index
    final indexFile = File('$OUTPUT_DIR/index.json');
    await indexFile.writeAsString(JsonEncoder.withIndent('  ').convert(index));
    
    // Write tiles
    for (final entry in tileData.entries) {
      final tileKey = entry.key;
      final runways = entry.value;
      
      final tileData = {
        'tile': tileKey,
        'runways': runways,
        'count': runways.length,
      };
      
      // Write uncompressed
      final jsonStr = json.encode(tileData);
      final jsonFile = File('$OUTPUT_DIR/tile_$tileKey.json');
      await jsonFile.writeAsString(jsonStr);
      
      // Write compressed
      final compressed = GZipEncoder().encode(utf8.encode(jsonStr))!;
      final gzFile = File('$OUTPUT_DIR/tile_$tileKey.json.gz');
      await gzFile.writeAsBytes(compressed);
    }
    
    print('✅ Wrote ${tileData.length} tiles');
  }
}

void main() async {
  final generator = OpenAIPRunwayTileGenerator();
  await generator.generate();
}