import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Service for fetching and managing weather data for airports

class WeatherService {
  static const String _baseUrl = 'https://aviationweather.gov/cgi-bin/data';
  
  final _logger = Logger();
  final _client = http.Client();
  
  WeatherService();
  
  /// Fetches raw METAR string for the given ICAO code
  Future<String?> fetchMetar(String icaoCode) async {
    try {
      final url = '$_baseUrl/metar.php?ids=$icaoCode&format=json';
      _logger.d('🌤️ Fetching METAR from $url');
      
      final response = await _client.get(Uri.parse(url));
      _logger.d('📡 METAR response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Check if the response is a JSON error message
        if (response.body.trim().startsWith('error') || 
            response.body.trim().startsWith('<') ||
            response.body.trim().isEmpty) {
          _logger.w('⚠️ Received error or empty response from METAR API: ${response.body}');
          return null;
        }
        
        try {
          final data = jsonDecode(response.body);
          _logger.d('📊 Decoded METAR data type: ${data.runtimeType}');
          
          if (data is List) {
            _logger.d('📋 METAR data contains ${data.length} entries');
            if (data.isNotEmpty) {
              final metarString = data[0]['raw_text'] as String?;
              _logger.d('📝 Extracted METAR string: $metarString');
              if (metarString != null && metarString.isNotEmpty) {
                _logger.d('✅ Successfully parsed METAR: $metarString');
                return metarString;
              } else {
                _logger.w('⚠️ No raw_text field found in METAR data');
              }
            } else {
              _logger.w('⚠️ Empty METAR data array received');
            }
          } else {
            _logger.w('⚠️ Unexpected METAR data format: ${data.runtimeType}');
          }
        } catch (e) {
          _logger.e('❌ Error parsing METAR JSON: $e');
          _logger.d('Response body: ${response.body}');
          return null;
        }
      } else {
        _logger.e('❌ Failed to fetch METAR: ${response.statusCode}');
        _logger.d('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching METAR', error: e, stackTrace: stackTrace);
    }
    return null;
  }
  
  /// Fetches TAF data for the given ICAO code
  Future<String?> fetchTaf(String icaoCode) async {
    try {
      final url = '$_baseUrl/taf.php?ids=$icaoCode&format=json';
      _logger.d('🌤️ Fetching TAF from $url');
      
      final response = await _client.get(Uri.parse(url));
      _logger.d('📡 TAF response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Check if the response is a JSON error message
        if (response.body.trim().startsWith('error') || 
            response.body.trim().startsWith('<') ||
            response.body.trim().isEmpty) {
          _logger.w('⚠️ Received error or empty response from TAF API: ${response.body}');
          return null;
        }
        
        try {
          final data = jsonDecode(response.body);
          _logger.d('📊 Decoded TAF data type: ${data.runtimeType}');
          
          if (data is List) {
            _logger.d('📋 TAF data contains ${data.length} entries');
            if (data.isNotEmpty) {
              final tafString = data[0]['raw_text'] as String?;
              _logger.d('📝 Extracted TAF string: $tafString');
              if (tafString != null && tafString.isNotEmpty) {
                _logger.d('✅ Successfully parsed TAF: $tafString');
                return tafString;
              } else {
                _logger.w('⚠️ No raw_text field found in TAF data');
              }
            } else {
              _logger.w('⚠️ Empty TAF data array received');
            }
          } else {
            _logger.w('⚠️ Unexpected TAF data format: ${data.runtimeType}');
          }
        } catch (e) {
          _logger.e('❌ Error parsing TAF JSON: $e');
          _logger.d('Response body: ${response.body}');
          return null;
        }
      } else {
        _logger.e('❌ Failed to fetch TAF: ${response.statusCode}');
        _logger.d('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching TAF', error: e, stackTrace: stackTrace);
    }
    return null;
  }
  
  /// Gets the flight category color based on weather conditions
  static String getFlightCategoryColor(String? category) {
    if (category == null) return '#808080'; // Gray for unknown
    
    switch (category.toUpperCase()) {
      case 'VFR':
        return '#4CAF50'; // Green
      case 'MVFR':
        return '#2196F3'; // Blue
      case 'IFR':
        return '#F44336'; // Red
      case 'LIFR':
        return '#9C27B0'; // Purple
      default:
        return '#808080'; // Gray
    }
  }
  
  /// Disposes of resources
  void dispose() {
    _client.close();
  }
}
