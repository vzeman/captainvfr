import 'package:flutter_test/flutter_test.dart';
import 'package:csv/csv.dart';

void main() {
  test('Complex CSV parsing with escaped JSON', () {
    // Simplified version of the LZDV line
    final csvData = '''id,ident,type,name,runways
123,LZDV,2,DUBOVA,"[{""designator"":""13""}]"
456,TEST,3,TEST2,"normal field"''';

    print('CSV Data:');
    print(csvData);
    print('');
    
    // Try different CSV parser configurations
    final configs = [
      {'name': 'Default', 'converter': const CsvToListConverter()},
      {'name': 'With quotes', 'converter': const CsvToListConverter(textDelimiter: '"')},
      {'name': 'Complex', 'converter': const CsvToListConverter(
        eol: '\n',
        textDelimiter: '"',
        fieldDelimiter: ',',
        shouldParseNumbers: false,
      )},
    ];
    
    for (var config in configs) {
      print('\n=== ${config['name']} ===');
      try {
        final table = (config['converter'] as CsvToListConverter).convert(csvData);
        print('Rows: ${table.length}');
        for (var i = 0; i < table.length; i++) {
          print('Row $i: ${table[i].length} columns');
          if (table[i].length > 1) {
            print('  Ident: ${table[i][1]}');
          }
          if (table[i].length > 4) {
            print('  Runways: ${table[i][4]}');
          }
        }
      } catch (e) {
        print('Error: $e');
      }
    }
  });
}