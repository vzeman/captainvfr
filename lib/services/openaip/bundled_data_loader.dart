import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:archive/archive.dart';
import '../../models/airspace.dart';
import '../../models/reporting_point.dart';

/// Handles loading of bundled data from assets
class BundledDataLoader {
  final Logger _logger = Logger(level: Level.warning);
  
  bool _bundledDataLoaded = false;
  bool _bundledAirspacesLoaded = false;
  bool _bundledReportingPointsLoaded = false;

  bool get isBundledDataLoaded => _bundledDataLoaded;
  bool get isBundledAirspacesLoaded => _bundledAirspacesLoaded;
  bool get isBundledReportingPointsLoaded => _bundledReportingPointsLoaded;

  /// Load bundled data from assets
  Future<Map<String, dynamic>> loadBundledData() async {
    if (_bundledDataLoaded) {
      return {
        'airspaces': <Airspace>[],
        'reportingPoints': <ReportingPoint>[],
      };
    }

    try {
      // Try compressed data first, fallback to uncompressed
      try {
        return await _loadCompressedData();
      } catch (e) {
        _logger.w('Failed to load compressed data, trying uncompressed: $e');
        return await _loadUncompressedData();
      }
    } catch (e) {
      _logger.e('❌ Error loading bundled data: $e');
      _bundledDataLoaded = true; // Prevent repeated attempts
      return {
        'airspaces': <Airspace>[],
        'reportingPoints': <ReportingPoint>[],
      };
    }
  }

  /// Load compressed bundled data
  Future<Map<String, dynamic>> _loadCompressedData() async {
    // Note: Compressed JSON files have been replaced with tiled CSV format
    // Airspaces and other data are now loaded through TiledDataLoader on demand
    
    final results = <String, dynamic>{
      'airspaces': <Airspace>[],
      'reportingPoints': <ReportingPoint>[],
    };

    // Load compressed airspaces
    try {
      final compressedAirspaces = await rootBundle.load('assets/data/airspaces_bundled.json.gz');
      List<int> decompressed;
      
      try {
        // Try gzip decompression
        decompressed = GZipDecoder().decodeBytes(compressedAirspaces.buffer.asUint8List());
      } catch (e) {
        _logger.w('GZip decompression failed, trying zlib: $e');
        // Try zlib decompression as fallback
        decompressed = ZLibDecoder().decodeBytes(compressedAirspaces.buffer.asUint8List());
      }
      
      final jsonStr = utf8.decode(decompressed);
      final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
      
      if (jsonData['items'] != null) {
        final airspaces = (jsonData['items'] as List)
            .map((item) => Airspace.fromJson(item))
            .toList();
        results['airspaces'] = airspaces;
        _bundledAirspacesLoaded = true;
        _logger.d('✅ Loaded ${airspaces.length} bundled airspaces from compressed file');
      }
    } catch (e) {
      _logger.w('❌ Error loading compressed airspaces: $e');
    }

    // Load compressed reporting points
    try {
      final compressedPoints = await rootBundle.load('assets/data/reporting_points_bundled.json.gz');
      List<int> decompressed;
      
      try {
        // Try gzip decompression
        decompressed = GZipDecoder().decodeBytes(compressedPoints.buffer.asUint8List());
      } catch (e) {
        _logger.w('GZip decompression failed for reporting points, trying zlib: $e');
        // Try zlib decompression as fallback
        decompressed = ZLibDecoder().decodeBytes(compressedPoints.buffer.asUint8List());
      }
      
      final jsonStr = utf8.decode(decompressed);
      final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
      
      if (jsonData['items'] != null) {
        final reportingPoints = (jsonData['items'] as List)
            .map((item) => ReportingPoint.fromJson(item))
            .toList();
        results['reportingPoints'] = reportingPoints;
        _bundledReportingPointsLoaded = true;
        _logger.d('✅ Loaded ${reportingPoints.length} bundled reporting points from compressed file');
      }
    } catch (e) {
      _logger.w('❌ Error loading compressed reporting points: $e');
    }

    _bundledDataLoaded = true;
    return results;
  }

  /// Load uncompressed bundled data
  Future<Map<String, dynamic>> _loadUncompressedData() async {
    final results = <String, dynamic>{
      'airspaces': <Airspace>[],
      'reportingPoints': <ReportingPoint>[],
    };

    // Load airspaces
    try {
      final airspacesData = await rootBundle.loadString('assets/data/airspaces_bundled.json');
      final jsonData = json.decode(airspacesData) as Map<String, dynamic>;
      
      if (jsonData['items'] != null) {
        final airspaces = (jsonData['items'] as List)
            .map((item) => Airspace.fromJson(item))
            .toList();
        results['airspaces'] = airspaces;
        _bundledAirspacesLoaded = true;
        _logger.d('✅ Loaded ${airspaces.length} bundled airspaces from uncompressed file');
      }
    } catch (e) {
      _logger.w('❌ Error loading uncompressed airspaces: $e');
    }

    // Load reporting points
    try {
      final reportingPointsData = await rootBundle.loadString('assets/data/reporting_points_bundled.json');
      final jsonData = json.decode(reportingPointsData) as Map<String, dynamic>;
      
      if (jsonData['items'] != null) {
        final reportingPoints = (jsonData['items'] as List)
            .map((item) => ReportingPoint.fromJson(item))
            .toList();
        results['reportingPoints'] = reportingPoints;
        _bundledReportingPointsLoaded = true;
        _logger.d('✅ Loaded ${reportingPoints.length} bundled reporting points from uncompressed file');
      }
    } catch (e) {
      _logger.w('❌ Error loading uncompressed reporting points: $e');
    }

    _bundledDataLoaded = true;
    return results;
  }
}