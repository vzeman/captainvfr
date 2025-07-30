import 'package:flutter_test/flutter_test.dart';
import 'package:csv/csv.dart';

void main() {
  test('LZDV CSV parsing', () {
    // This is the actual LZDV line from the CSV
    final csvData = '''id,ident,type,name,lat,lon,elevation_ft,country,municipality,scheduled_service,gps_code,iata_code,local_code,home_link,wikipedia_link,runways,frequencies
626150685e9ded571044eaef,LZDV,2,DUBOVA,48.346944444444,17.356388888889,"{""value"":193,""unit"":0,""referenceDatum"":1}",SK,,0,,,,,,"[{""designator"":""13"",""trueHeading"":132,""alignedTrueNorth"":false,""operations"":0,""mainRunway"":true,""turnDirection"":2,""takeOffOnly"":false,""landingOnly"":false,""surface"":{""composition"":[2],""mainComposite"":2,""condition"":0,""mtow"":{""value"":5.7,""unit"":9}},""dimension"":{""length"":{""value"":580,""unit"":0},""width"":{""value"":30,""unit"":0}},""declaredDistance"":{""tora"":{""value"":575,""unit"":0},""lda"":{""value"":575,""unit"":0}},""pilotCtrlLighting"":false,""_id"":""626150685e9ded571044eaf1""},{""designator"":""31"",""trueHeading"":312,""alignedTrueNorth"":false,""operations"":0,""mainRunway"":true,""turnDirection"":2,""takeOffOnly"":false,""landingOnly"":false,""surface"":{""composition"":[2],""mainComposite"":2,""condition"":0,""mtow"":{""value"":5.7,""unit"":9}},""dimension"":{""length"":{""value"":580,""unit"":0},""width"":{""value"":30,""unit"":0}},""declaredDistance"":{""tora"":{""value"":580,""unit"":0},""lda"":{""value"":580,""unit"":0}},""pilotCtrlLighting"":false,""_id"":""626150685e9ded571044eaf2""}]","[{""value"":""123.930"",""unit"":2,""type"":10,""name"":""DUBOVA PREVADZKA"",""primary"":true,""publicUse"":true,""_id"":""626150685e9ded571044eaf0""}]"''';

    // Test default CSV parsing
    print('\n=== Testing CSV Parsing ===\n');
    
    final csvTable = const CsvToListConverter(
      eol: '\n',
      textDelimiter: '"',
      fieldDelimiter: ',',
      shouldParseNumbers: false,
    ).convert(csvData);
    
    print('Number of rows: ${csvTable.length}');
    print('Number of columns in data row: ${csvTable[1].length}');
    
    // Check LZDV row
    final lzdvRow = csvTable[1];
    print('\nLZDV Data:');
    print('  ICAO: ${lzdvRow[1]}');
    print('  Name: ${lzdvRow[3]}');
    print('  Row length: ${lzdvRow.length}');
    
    // Check runway data
    if (lzdvRow.length > 15) {
      final runwayData = lzdvRow[15].toString();
      print('  Runway data exists: ${runwayData.isNotEmpty}');
      print('  Runway data length: ${runwayData.length}');
      print('  First 100 chars: ${runwayData.substring(0, runwayData.length > 100 ? 100 : runwayData.length)}');
      
      // Try to parse as JSON
      try {
        // The data might have been escaped, so we need to unescape it
        var jsonStr = runwayData;
        if (jsonStr.startsWith('[') && jsonStr.endsWith(']')) {
          print('  ✓ Runway data looks like valid JSON array');
        } else {
          print('  ✗ Runway data doesn\'t look like JSON: starts with "${jsonStr.substring(0, 1)}", ends with "${jsonStr.substring(jsonStr.length - 1)}"');
        }
      } catch (e) {
        print('  Error checking JSON: $e');
      }
    } else {
      print('  ✗ Column 15 (runways) is missing! Only ${lzdvRow.length} columns found');
    }
  });
}