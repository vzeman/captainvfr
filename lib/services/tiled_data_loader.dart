import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:archive/archive.dart';
import 'package:logger/logger.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/navaid.dart';
import '../models/airport.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import '../models/obstacle.dart';
import '../models/hotspot.dart';
import '../models/runway.dart';
import '../models/frequency.dart';
import '../utils/spatial_index.dart';

/// Service for loading tiled CSV data based on geographic area
class TiledDataLoader {
  static final TiledDataLoader _instance = TiledDataLoader._internal();
  factory TiledDataLoader() => _instance;
  TiledDataLoader._internal();

  final _logger = Logger(printer: PrettyPrinter());
  
  // Tile configuration
  static const double tileWidth = 10.0; // degrees
  static const double tileHeight = 10.0; // degrees
  static const int tilesX = 36;
  static const int tilesY = 18;
  
  // Cache for loaded tiles
  final Map<String, Map<String, List<dynamic>>> _tileCache = {};
  
  // Track loaded tiles to avoid reloading
  final Set<String> _loadedTiles = {};
  
  // Spatial indexes for each data type
  final Map<String, HybridSpatialIndex> _spatialIndexes = {
    'airports': HybridSpatialIndex(),
    'airspaces': HybridSpatialIndex(),
    'navaids': HybridSpatialIndex(),
    'reporting_points': HybridSpatialIndex(),
    'obstacles': HybridSpatialIndex(),
    'hotspots': HybridSpatialIndex(),
  };
  
