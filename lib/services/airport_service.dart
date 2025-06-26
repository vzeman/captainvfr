import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';

// Extension to add distance calculation to LatLng (Haversine formula)
extension LatLngExt on LatLng {
  // Returns distance in kilometers
  double distanceTo(LatLng other) {
    const double earthRadiusKm = 6371.0; // Earth's radius in kilometers
    
    double dLat = _toRadians(other.latitude - latitude);
    double dLon = _toRadians(other.longitude - longitude);
    
    double lat1 = _toRadians(latitude);
    double lat2 = _toRadians(other.latitude);
    
    double a = sin(dLat/2) * sin(dLat/2) +
              sin(dLon/2) * sin(dLon/2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    
    return earthRadiusKm * c;
  }
  
  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}



class AirportService {
  static const String _baseUrl = 'https://davidmegginson.github.io/ourairports-data';
  // Max distance to load airports (km)
  static const double _maxDistanceKm = 100.0; // ignore: unused_field
  
  List<Airport> _airports = [];
  bool _isLoading = false;
  
  // Singleton pattern
  static final AirportService _instance = AirportService._internal();
  factory AirportService() => _instance;
  AirportService._internal();
  
  bool get isLoading => _isLoading;
  List<Airport> get airports => List.unmodifiable(_airports);
  
  // Load airports from bundled asset (for offline use)
  Future<void> loadFromAsset() async {
    if (_isLoading) return;
    _isLoading = true;
    
    try {
      // For now, we'll initialize with an empty list
      // In a real app, you would load this from a bundled JSON file
      _airports = [];
      // If we have no airports, try fetching from network
      if (_airports.isEmpty) {
        await fetchNearbyAirports();
      }
    } catch (e) {
      developer.log('Error loading airports from asset', error: e);
      // If offline data fails, try fetching from network
      await fetchNearbyAirports();
    } finally {
      _isLoading = false;
    }
  }
  
  // Get current location (placeholder - will be implemented with location service)
  Future<LatLng?> getCurrentLocation() async {
    // This is a placeholder implementation
    // In a real app, this would use the device's location services
    return null;
  }
  
  /// Clean up resources used by the service
  void dispose() {
    // Clean up any resources if needed
  }
  
  /// Get airports within a bounding box
  Future<List<Airport>> getAirportsInBounds(LatLng southWest, LatLng northEast) async {
    print('getAirportsInBounds called with bounds: $southWest to $northEast');
    
    if (_airports.isEmpty) {
      print('No airports in cache, fetching nearby airports...');
      // If no airports loaded yet, try to fetch some
      await fetchNearbyAirports();
      print('Fetched ${_airports.length} airports');
    } else {
      print('Using ${_airports.length} cached airports');
    }
    
    // Filter airports within the bounding box
    return _airports.where((airport) {
      final lat = airport.position.latitude;
      final lng = airport.position.longitude;
      
      return lat >= southWest.latitude && 
             lat <= northEast.latitude &&
             lng >= southWest.longitude && 
             lng <= northEast.longitude;
    }).toList();
  }
  
