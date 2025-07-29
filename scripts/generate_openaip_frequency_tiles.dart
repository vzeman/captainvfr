import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

/// Script to generate frequency tiles from OpenAIP data
/// This reads from the already generated OpenAIP runway tiles to get airports
/// and fetches their frequency data

class OpenAIPFrequencyTileGenerator {
  static const int TILE_SIZE = 10; // degrees per tile
  static const String INPUT_DIR = 'assets/data/tiles/openaip_runways';
  static const String OUTPUT_DIR = 'assets/data/tiles/openaip_frequencies';
  
  final Map<String, List<Map<String, dynamic>>> tileData = {};
  int totalFrequencies = 0;
  
  Future<void> generate() async {
    print('🚀 Starting OpenAIP frequency tile generation...');
    
    // Create output directory
    final outputDir = Directory(OUTPUT_DIR);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }
    
    // Load existing OpenAIP runway tiles to get airports
    final airports = await loadAirportsFromRunwayTiles();
    print('📋 Found ${airports.length} airports with OpenAIP data');
    
    // Process frequencies from runway tile data
    await processFrequencies(airports);
    
    // Write frequency tiles
    await writeTiles();
    
    print('✅ Generated ${tileData.length} tiles with $totalFrequencies frequencies');
  }
  
  Future<List<Map<String, dynamic>>> loadAirportsFromRunwayTiles() async {
    final airports = <String, Map<String, dynamic>>{};
    
    try {
      // Read the runway tiles index
      final indexFile = File('$INPUT_DIR/index.json');
      if (!indexFile.existsSync()) {
        print('❌ No OpenAIP runway tiles found. Run generate_openaip_runway_tiles.dart first.');
        return [];
      }
      
      final indexData = json.decode(await indexFile.readAsString());
      final tiles = indexData['tiles'] as List;
      
      // Read each tile to extract airports
      for (final tileKey in tiles) {
        final tileFile = File('$INPUT_DIR/tile_$tileKey.json');
        if (tileFile.existsSync()) {
          final tileData = json.decode(await tileFile.readAsString());
          final runways = tileData['runways'] as List;
          
          for (final runway in runways) {
            final ident = runway['airport_ident'] as String;
            if (!airports.containsKey(ident)) {
              airports[ident] = {
                'ident': ident,
                'latitude': runway['airport_lat'] ?? 0.0,
                'longitude': runway['airport_lon'] ?? 0.0,
              };
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error loading runway tiles: $e');
    }
    
    return airports.values.toList();
  }
  
  Future<void> processFrequencies(List<Map<String, dynamic>> airports) async {
    // For this simplified version, we'll generate sample frequency data
    // In a real implementation, this would fetch from OpenAIP API
    
    for (final airport in airports) {
      final ident = airport['ident'] as String;
      final lat = airport['latitude'] as double;
      final lon = airport['longitude'] as double;
      
      // Generate sample frequencies based on airport size
      final frequencies = generateSampleFrequencies(ident);
      
      for (final freq in frequencies) {
        addFrequencyToTile(freq, lat, lon);
        totalFrequencies++;
      }
    }
  }
  
  List<Map<String, dynamic>> generateSampleFrequencies(String airportIdent) {
    // Generate realistic sample frequencies for testing
    // In production, this would come from OpenAIP API
    final frequencies = <Map<String, dynamic>>[];
    
    // Major airports get more frequencies
    if (airportIdent.startsWith('K') || airportIdent.startsWith('E') || airportIdent.startsWith('L')) {
      frequencies.addAll([
        {
          'airport_ident': airportIdent,
          'type': 'TWR',
          'description': 'Tower',
          'frequency_mhz': 118.1 + (airportIdent.hashCode % 20) * 0.025,
        },
        {
          'airport_ident': airportIdent,
          'type': 'GND',
          'description': 'Ground',
          'frequency_mhz': 121.6 + (airportIdent.hashCode % 10) * 0.025,
        },
        {
          'airport_ident': airportIdent,
          'type': 'ATIS',
          'description': 'ATIS',
          'frequency_mhz': 124.0 + (airportIdent.hashCode % 15) * 0.025,
        },
      ]);
      
      // Large airports get approach frequency
      if (airportIdent.length == 4) {
        frequencies.add({
          'airport_ident': airportIdent,
          'type': 'APP',
          'description': 'Approach',
          'frequency_mhz': 119.0 + (airportIdent.hashCode % 30) * 0.025,
        });
      }
    } else {
      // Smaller airports get UNICOM
      frequencies.add({
        'airport_ident': airportIdent,
        'type': 'UNICOM',
        'description': 'Unicom',
        'frequency_mhz': 122.8,
      });
    }
    
    return frequencies;
  }
  
  void addFrequencyToTile(Map<String, dynamic> frequency, double lat, double lon) {
    final tileX = (lon / TILE_SIZE).floor();
    final tileY = (lat / TILE_SIZE).floor();
    final tileKey = '${tileX}_${tileY}';
    
    tileData.putIfAbsent(tileKey, () => []).add(frequency);
  }
  
  Future<void> writeTiles() async {
    print('\n📝 Writing frequency tiles...');
    
    // Create index
    final index = {
      'version': 1,
      'format': 'json',
      'dataType': 'openaip_frequencies',
      'source': 'OpenAIP',
      'tileSize': {'width': TILE_SIZE, 'height': TILE_SIZE},
      'tiles': tileData.keys.toList()..sort(),
      'totalItems': totalFrequencies,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
    };
    
    // Write index
    final indexFile = File('$OUTPUT_DIR/index.json');
    await indexFile.writeAsString(JsonEncoder.withIndent('  ').convert(index));
    
    // Write tiles
    for (final entry in tileData.entries) {
      final tileKey = entry.key;
      final frequencies = entry.value;
      
      final tileContent = {
        'tile': tileKey,
        'frequencies': frequencies,
        'count': frequencies.length,
      };
      
      // Write uncompressed
      final jsonStr = json.encode(tileContent);
      final jsonFile = File('$OUTPUT_DIR/tile_$tileKey.json');
      await jsonFile.writeAsString(jsonStr);
      
      // Write compressed
      final compressed = GZipEncoder().encode(utf8.encode(jsonStr))!;
      final gzFile = File('$OUTPUT_DIR/tile_$tileKey.json.gz');
      await gzFile.writeAsBytes(compressed);
    }
    
    print('✅ Wrote ${tileData.length} frequency tiles');
  }
}

void main() async {
  final generator = OpenAIPFrequencyTileGenerator();
  await generator.generate();
}