  /// Get tiles needed for a given area
  List<String> getTilesForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) {
    // Calculate tile indices
    final minTileX = ((minLon + 180) / tileWidth).floor().clamp(0, tilesX - 1);
    final maxTileX = ((maxLon + 180) / tileWidth).ceil().clamp(0, tilesX - 1);
    final minTileY = ((minLat + 90) / tileHeight).floor().clamp(0, tilesY - 1);
    final maxTileY = ((maxLat + 90) / tileHeight).ceil().clamp(0, tilesY - 1);
    
    final tiles = <String>[];
    for (int x = minTileX; x <= maxTileX; x++) {
      for (int y = minTileY; y <= maxTileY; y++) {
        tiles.add('${x}_$y');
      }
    }
    
    return tiles;
  }
  
  /// Load airports for a given area
  Future<List<Airport>> loadAirportsForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    return _loadDataForArea<Airport>(
      dataType: 'airports',
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      parser: _parseAirportRow,
    );
  }
  
  /// Load navaids for a given area
  Future<List<Navaid>> loadNavaidsForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    return _loadDataForArea<Navaid>(
      dataType: 'navaids',
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      parser: _parseNavaidRow,
    );
  }
  
  /// Load airspaces for a given area
  Future<List<Airspace>> loadAirspacesForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    return _loadDataForArea<Airspace>(
      dataType: 'airspaces',
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      parser: _parseAirspaceRow,
    );
  }
  
  /// Load reporting points for a given area
  Future<List<ReportingPoint>> loadReportingPointsForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    return _loadDataForArea<ReportingPoint>(
      dataType: 'reporting_points',
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      parser: _parseReportingPointRow,
    );
  }
  
  /// Load obstacles for a given area
  Future<List<Obstacle>> loadObstaclesForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    return _loadDataForArea<Obstacle>(
      dataType: 'obstacles',
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      parser: _parseObstacleRow,
    );
  }
  
  /// Load hotspots for a given area
  Future<List<Hotspot>> loadHotspotsForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    return _loadDataForArea<Hotspot>(
      dataType: 'hotspots',
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      parser: _parseHotspotRow,
    );
  }
  
  /// Load runways for a given area
  Future<List<Runway>> loadRunwaysForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    return _loadDataForArea<Runway>(
      dataType: 'runways',
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      parser: _parseRunwayRow,
    );
  }
  
  /// Load frequencies for a given area
  Future<List<Frequency>> loadFrequenciesForArea({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    return _loadDataForArea<Frequency>(
      dataType: 'frequencies',
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      parser: _parseFrequencyRow,
    );
  }
  
  /// Generic method to load data for an area
  Future<List<T>> _loadDataForArea<T>({
    required String dataType,
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required T? Function(List<dynamic>) parser,
  }) async {
    final tiles = getTilesForArea(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
    );
    
    final results = <T>[];
    
    for (final tileKey in tiles) {
      final cacheKey = '$dataType:$tileKey';
      final wasAlreadyLoaded = _loadedTiles.contains(cacheKey);
      
      final tileData = await _loadTile(dataType, tileKey);
      if (tileData != null) {
        for (final row in tileData) {
          final item = parser(row);
          if (item != null) {
            results.add(item);
            // Only add to spatial index if this tile wasn't already loaded
            // This prevents duplicates in the spatial index
            if (!wasAlreadyLoaded) {
              _addToSpatialIndex(dataType, item);
            }
          }
        }
      }
    }
    
    return results;
  }
  
  /// Add an item to the appropriate spatial index
  void _addToSpatialIndex(String dataType, dynamic item) {
    final index = _spatialIndexes[dataType];
    if (index != null && item is SpatialIndexable) {
      index.insert(item);
    }
  }
  
  /// Get spatial index for a data type
  HybridSpatialIndex? getSpatialIndex(String dataType) {
    return _spatialIndexes[dataType];
  }
  
  /// Query spatial index for items in bounds
  List<T> queryBounds<T extends SpatialIndexable>(String dataType, LatLngBounds bounds) {
    final index = _spatialIndexes[dataType];
    if (index == null) return [];
    
    final results = index.search(bounds);
    return results.cast<T>();
  }
  
  /// Query spatial index for items at a point
  List<T> queryPoint<T extends SpatialIndexable>(String dataType, LatLng point) {
    final index = _spatialIndexes[dataType];
    if (index == null) return [];
    
    final results = index.searchPoint(point);
    return results.cast<T>();
  }
  
  /// Load a single tile
  Future<List<List<dynamic>>?> _loadTile(String dataType, String tileKey) async {
    final cacheKey = '$dataType:$tileKey';
    
    // Check if already loaded - return cached data immediately
    if (_loadedTiles.contains(cacheKey)) {
      // Get cached data from the nested map structure
      final typeCache = _tileCache[dataType];
      if (typeCache != null && typeCache.containsKey(tileKey)) {
        final cachedData = typeCache[tileKey];
        return cachedData as List<List<dynamic>>?;
      }
    }
    
    try {
      final tilePath = 'assets/data/tiles/$dataType/tile_$tileKey.csv.gz';
      
      // Load compressed data
      final compressedData = await rootBundle.load(tilePath);
      final bytes = compressedData.buffer.asUint8List();
      
      // Decompress
      final decompressed = GZipDecoder().decodeBytes(bytes);
      final csvString = utf8.decode(decompressed);
      
      // Parse CSV
      final csvTable = const CsvToListConverter().convert(csvString);
      
      // Skip header row
      if (csvTable.length > 1) {
        final dataRows = csvTable.sublist(1);
        
        // Cache the data
        _tileCache.putIfAbsent(dataType, () => {})[tileKey] = dataRows;
        _loadedTiles.add(cacheKey);
        
        return dataRows;
      }
    } catch (e) {
      // Mark as loaded even if it doesn't exist to prevent repeated attempts
      _loadedTiles.add(cacheKey);
    }
    
    return null;
  }
  
  /// Parse airport CSV row
  Airport? _parseAirportRow(List<dynamic> row) {
    try {
      // CSV headers: ['id', 'ident', 'type', 'name', 'lat', 'lon', 'elevation_ft', 
      //               'country', 'municipality', 'scheduled_service', 'gps_code', 
      //               'iata_code', 'local_code', 'home_link', 'wikipedia_link']
      final lat = double.parse(row[4].toString());
      final lon = double.parse(row[5].toString());
      
      // Convert OpenAIP numeric type codes to expected string types
      final rawType = row[2].toString();
      final type = _convertOpenAIPTypeToString(rawType);
      
      // Parse elevation - it might be a JSON object or a simple number
      int elevation = 0;
      if (row[6] != null) {
        final elevStr = row[6].toString();
        if (elevStr.startsWith('{') && elevStr.contains('"value"')) {
          // Extract value from JSON-like format: {"value":380,"unit":0,"referenceDatum":1}
          final match = RegExp(r'"value":\s*(\d+)').firstMatch(elevStr);
          if (match != null) {
            elevation = int.tryParse(match.group(1)!) ?? 0;
          }
        } else {
          elevation = int.tryParse(elevStr) ?? 0;
        }
      }
      
      return Airport(
        icao: row[1].toString(), // ident field
        iata: row[11].toString().isNotEmpty ? row[11].toString() : null,
        name: row[3].toString(),
        city: row[8].toString(), // municipality
        country: row[7].toString(),
        position: LatLng(lat, lon),
        elevation: elevation,
        type: type,
        gpsCode: row[10].toString(),
        iataCode: row[11].toString().isNotEmpty ? row[11].toString() : null,
        localCode: row[12].toString(),
        municipality: row[8].toString(),
        countryCode: row[7].toString(),
      );
    } catch (e) {
      _logger.e('Error parsing airport row: $e');
      return null;
    }
  }
  
  /// Convert obstacle type code to string
  String _convertObstacleType(String typeCode) {
    switch (typeCode) {
      case '0':
        return 'obstacle'; // Generic obstacle
      case '1':
        return 'tower'; // Mast/Tower
      case '2':
        return 'building'; // Building
      case '3':
        return 'crane'; // Crane
      case '4':
        return 'wind_turbine'; // Wind turbine
      default:
        return 'obstacle'; // Default to generic obstacle
    }
  }
  
  /// Convert OpenAIP numeric type codes to string types
  String _convertOpenAIPTypeToString(String numericType) {
    // Based on analysis of the data:
    // 0 - Large/International airports (e.g., PARDUBICE, KBELY)
    // 1 - Grass strips/Ultra-light fields  
    // 2 - Regional/Medium airports (e.g., CHEB)
    // 3 - Major airports (e.g., BERLIN-BRANDENBURG)
    // 5 - Small airfields
    // 6 - Small strips/fields
    // 7 - Heliports (e.g., hospital heliports)
    // 8 - Glider sites
    // 9 - Regional airports with ultra-light capability (e.g., LKKU/KUNOVICE)
    // 10 - Hang gliding sites
    // 11 - Paragliding sites
    switch (numericType) {
      case '0':
      case '3':
        return 'large_airport';
      case '2':
      case '9':  // Include type 9 as medium airports (like LKKU)
        return 'medium_airport';
      case '1':
      case '5':
      case '6':
        return 'small_airport';
      case '7':
        return 'heliport';
      case '8':
      case '10':
      case '11':
        return 'closed'; // Treat specialized sport aviation sites as closed
      default:
        return 'small_airport'; // Default fallback
    }
  }
  
  /// Parse navaid CSV row
  Navaid? _parseNavaidRow(List<dynamic> row) {
    try {
      // CSV headers: ['id', 'ident', 'name', 'type', 'frequency_khz', 'lat', 'lon', 
      //               'elevation_ft', 'country', 'dme_frequency_khz', 'dme_channel', 
      //               'magnetic_variation_deg', 'usage_type']
      final lat = double.parse(row[5].toString());
      final lon = double.parse(row[6].toString());
      
      return Navaid(
        id: int.parse(row[0].toString()),
        filename: '', // Not in CSV, use empty string
        ident: row[1].toString(),
        name: row[2].toString(),
        type: row[3].toString(),
        frequencyKhz: double.parse(row[4].toString()),
        position: LatLng(lat, lon),
        elevationFt: int.tryParse(row[7].toString()) ?? 0,
        isoCountry: row[8].toString(),
        dmeFrequencyKhz: double.tryParse(row[9].toString()) ?? 0.0,
        dmeChannel: row[10].toString(),
        dmeLatitudeDeg: 0, // Not in CSV, use 0
        dmeLongitudeDeg: 0, // Not in CSV, use 0
        dmeElevationFt: 0, // Not in CSV, use 0
        slavedVariationDeg: 0.0, // Not in CSV, use 0
        magneticVariationDeg: double.tryParse(row[11].toString()) ?? 0.0,
        usageType: row[12].toString(),
        power: 0.0, // Not in CSV, use 0
        associatedAirport: '', // Not in CSV, use empty string
      );
    } catch (e) {
      _logger.e('Error parsing navaid row: $e');
      return null;
    }
  }
  
  /// Parse airspace CSV row
  Airspace? _parseAirspaceRow(List<dynamic> row) {
    try {
      // CSV headers: ['id', 'name', 'type', 'country', 'top_altitude_ft', 
      //               'bottom_altitude_ft', 'geometry_type', 'geometry']

      
      // Parse geometry from encoded string
      final geometryStr = row[7].toString();
      final points = <LatLng>[];
      
      if (geometryStr.isNotEmpty) {
        final pairs = geometryStr.split('|');
        for (final pair in pairs) {
          final parts = pair.split(',');
          if (parts.length >= 2) {
            points.add(LatLng(
              double.parse(parts[1]), // lat
              double.parse(parts[0]), // lon
            ));
          }
        }
      }
      
      // Parse altitude values from CSV - might be JSON format or simple numbers
      double? topAltitude;
      double? bottomAltitude;
      
      // Top altitude (upper limit)
      if (row[4] != null && row[4].toString().isNotEmpty && row[4].toString() != 'null') {
        final altStr = row[4].toString();
        if (altStr.startsWith('{') && altStr.contains('value')) {
          // Parse JSON format: {"value":10000,"unit":1,"referenceDatum":0}
          final valueMatch = RegExp(r'"value":\s*(\d+(?:\.\d+)?)').firstMatch(altStr);
          final unitMatch = RegExp(r'"unit":\s*(\d+)').firstMatch(altStr);
          
          if (valueMatch != null) {
            var value = double.parse(valueMatch.group(1)!);
            final unit = unitMatch != null ? int.tryParse(unitMatch.group(1)!) : 1;
            
            // Convert based on unit
            switch (unit) {
              case 6: // Flight levels (hundreds of feet)
                topAltitude = value * 100;
                break;
              case 2: // Meters
                topAltitude = value * 3.28084;
                break;
              default: // Already in feet
                topAltitude = value;
            }
          }
        } else {
          // Simple numeric value
          topAltitude = double.tryParse(altStr);
        }
      }
      
      // Bottom altitude (lower limit) 
      if (row[5] != null && row[5].toString().isNotEmpty && row[5].toString() != 'null') {
        final altStr = row[5].toString();
        if (altStr.startsWith('{') && altStr.contains('value')) {
          // Parse JSON format
          final valueMatch = RegExp(r'value:\s*(\d+(?:\.\d+)?)').firstMatch(altStr);
          final unitMatch = RegExp(r'unit:\s*(\d+)').firstMatch(altStr);
          
          if (valueMatch != null) {
            var value = double.parse(valueMatch.group(1)!);
            final unit = unitMatch != null ? int.tryParse(unitMatch.group(1)!) : 1;
            
            // Convert based on unit
            switch (unit) {
              case 6: // Flight levels (hundreds of feet)
                bottomAltitude = value * 100;
                break;
              case 2: // Meters
                bottomAltitude = value * 3.28084;
                break;
              default: // Already in feet
                bottomAltitude = value;
            }
          }
        } else {
          // Simple numeric value
          bottomAltitude = double.tryParse(altStr);
        }
      }
      
      // Get the airspace type (convert numeric if needed)
      var finalAirspaceType = row[2]?.toString() ?? '';
      if (finalAirspaceType.isNotEmpty && RegExp(r'^\d+$').hasMatch(finalAirspaceType)) {
        switch (finalAirspaceType) {
          case '0': finalAirspaceType = 'OTHER'; break;
          case '1': finalAirspaceType = 'RESTRICTED'; break;
          case '2': finalAirspaceType = 'DANGER'; break;
          case '3': finalAirspaceType = 'PROHIBITED'; break;
          case '4': finalAirspaceType = 'CTR'; break;
          case '5': finalAirspaceType = 'TMZ'; break;
          case '6': finalAirspaceType = 'RMZ'; break;
          case '7': finalAirspaceType = 'TMA'; break;
          case '8': finalAirspaceType = 'TRA'; break;
          case '9': finalAirspaceType = 'TSA'; break;
          case '10': finalAirspaceType = 'FIR'; break;
          case '11': finalAirspaceType = 'UIR'; break;
          case '12': finalAirspaceType = 'ADIZ'; break;
          case '13': finalAirspaceType = 'ATZ'; break;
          case '14': finalAirspaceType = 'MATZ'; break;
          case '15': finalAirspaceType = 'AIRWAY'; break;
          case '16': finalAirspaceType = 'MTR'; break;
          case '17': finalAirspaceType = 'ALERT'; break;
          case '18': finalAirspaceType = 'WARNING'; break;
          case '19': finalAirspaceType = 'PROTECTED'; break;
          case '20': finalAirspaceType = 'HTZ'; break;
          case '21': finalAirspaceType = 'GLIDING'; break;
          case '22': finalAirspaceType = 'TRP'; break;
          case '23': finalAirspaceType = 'TIZ'; break;
          case '24': finalAirspaceType = 'TIA'; break;
          case '25': finalAirspaceType = 'MTA'; break;
          case '26': finalAirspaceType = 'CTA'; break;
          case '27': finalAirspaceType = 'ACC'; break;
          case '28': finalAirspaceType = 'SPORT'; break;
          case '29': finalAirspaceType = 'LOW_ALTITUDE'; break;
          default: finalAirspaceType = 'OTHER'; break;
        }
      }
      
      return Airspace(
        id: row[0].toString(),
        name: row[1].toString(),
        type: finalAirspaceType,
        country: row[3].toString(),
        upperLimitFt: topAltitude,
        lowerLimitFt: bottomAltitude,
        geometry: points,
        // Default references to MSL for CSV data
        upperLimitReference: topAltitude != null ? 'MSL' : null,
        lowerLimitReference: bottomAltitude != null ? 'MSL' : null,
      );
    } catch (e) {
      _logger.e('Error parsing airspace row: $e');
      return null;
    }
  }
  
  /// Parse reporting point CSV row
  ReportingPoint? _parseReportingPointRow(List<dynamic> row) {
    try {
      // CSV headers: ['id', 'ident', 'name', 'type', 'lat', 'lon', 'country']
      return ReportingPoint(
        id: row[0].toString(),
        name: row[2].toString(), // Use name field
        type: row[3].toString(),
        latitude: double.parse(row[4].toString()),
        longitude: double.parse(row[5].toString()),
        country: row[6].toString(),
      );
    } catch (e) {
      _logger.e('Error parsing reporting point row: $e');
      return null;
    }
  }
  
  /// Parse obstacle CSV row
  Obstacle? _parseObstacleRow(List<dynamic> row) {
    try {
      // CSV headers: ['id', 'name', 'type', 'lat', 'lon', 'elevation_ft', 'height_ft', 
      //               'lighted', 'marking', 'country']
      
      // Parse elevation - it might be a JSON object or a simple number
      int? elevationFt;
      if (row[5] != null && row[5].toString().isNotEmpty) {
        final elevStr = row[5].toString();
        if (elevStr.startsWith('{')) {
          // Parse JSON format: {"value":259,"unit":0,"referenceDatum":1}
          final match = RegExp(r'"value":\s*(\d+)').firstMatch(elevStr);
          if (match != null) {
            elevationFt = int.parse(match.group(1)!);
          }
        } else {
          elevationFt = int.tryParse(elevStr);
        }
      }
      
      // Parse height - it might be a JSON object or a simple number
      int? heightFt;
      if (row[6] != null && row[6].toString().isNotEmpty) {
        final heightStr = row[6].toString();
        if (heightStr.startsWith('{')) {
          // Parse JSON format: {"value":104,"unit":0,"referenceDatum":0}
          final match = RegExp(r'"value":\s*(\d+)').firstMatch(heightStr);
          if (match != null) {
            heightFt = int.parse(match.group(1)!);
          }
        } else {
          heightFt = int.tryParse(heightStr);
        }
      }
      
      // Convert numeric obstacle type to string
      String obstacleType = _convertObstacleType(row[2].toString());
      
      return Obstacle(
        id: row[0].toString(),
        name: row[1].toString(),
        type: obstacleType,
        latitude: double.parse(row[3].toString()),
        longitude: double.parse(row[4].toString()),
        elevationFt: elevationFt,
        heightFt: heightFt,
        lighted: row[7] == 1 || row[7] == '1' || row[7] == true,
        marking: row[8]?.toString() ?? '',
        country: row[9].toString(),
      );
    } catch (e) {
      _logger.e('Error parsing obstacle row: $e');
      return null;
    }
  }
  
  /// Parse hotspot CSV row
  Hotspot? _parseHotspotRow(List<dynamic> row) {
    try {
      // CSV headers: ['id', 'name', 'type', 'lat', 'lon', 'elevation_ft', 
      //               'reliability', 'occurrence', 'conditions', 'country']
      
      // Parse elevation - it might be a JSON object or a simple number
      int? elevationFt;
      if (row[5] != null && row[5].toString().isNotEmpty) {
        final elevStr = row[5].toString();
        if (elevStr.startsWith('{')) {
          // Parse JSON format: {"value":143,"unit":0,"referenceDatum":1}
          final match = RegExp(r'"value":\s*(\d+)').firstMatch(elevStr);
          if (match != null) {
            elevationFt = int.parse(match.group(1)!);
          }
        } else {
          elevationFt = int.tryParse(elevStr);
        }
      }
      
      return Hotspot(
        id: row[0].toString(),
        name: row[1].toString(),
        type: row[2].toString(),
        latitude: double.parse(row[3].toString()),
        longitude: double.parse(row[4].toString()),
        elevationFt: elevationFt,
        reliability: row[6].toString(),
        occurrence: row[7].toString(),
        conditions: row[8]?.toString() ?? '',
        country: row[9].toString(),
      );
    } catch (e) {
      _logger.e('Error parsing hotspot row: $e');
      return null;
    }
  }
  
  /// Parse runway CSV row
  Runway? _parseRunwayRow(List<dynamic> row) {
    try {
      // CSV headers: ['airport_ident', 'length_ft', 'width_ft', 'surface', 'lighted', 'closed',
      //               'le_ident', 'le_latitude_deg', 'le_longitude_deg', 'le_elevation_ft', 'he_ident']
      // Note: Our simplified runway data only includes coordinates for the LE (low end) of the runway.
      // HE (high end) coordinates are not available in the data source.
      
      final leIdent = row[6].toString();
      final heIdent = row[10].toString();
      
      // Calculate headings from runway identifiers
      // Runway numbers are magnetic headings divided by 10 (e.g., runway 04 = 040 degrees)
      double? leHeading;
      double? heHeading;
      
      // Extract numeric part from identifier (handle L/R/C suffixes)
      final leMatch = RegExp(r'^(\d+)').firstMatch(leIdent);
      final heMatch = RegExp(r'^(\d+)').firstMatch(heIdent);
      
      if (leMatch != null) {
        final leNumber = int.tryParse(leMatch.group(1)!);
        if (leNumber != null) {
          leHeading = leNumber * 10.0;
        }
      }
      
      if (heMatch != null) {
        final heNumber = int.tryParse(heMatch.group(1)!);
        if (heNumber != null) {
          heHeading = heNumber * 10.0;
        }
      }
      
      // Generate a unique ID based on airport and runway designation
      final id = '${row[0]}_${leIdent}_$heIdent'.hashCode;
      
      return Runway(
        id: id,
        airportRef: '', // Not in our simplified format
        airportIdent: row[0].toString(),
        lengthFt: int.parse(row[1].toString()),
        widthFt: row[2] != null && row[2].toString().isNotEmpty ? int.tryParse(row[2].toString()) : null,
        surface: row[3].toString(),
        lighted: row[4].toString() == '1',
        closed: row[5].toString() == '1',
        leIdent: leIdent,
        leLatitude: row[7] != null && row[7].toString().isNotEmpty ? double.tryParse(row[7].toString()) : null,
        leLongitude: row[8] != null && row[8].toString().isNotEmpty ? double.tryParse(row[8].toString()) : null,
        leElevationFt: row[9] != null && row[9].toString().isNotEmpty ? int.tryParse(row[9].toString()) : null,
        leHeadingDegT: leHeading,
        leDisplacedThresholdFt: null, // Not available in our data
        heIdent: heIdent,
        heLatitude: null, // Not available in our simplified runway data
        heLongitude: null, // Not available in our simplified runway data
        heElevationFt: null, // Not available in our simplified runway data
        heHeadingDegT: heHeading,
        heDisplacedThresholdFt: null, // Not available in our data
      );
    } catch (e) {
      _logger.e('Error parsing runway row: $e');
      return null;
    }
  }
  
  /// Parse frequency CSV row
  Frequency? _parseFrequencyRow(List<dynamic> row) {
    try {
      // CSV headers: ['airport_ident', 'type', 'description', 'frequency_mhz']
      
      return Frequency(
        id: 0, // OurAirports data doesn't have IDs in our simplified format
        airportIdent: row[0].toString(),
        type: row[1].toString(),
        description: row[2] != null && row[2].toString().isNotEmpty ? row[2].toString() : null,
        frequencyMhz: double.parse(row[3].toString()),
      );
    } catch (e) {
      _logger.e('Error parsing frequency row: $e');
      return null;
    }
  }
  
  /// Clear cache for memory management
  void clearCache() {
    _tileCache.clear();
    _loadedTiles.clear();
    // Clear all spatial indexes
    for (final index in _spatialIndexes.values) {
      index.clear();
    }
    _logger.i('Cleared tile cache and spatial indexes');
  }
  
  /// Clear cache for specific data type
  void clearCacheForType(String dataType) {
    _tileCache.remove(dataType);
    _loadedTiles.removeWhere((key) => key.startsWith('$dataType:'));
    // Clear spatial index for this data type
    _spatialIndexes[dataType]?.clear();
    _logger.i('Cleared cache and spatial index for $dataType');
  }
}