  // Fetch all airports from OurAirports
  Future<void> fetchNearbyAirports({LatLng? position}) async {
    print('🚀 fetchNearbyAirports called with position: $position');
    if (_isLoading) {
      print('⏳ Already loading airports, skipping...');
      return;
    }
    
    // If we already have airports, no need to fetch again
    if (_airports.isNotEmpty) {
      print('✅ Using cached airports (${_airports.length} airports)');
      return;
    }
    
    _isLoading = true;
    print('🌐 Fetching all airports...');
    
    try {
      // First try to fetch from network
      final url = '$_baseUrl/airports.csv';
      print('🔗 Fetching airports from: $url');
      
      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse(url));
      print('📡 Airport data response status: ${response.statusCode} (took ${stopwatch.elapsedMilliseconds}ms)');
      
      if (response.statusCode == 200) {
        print('📊 Successfully fetched airport data. Parsing...');
        // Parse CSV response
        final lines = const LineSplitter().convert(response.body);
        print('📄 Parsed ${lines.length} lines from CSV');
        
        if (lines.length > 1) { // Skip header
          print('🔍 Filtering valid airport entries...');
          final header = lines[0].split(',');
          print('📋 CSV Header: $header');
          
          final filteredAirports = <String>[];
          int invalidCount = 0;
          
          for (var i = 1; i < lines.length; i++) {
            final line = lines[i];
            if (line.trim().isEmpty) continue;
            
            final values = line.split(',');
            if (values.length >= 14 && values[1].isNotEmpty) {
              final lat = double.tryParse(values[4]) ?? 0.0;
              final lon = double.tryParse(values[5]) ?? 0.0;
              
              if (lat != 0.0 && lon != 0.0) {
                filteredAirports.add(line);
              } else {
                invalidCount++;
              }
            } else {
              invalidCount++;
            }
          }
          
          print('✅ Found ${filteredAirports.length} valid airport entries in CSV (${invalidCount} invalid entries skipped)');
          
          print('🏗  Creating Airport objects...');
          _airports = filteredAirports.map((line) {
            final values = line.split(',');
            try {
              final lat = double.tryParse(values[4]) ?? 0.0;
              final lon = double.tryParse(values[5]) ?? 0.0;
              final elevation = double.tryParse(values[6])?.toInt() ?? 0;
              
              final icao = values[1].replaceAll('"', '').trim();
              final name = values[3].replaceAll('"', '').trim();
              final city = values[10].replaceAll('"', '').trim();
              final country = values[8].replaceAll('"', '').trim();
              final type = values[2].replaceAll('"', '').trim();
              
              return Airport(
                icao: icao,
                iata: values.length > 13 ? values[13].replaceAll('"', '').trim() : '',
                name: name,
                city: city,
                country: country,
                position: LatLng(lat, lon),
                elevation: elevation,
                type: type,
              );
            } catch (e) {
              print('❌ Error parsing airport data: $e');
              print('Problematic line: $line');
              return null;
            }
          }).whereType<Airport>().toList();
          
          print('✨ Successfully created ${_airports.length} Airport objects');
          
          if (_airports.isNotEmpty) {
            print('🏢 First airport: ${_airports.first.icao} - ${_airports.first.name} (${_airports.first.position})');
            print('🏢 Last airport: ${_airports.last.icao} - ${_airports.last.name} (${_airports.last.position})');
          }
        }
      } else {
        throw Exception('Failed to load airports: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error fetching nearby airports: $e');
      print('Stack trace: $stackTrace');
      // Fall back to local asset if available
      await loadFromAsset();
    } finally {
      _isLoading = false;
    }
  }
  
  /// Search airports by name or code
  List<Airport> searchAirports(String query) {
    if (query.isEmpty) return [];

    final searchQuery = query.toLowerCase().trim();

    return _airports.where((airport) {
      // Search by ICAO code
      if (airport.icao.toLowerCase().contains(searchQuery)) return true;

      // Search by IATA code if available
      if (airport.iata?.toLowerCase().contains(searchQuery) == true) return true;

      // Search by name
      if (airport.name.toLowerCase().contains(searchQuery)) return true;

      // Search by municipality if available
      if (airport.municipality?.toLowerCase().contains(searchQuery) == true) return true;

      return false;
    }).toList();
  }

  /// Find airport by exact ICAO code
  Airport? findAirportByIcao(String icaoCode) {
    try {
      return _airports.firstWhere(
        (airport) => airport.icao.toLowerCase() == icaoCode.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Find airports near a position
  List<Airport> findAirportsNearby(LatLng position, {double radiusKm = 50.0}) {
    if (_airports.isEmpty) return [];
    
    return _airports.where((airport) {
      try {
        final distance = position.distanceTo(airport.position);
        return distance <= radiusKm;
      } catch (e) {
        developer.log('Error calculating distance', error: e);
        return false;
      }
    }).toList();
  }
  
  /// Find nearest airport to a position
  Airport? findNearestAirport(LatLng position) {
    if (_airports.isEmpty) return null;
    
    Airport? nearest;
    double? minDistance;
    
    for (final airport in _airports) {
      try {
        final distance = position.distanceTo(airport.position);
        if (minDistance == null || distance < minDistance) {
          minDistance = distance;
          nearest = airport;
        }
      } catch (e) {
        // ignore: avoid_print
        print('Error calculating distance: $e');
        // Continue to next airport if distance calculation fails
        continue;
      }
    }
    
    return nearest;
  }
  
  // Clear all loaded airports
  void clear() {
    _airports.clear();
  }
}
