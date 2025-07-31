import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:captainvfr/services/tiled_data_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  test('LZDV TiledDataLoader test', () async {
    print('\n=== Testing TiledDataLoader for LZDV ===\n');
    
    final loader = TiledDataLoader();
    
    // LZDV coordinates: 48.346944444444, 17.356388888889
    // Calculate tile for LZDV
    final lzdvLat = 48.346944444444;
    final lzdvLon = 17.356388888889;
    
    // The tiles are 10° wide and 10° tall (not 5°!)
    // X: floor((lon + 180) / 10) = floor(197.356/10) = 19 ✓
    // Y: floor((lat + 90) / 10) = floor(138.346/10) = 13 ✓
    
    print('LZDV is at: $lzdvLat, $lzdvLon');
    print('Calculated tile: X=${((lzdvLon + 180) / 10).floor()}, Y=${((lzdvLat + 90) / 10).floor()}');
    print('LZDV should be in tile_19_13');
    
    // Load airports for the area around LZDV
    final airports = await loader.loadAirportsForArea(
      minLat: 45.0,  // Much wider area
      maxLat: 50.0,  
      minLon: 15.0,  
      maxLon: 20.0,  
    );
    
    // Debug: List some airports
    print('\nFirst 10 airports:');
    for (var i = 0; i < airports.length && i < 10; i++) {
      print('  ${airports[i].icao} - ${airports[i].name}');
    }
    
    // Check if any airports contain "DV"
    final dvAirports = airports.where((a) => a.icao.contains('DV')).toList();
    print('\nAirports containing "DV": ${dvAirports.length}');
    for (var airport in dvAirports) {
      print('  ${airport.icao} - ${airport.name}');
    }
    
    // Find LZDV
    final lzdv = airports.firstWhere(
      (a) => a.icao == 'LZDV',
      orElse: () => throw Exception('LZDV not found in ${airports.length} airports'),
    );
    
    print('\nLZDV found:');
    print('  Name: ${lzdv.name}');
    print('  Position: ${lzdv.position.latitude}, ${lzdv.position.longitude}');
    print('  Runways field: ${lzdv.runways != null ? "${lzdv.runways!.length} chars" : "NULL"}');
    print('  Runways list: ${lzdv.runwaysList.length} runways');
    
    if (lzdv.runwaysList.isNotEmpty) {
      print('\nRunway details:');
      for (var runway in lzdv.runwaysList) {
        print('  - Runway: ${runway}');
      }
    }
    
    // Test OpenAIP runways
    final openAIPRunways = lzdv.openAIPRunways;
    print('\nOpenAIP runways: ${openAIPRunways.length}');
    for (var runway in openAIPRunways) {
      print('  - Designator: ${runway.designator}');
      print('    Length: ${runway.lengthM}m');
      print('    Width: ${runway.widthM}m');
      print('    Surface: ${runway.surface}');
    }
    
    expect(lzdv.runways, isNotNull, reason: 'LZDV should have runway data');
    expect(lzdv.runwaysList.length, greaterThan(0), reason: 'LZDV should have runways');
  });
}