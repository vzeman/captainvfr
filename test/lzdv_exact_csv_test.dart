import 'package:flutter_test/flutter_test.dart';
import 'package:csv/csv.dart';
import 'dart:io';

void main() {
  test('Parse LZDV exact CSV', () async {
    // Read the test CSV file
    final csvString = await File('/tmp/airports_header.csv').readAsString();
    
    print('CSV length: ${csvString.length}');
    
    // Try the same parser configuration as TiledDataLoader
    final csvTable = CsvToListConverter(
      eol: '\n',
      textDelimiter: '"',
      fieldDelimiter: ',',
      shouldParseNumbers: false,
      allowInvalid: false,
    ).convert(csvString);
    
    print('Parsed ${csvTable.length} rows');
    
    if (csvTable.length > 1) {
      final lzdvRow = csvTable[1];
      print('LZDV row has ${lzdvRow.length} columns');
      print('Ident (col 1): ${lzdvRow[1]}');
      print('Name (col 3): ${lzdvRow[3]}');
      
      if (lzdvRow.length > 15) {
        final runwaysJson = lzdvRow[15].toString();
        print('Runways JSON length: ${runwaysJson.length}');
        print('First 100 chars: ${runwaysJson.substring(0, 100)}');
      }
    }
  });
}