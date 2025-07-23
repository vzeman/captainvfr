import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:archive/archive.dart';
import 'package:logger/logger.dart';
import '../models/airport.dart';
import 'package:latlong2/latlong.dart';

/// Service for loading all airports in the background for search functionality
class BackgroundAirportLoader {
  static final BackgroundAirportLoader _instance = BackgroundAirportLoader._internal();
  factory BackgroundAirportLoader() => _instance;
  BackgroundAirportLoader._internal();

  final _logger = Logger(printer: PrettyPrinter());
  
  // All loaded airports
  final List<Airport> _airports = [];
  
  // Search indices
  final Map<String, List<int>> _nameIndex = {};
  final Map<String, List<int>> _icaoIndex = {};
  final Map<String, List<int>> _iataIndex = {};
  final Map<String, List<int>> _cityIndex = {};
  
  // Loading state
  bool _isLoading = false;
  bool _isLoaded = false;
  double _loadingProgress = 0.0;
  
  // Stream controller for loading progress
  final StreamController<double> _progressController = StreamController<double>.broadcast();
  
  // Getters
  List<Airport> get airports => List.unmodifiable(_airports);
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  double get loadingProgress => _loadingProgress;
  Stream<double> get onProgress => _progressController.stream;
  
  /// Start loading airports in the background
  Future<void> startLoading() async {
    if (_isLoading || _isLoaded) return;
    
    _isLoading = true;
    _loadingProgress = 0.0;
    _progressController.add(_loadingProgress);
    
    try {
      // Load the index file to get list of tiles
      final indexData = await rootBundle.loadString('assets/data/tiles/airports/index.json');
      final index = json.decode(indexData);
      final tiles = (index['tiles'] as List).cast<String>();
      
      _logger.i('Starting background loading of ${tiles.length} airport tiles');
      
      // Load tiles in batches to avoid blocking UI
      const batchSize = 5;
      for (int i = 0; i < tiles.length; i += batchSize) {
        final batch = tiles.skip(i).take(batchSize).toList();
        
        // Process batch
        await _loadTileBatch(batch);
        
        // Update progress
        _loadingProgress = (i + batch.length) / tiles.length;
        _progressController.add(_loadingProgress);
        
        // Yield to UI thread
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Build search indices
      _buildSearchIndices();
      
      _isLoaded = true;
      _loadingProgress = 1.0;
      _progressController.add(_loadingProgress);
      
      _logger.i('Loaded ${_airports.length} airports successfully');
    } catch (e) {
      _logger.e('Error loading airports: $e');
    } finally {
      _isLoading = false;
    }
  }
  
  /// Load a batch of tiles
  Future<void> _loadTileBatch(List<String> tileKeys) async {
    for (final tileKey in tileKeys) {
      try {
        final tilePath = 'assets/data/tiles/airports/tile_$tileKey.csv.gz';
        
        // Load compressed data
        final compressedData = await rootBundle.load(tilePath);
        final bytes = compressedData.buffer.asUint8List();
        
        // Decompress
        final decompressed = GZipDecoder().decodeBytes(bytes);
        final csvString = utf8.decode(decompressed);
        
        // Parse CSV
        final csvTable = const CsvToListConverter().convert(csvString);
        
        // Skip header row and parse airports
        if (csvTable.length > 1) {
          for (int i = 1; i < csvTable.length; i++) {
            final airport = _parseAirportRow(csvTable[i]);
            if (airport != null) {
              _airports.add(airport);
            }
          }
        }
      } catch (e) {
        _logger.w('Error loading tile $tileKey: $e');
      }
    }
  }
  
  /// Parse airport CSV row
  Airport? _parseAirportRow(List<dynamic> row) {
    try {
      // CSV headers: ['id', 'ident', 'type', 'name', 'lat', 'lon', 'elevation_ft', 
      //               'country', 'municipality', 'scheduled_service', 'gps_code', 
      //               'iata_code', 'local_code', 'home_link', 'wikipedia_link']
      final lat = double.parse(row[4].toString());
      final lon = double.parse(row[5].toString());
      
      return Airport(
        icao: row[1].toString(),
        iata: row[11].toString().isNotEmpty ? row[11].toString() : null,
        name: row[3].toString(),
        city: row[8].toString(),
        country: row[7].toString(),
        position: LatLng(lat, lon),
        elevation: row[6] != null ? int.tryParse(row[6].toString()) ?? 0 : 0,
        type: row[2].toString(),
        gpsCode: row[10].toString(),
        iataCode: row[11].toString().isNotEmpty ? row[11].toString() : null,
        localCode: row[12].toString(),
        municipality: row[8].toString(),
        countryCode: row[7].toString(),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Build search indices for fast lookup
  void _buildSearchIndices() {
    _nameIndex.clear();
    _icaoIndex.clear();
    _iataIndex.clear();
    _cityIndex.clear();
    
    for (int i = 0; i < _airports.length; i++) {
      final airport = _airports[i];
      
      // Index by name (tokenized)
      final nameTokens = _tokenize(airport.name);
      for (final token in nameTokens) {
        _nameIndex.putIfAbsent(token, () => []).add(i);
      }
      
      // Index by ICAO
      if (airport.icao.isNotEmpty) {
        _icaoIndex.putIfAbsent(airport.icao.toLowerCase(), () => []).add(i);
      }
      
      // Index by IATA
      if (airport.iata != null && airport.iata!.isNotEmpty) {
        _iataIndex.putIfAbsent(airport.iata!.toLowerCase(), () => []).add(i);
      }
      
      // Index by city (tokenized)
      if (airport.city.isNotEmpty) {
        final cityTokens = _tokenize(airport.city);
        for (final token in cityTokens) {
          _cityIndex.putIfAbsent(token, () => []).add(i);
        }
      }
    }
    
    _logger.i('Built search indices: ${_nameIndex.length} name tokens, '
             '${_icaoIndex.length} ICAO codes, ${_iataIndex.length} IATA codes, '
             '${_cityIndex.length} city tokens');
  }
  
  /// Tokenize a string for search indexing
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[\s\-_/]+'))
        .where((token) => token.length >= 2)
        .toList();
  }
  
  /// Search airports by query
  List<Airport> search(String query, {int limit = 50}) {
    if (!_isLoaded || query.isEmpty) return [];
    
    final normalizedQuery = query.toLowerCase().trim();
    final results = <int>{};
    
    // Search by ICAO (exact match)
    if (normalizedQuery.length >= 3 && normalizedQuery.length <= 4) {
      final icaoMatches = _icaoIndex[normalizedQuery];
      if (icaoMatches != null) {
        results.addAll(icaoMatches);
      }
    }
    
    // Search by IATA (exact match)
    if (normalizedQuery.length == 3) {
      final iataMatches = _iataIndex[normalizedQuery];
      if (iataMatches != null) {
        results.addAll(iataMatches);
      }
    }
    
    // Search by name and city (prefix match)
    final queryTokens = _tokenize(normalizedQuery);
    for (final token in queryTokens) {
      // Search name index
      _nameIndex.forEach((indexToken, indices) {
        if (indexToken.startsWith(token)) {
          results.addAll(indices);
        }
      });
      
      // Search city index
      _cityIndex.forEach((indexToken, indices) {
        if (indexToken.startsWith(token)) {
          results.addAll(indices);
        }
      });
    }
    
    // Convert indices to airports and sort by relevance
    final airportResults = results
        .map((index) => _airports[index])
        .toList();
    
    // Sort by relevance (exact matches first, then by type)
    airportResults.sort((a, b) {
      // Exact ICAO/IATA matches first
      final aExact = a.icao.toLowerCase() == normalizedQuery || 
                     (a.iata?.toLowerCase() ?? '') == normalizedQuery;
      final bExact = b.icao.toLowerCase() == normalizedQuery || 
                     (b.iata?.toLowerCase() ?? '') == normalizedQuery;
      
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      
      // Then by airport type (larger airports first)
      final typeOrder = {'large_airport': 0, 'medium_airport': 1, 'small_airport': 2};
      final aTypeOrder = typeOrder[a.type] ?? 3;
      final bTypeOrder = typeOrder[b.type] ?? 3;
      
      return aTypeOrder.compareTo(bTypeOrder);
    });
    
    return airportResults.take(limit).toList();
  }
  
  /// Get nearest airports to a location
  List<Airport> getNearestAirports(LatLng location, {int limit = 10}) {
    if (!_isLoaded) return [];
    
    // Calculate distances and sort
    final airportsWithDistance = _airports.map((airport) {
      final distance = const Distance().as(
        LengthUnit.Kilometer,
        location,
        airport.position,
      );
      return MapEntry(airport, distance);
    }).toList();
    
    airportsWithDistance.sort((a, b) => a.value.compareTo(b.value));
    
    return airportsWithDistance
        .take(limit)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Clear all loaded data
  void clear() {
    _airports.clear();
    _nameIndex.clear();
    _icaoIndex.clear();
    _iataIndex.clear();
    _cityIndex.clear();
    _isLoaded = false;
    _loadingProgress = 0.0;
    _progressController.add(_loadingProgress);
  }
  
  /// Dispose of resources
  void dispose() {
    _progressController.close();
  }
}