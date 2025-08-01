import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';
import 'cache_service.dart';
import 'tiled_data_loader.dart';

// Extension to add distance calculation to LatLng (Haversine formula)
extension LatLngExt on LatLng {
  // Returns distance in kilometers
  double distanceTo(LatLng other) {
    const double earthRadiusKm = 6371.0; // Earth's radius in kilometers

    double dLat = _toRadians(other.latitude - latitude);
    double dLon = _toRadians(other.longitude - longitude);

    double lat1 = _toRadians(latitude);
    double lat2 = _toRadians(other.latitude);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}

class AirportService {
  static const String _baseUrl =
      'https://davidmegginson.github.io/ourairports-data';
  // Max distance to load airports (km)
  static const double _maxDistanceKm = 100.0; // ignore: unused_field

  List<Airport> _airports = [];
  bool _isLoading = false;
  // ignore: prefer_final_fields
  bool _bundledDataLoaded = false;
  final CacheService _cacheService = CacheService();

  // Singleton pattern
  static final AirportService _instance = AirportService._internal();
  factory AirportService() => _instance;
  AirportService._internal();

  bool get isLoading => _isLoading;
  List<Airport> get airports => List.unmodifiable(_airports);

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    developer.log('🚀 AirportService.initialize() called');
    await _cacheService.initialize();
    
    // Try to load bundled data first
    await _loadBundledAirports();
    
    if (!_bundledDataLoaded) {
      developer.log('📦 No bundled data loaded, trying cache...');
      await _loadFromCache();
    }
    
    developer.log('✅ AirportService initialized with ${_airports.length} airports');
    
    // If still no airports, load from TiledDataLoader as a temporary fix
    if (_airports.isEmpty) {
      developer.log('⚠️ No airports loaded, loading from TiledDataLoader...');
      try {
        final tiledLoader = TiledDataLoader();
        
        // Load airports from a large area (temporary fix to get search working)
        // This covers most of Europe
        final tiledAirports = await tiledLoader.loadAirportsForArea(
          minLat: 35.0,  // Southern Europe
          maxLat: 60.0,  // Northern Europe
          minLon: -10.0, // Western Europe
          maxLon: 30.0,  // Eastern Europe
        );
        
        developer.log('📦 Loaded ${tiledAirports.length} airports from tiles');
        
        // Use the loaded airports directly - they already have runway data!
        _airports = tiledAirports;
        
        // Cache these airports
        await _cacheService.cacheAirports(_airports);
        
      } catch (e) {
        developer.log('❌ Error loading from TiledDataLoader: $e');
        // Fall back to network
        await fetchNearbyAirports();
      }
    }
  }

  /// Load airports from cache if available
  Future<void> _loadFromCache() async {
    try {
      final cachedAirports = await _cacheService.getCachedAirports();

      // Filter out closed airports from cached data as well
      _airports = cachedAirports
          .where((airport) => airport.type.toLowerCase() != 'closed')
          .toList();
    } catch (e) {
      developer.log('❌ Error loading airports from cache: $e');
      _airports = [];
    }
  }

  /// Force refresh data from network
  Future<void> refreshData() async {
    await _cacheService.clearAllCaches();
    _airports.clear();
    await fetchNearbyAirports(forceRefresh: true);
  }
  
  /// Load bundled airports data
  Future<void> _loadBundledAirports() async {
    try {
      developer.log('📦 Bundled airport data loading...');
      
      // Note: Bundled airport data is now loaded through TiledDataLoader when needed
      // The old JSON files have been replaced with tiled CSV format
      // OpenAIPService uses TiledDataLoader to load airports from tiles
      
      // This service currently relies on OurAirports API for initial data
      developer.log('ℹ️ AirportService uses OurAirports API. For bundled data, use OpenAIPService with TiledDataLoader.');
      
      /* Old compressed data loading code - no longer used
      // Try compressed data first
      try {
        final airportsBytes = await rootBundle.load('assets/data/airports_min.json.gz');
        final compressedData = airportsBytes.buffer.asUint8List();
        
        // Use platform-appropriate decompression
        List<int> decompressed;
        if (kIsWeb) {
          // Use archive package for web
          decompressed = GZipDecoder().decodeBytes(compressedData);
        } else {
          // Use dart:io gzip for native platforms
          decompressed = gzip.decode(compressedData);
        }
        
        final jsonString = utf8.decode(decompressed);
        final data = json.decode(jsonString);
        
        if (data['airports'] != null) {
          final List<dynamic> items = data['airports'];
          final airports = items.map((item) => _parseMinifiedAirport(item)).toList();
          
          if (airports.isNotEmpty) {
            // Filter out closed airports
            _airports = airports
                .where((airport) => airport.type?.toLowerCase() != 'closed')
                .toList();
            
            // Also cache them for offline use
            await _cacheService.cacheAirports(_airports);
            
            developer.log('✅ Loaded ${_airports.length} airports from bundled data');
            _bundledDataLoaded = true;
          }
        }
      } catch (e) {
        developer.log('⚠️ Could not load compressed airports, trying uncompressed: $e');
        
        // Fallback to uncompressed data
        final airportsJson = await rootBundle.loadString('assets/data/airports.json');
        final airportsData = json.decode(airportsJson);
        
        if (airportsData['airports'] != null) {
          final List<dynamic> airportsList = airportsData['airports'];
          final airports = airportsList.map((json) => Airport.fromJson(json)).toList();
          
          if (airports.isNotEmpty) {
            // Filter out closed airports
            _airports = airports
                .where((airport) => airport.type?.toLowerCase() != 'closed')
                .toList();
            
            // Also cache them for offline use
            await _cacheService.cacheAirports(_airports);
            
            developer.log('✅ Loaded ${_airports.length} airports from bundled data');
            developer.log('📅 Data generated at: ${airportsData['generated_at']}');
            _bundledDataLoaded = true;
          }
        }
      }
      */
    } catch (e) {
      developer.log('📡 No bundled airports data found, will use cache or fetch: $e');
    }
  }
  
  // NOTE: _parseMinifiedAirport method removed - no longer needed with tiled data

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
  Future<List<Airport>> getAirportsInBounds(
    LatLng southWest,
    LatLng northEast,
  ) async {
    if (_airports.isEmpty) {
      // If no airports loaded yet, try to fetch some
      await fetchNearbyAirports();
    }

    // Filter airports within the bounding box (closed airports already excluded at data loading level)
    return _airports.where((airport) {
      final lat = airport.position.latitude;
      final lng = airport.position.longitude;

      // Check if airport is within bounds
      return lat >= southWest.latitude &&
          lat <= northEast.latitude &&
          lng >= southWest.longitude &&
          lng <= northEast.longitude;
    }).toList();
  }

  // Fetch all airports from OurAirports
  Future<void> fetchNearbyAirports({
    LatLng? position,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) {
      return;
    }

    // If we already have airports and not forcing refresh, no need to fetch again
    if (_airports.isNotEmpty && !forceRefresh) {
      return;
    }

    _isLoading = true;

    try {
      // First try to fetch from network
      final url = '$_baseUrl/airports.csv';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        developer.log('📊 Successfully fetched airport data. Parsing...');
        // Parse CSV response
        final lines = const LineSplitter().convert(response.body);
        developer.log('📄 Parsed ${lines.length} lines from CSV');

        if (lines.length > 1) {
          // Skip header
          developer.log('🔍 Filtering valid airport entries...');
          final header = lines[0].split(',');
          developer.log('📋 CSV Header: $header');

          final filteredAirports = <String>[];
          int invalidCount = 0;
          int closedCount = 0;

          for (var i = 1; i < lines.length; i++) {
            final line = lines[i];
            if (line.trim().isEmpty) continue;

            final values = line.split(',');
            if (values.length >= 14 && values[1].isNotEmpty) {
              final lat = double.tryParse(values[4]) ?? 0.0;
              final lon = double.tryParse(values[5]) ?? 0.0;
              final type = values[2].replaceAll('"', '').trim().toLowerCase();

              // Skip closed airports entirely
              if (type == 'closed') {
                closedCount++;
                continue;
              }

              if (lat != 0.0 && lon != 0.0) {
                filteredAirports.add(line);
              } else {
                invalidCount++;
              }
            } else {
              invalidCount++;
            }
          }

          developer.log(
            '✅ Found ${filteredAirports.length} valid airport entries in CSV ($invalidCount invalid entries skipped, $closedCount closed airports excluded)',
          );

          developer.log('🏗  Creating Airport objects...');
          final parsedAirports = filteredAirports
              .map((line) {
                final values = line.split(',');
                try {
                  final lat = double.tryParse(values[4]) ?? 0.0;
                  final lon = double.tryParse(values[5]) ?? 0.0;
                  final elevation = double.tryParse(values[6])?.toInt() ?? 0;

                  final icao = values[1].replaceAll('"', '').trim();
                  final name = values[3].replaceAll('"', '').trim();
                  final municipality = values[10].replaceAll('"', '').trim();
                  final countryCode = values[8].replaceAll('"', '').trim();
                  final type = values[2].replaceAll('"', '').trim();
                  
                  // Use municipality if available, otherwise use airport name as city
                  final city = municipality.isNotEmpty ? municipality : name;
                  // Convert country code to country name
                  final country = _getCountryName(countryCode);

                  return Airport(
                    icao: icao,
                    iata: values.length > 13
                        ? values[13].replaceAll('"', '').trim()
                        : '',
                    name: name,
                    city: city,
                    country: country,
                    position: LatLng(lat, lon),
                    elevation: elevation,
                    type: type,
                    countryCode: countryCode,
                    municipality: municipality,
                  );
                } catch (e) {
                  developer.log('❌ Error parsing airport data: $e');
                  developer.log('Problematic line: $line');
                  return null;
                }
              })
              .whereType<Airport>()
              .toList();

          _airports = parsedAirports;

          // Cache the airports
          await _cacheService.cacheAirports(_airports);
        }
      } else {
        throw Exception('Failed to load airports: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error fetching nearby airports: $e');
      developer.log('Stack trace: $stackTrace');
      // Fall back to cached data if network fails
      if (!forceRefresh) {
        await _loadFromCache();
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Search airports by name or code
  List<Airport> searchAirports(String query) {
    if (query.isEmpty) return [];

    developer.log('🔍 Searching airports with query: "$query", total airports: ${_airports.length}');
    
    final searchQuery = query.toLowerCase().trim();

    final results = _airports.where((airport) {
      // Search by ICAO code
      if (airport.icao.toLowerCase().contains(searchQuery)) return true;

      // Search by IATA code if available
      if (airport.iata?.toLowerCase().contains(searchQuery) == true) {
        return true;
      }

      // Search by name
      if (airport.name.toLowerCase().contains(searchQuery)) {
        return true;
      }

      // Search by municipality if available
      if (airport.municipality?.toLowerCase().contains(searchQuery) == true) {
        return true;
      }

      return false;
    }).toList();
    
    return results;
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
        developer.log('❌ Error calculating distance: $e');
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
  
  /// Convert country code to country name
  String _getCountryName(String countryCode) {
    // Common country codes (expanded list)
    final countryNames = {
      // Europe
      'AD': 'Andorra',
      'AL': 'Albania',
      'AT': 'Austria',
      'BA': 'Bosnia and Herzegovina',
      'BE': 'Belgium',
      'BG': 'Bulgaria',
      'BY': 'Belarus',
      'CH': 'Switzerland',
      'CY': 'Cyprus',
      'CZ': 'Czech Republic',
      'DE': 'Germany',
      'DK': 'Denmark',
      'EE': 'Estonia',
      'ES': 'Spain',
      'FI': 'Finland',
      'FR': 'France',
      'GB': 'United Kingdom',
      'GR': 'Greece',
      'HR': 'Croatia',
      'HU': 'Hungary',
      'IE': 'Ireland',
      'IS': 'Iceland',
      'IT': 'Italy',
      'LI': 'Liechtenstein',
      'LT': 'Lithuania',
      'LU': 'Luxembourg',
      'LV': 'Latvia',
      'MC': 'Monaco',
      'MD': 'Moldova',
      'ME': 'Montenegro',
      'MK': 'North Macedonia',
      'MT': 'Malta',
      'NL': 'Netherlands',
      'NO': 'Norway',
      'PL': 'Poland',
      'PT': 'Portugal',
      'RO': 'Romania',
      'RS': 'Serbia',
      'RU': 'Russia',
      'SE': 'Sweden',
      'SI': 'Slovenia',
      'SK': 'Slovakia',
      'SM': 'San Marino',
      'TR': 'Turkey',
      'UA': 'Ukraine',
      'VA': 'Vatican City',
      'XK': 'Kosovo',
      // Americas
      'US': 'United States',
      'CA': 'Canada',
      'MX': 'Mexico',
      'BR': 'Brazil',
      'AR': 'Argentina',
      'CL': 'Chile',
      'CO': 'Colombia',
      'PE': 'Peru',
      'VE': 'Venezuela',
      // Asia
      'CN': 'China',
      'JP': 'Japan',
      'KR': 'South Korea',
      'IN': 'India',
      'TH': 'Thailand',
      'SG': 'Singapore',
      'MY': 'Malaysia',
      'ID': 'Indonesia',
      'PH': 'Philippines',
      'VN': 'Vietnam',
      // Oceania
      'AU': 'Australia',
      'NZ': 'New Zealand',
      'FJ': 'Fiji',
      // Africa
      'ZA': 'South Africa',
      'EG': 'Egypt',
      'MA': 'Morocco',
      'KE': 'Kenya',
      'NG': 'Nigeria',
      'ET': 'Ethiopia',
      // Middle East
      'AE': 'United Arab Emirates',
      'SA': 'Saudi Arabia',
      'IL': 'Israel',
      'JO': 'Jordan',
      'LB': 'Lebanon',
      'KW': 'Kuwait',
      'QA': 'Qatar',
      'OM': 'Oman',
      'BH': 'Bahrain',
    };
    
    return countryNames[countryCode] ?? countryCode;
  }
}
