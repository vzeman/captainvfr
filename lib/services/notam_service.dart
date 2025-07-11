import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/notam.dart';
import 'cache_service.dart';

class NotamService {
  static final NotamService _instance = NotamService._internal();
  factory NotamService() => _instance;
  NotamService._internal();

  final CacheService _cacheService = CacheService();
  static const Duration _cacheExpiry = Duration(hours: 6);
  
  // FAA NOTAM API endpoints
  static const String _faaBaseUrl = 'https://www.aviationweather.gov/adds/dataserver_current/httpparam';
  
  // Check if cached NOTAMs are still valid
  bool _isCacheValid(List<Notam> notams) {
    if (notams.isEmpty) return false;
    
    final oldestFetch = notams
        .map((n) => n.fetchedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    
    return DateTime.now().difference(oldestFetch) < _cacheExpiry;
  }
  
  /// Get NOTAMs for an airport, using cache if available and valid
  /// Prefetch NOTAMs for multiple airports in parallel
  Future<void> prefetchNotamsForAirports(List<String> icaoCodes) async {
    if (icaoCodes.isEmpty) return;
    
    developer.log('📋 Prefetching NOTAMs for ${icaoCodes.length} airports');
    
    // Process in batches to avoid overwhelming the API
    const batchSize = 5;
    for (int i = 0; i < icaoCodes.length; i += batchSize) {
      final batch = icaoCodes.skip(i).take(batchSize).toList();
      
      // Fetch NOTAMs in parallel for this batch
      await Future.wait(
        batch.map((icao) => getNotamsForAirport(icao, forceRefresh: false)
          .catchError((e) {
            developer.log('⚠️ Failed to prefetch NOTAMs for $icao: $e');
            return <Notam>[];
          })
        ),
      );
      
      // Small delay between batches to be nice to the API
      if (i + batchSize < icaoCodes.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    developer.log('✅ Prefetch complete for ${icaoCodes.length} airports');
  }
  
  Future<List<Notam>> getNotamsForAirport(String icaoCode, {bool forceRefresh = false}) async {
    developer.log('📋 Fetching NOTAMs for $icaoCode (forceRefresh: $forceRefresh)');
    
    // Try cache first unless force refresh
    if (!forceRefresh) {
      try {
        final cachedNotams = await _getCachedNotams(icaoCode);
        if (cachedNotams.isNotEmpty && _isCacheValid(cachedNotams)) {
          developer.log('✅ Using cached NOTAMs for $icaoCode (${cachedNotams.length} items)');
          return cachedNotams;
        }
      } catch (e) {
        developer.log('⚠️ Error reading NOTAM cache: $e');
      }
    }
    
    // Fetch fresh data
    try {
      final notams = await _fetchNotamsFromAPI(icaoCode);
      
      // Cache the results
      if (notams.isNotEmpty) {
        await _cacheNotams(icaoCode, notams);
      }
      
      return notams;
    } catch (e) {
      developer.log('❌ Error fetching NOTAMs from API: $e');
      
      // Fall back to cache even if expired
      try {
        final cachedNotams = await _getCachedNotams(icaoCode);
        if (cachedNotams.isNotEmpty) {
          developer.log('⚠️ Using expired cache for $icaoCode due to API error');
          return cachedNotams;
        }
      } catch (cacheError) {
        developer.log('❌ Cache fallback also failed: $cacheError');
      }
      
      // Return empty list if all fails
      return [];
    }
  }
  
  /// Fetch NOTAMs from FAA API
  Future<List<Notam>> _fetchNotamsFromAPI(String icaoCode) async {
    // Try different parameter combinations as FAA API can be picky
    final uri = Uri.parse(_faaBaseUrl).replace(queryParameters: {
      'dataSource': 'notams',
      'requestType': 'retrieve',
      'format': 'xml',
      'stationString': icaoCode, // Changed from icaoLocation to stationString
      'hoursBeforeNow': '168', // Get NOTAMs from last 7 days instead of 24 hours
    });
    
    developer.log('🌐 Requesting NOTAMs from: ${uri.toString()}');
    
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    
    developer.log('📡 Response status: ${response.statusCode}');
    developer.log('📄 Response length: ${response.body.length} characters');
    
    if (response.statusCode == 200) {
      developer.log('🔍 First 500 chars of response: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      return _parseNotamsXml(response.body, icaoCode);
    } else {
      developer.log('❌ Response body: ${response.body}');
      throw Exception('Failed to fetch NOTAMs: ${response.statusCode}');
    }
  }
  
  /// Parse NOTAMs from XML response
  List<Notam> _parseNotamsXml(String xmlString, String icaoCode) {
    try {
      final document = xml.XmlDocument.parse(xmlString);
      final notams = <Notam>[];
      
      // Debug: Check root element
      developer.log('📄 XML Root element: ${document.rootElement.name}');
      
      // Try to find NOTAM elements - FAA might use different element names
      var notamElements = document.findAllElements('NOTAM');
      developer.log('🔍 Found ${notamElements.length} NOTAM elements');
      
      // If no NOTAM elements, try other possible element names
      if (notamElements.isEmpty) {
        notamElements = document.findAllElements('notam');
        developer.log('🔍 Found ${notamElements.length} notam elements (lowercase)');
      }
      
      if (notamElements.isEmpty) {
        // Try to find any element that might contain NOTAMs
        final allElements = document.findAllElements('*');
        developer.log('📄 All element names in XML:');
        final elementNames = <String>{};
        for (final elem in allElements) {
          elementNames.add(elem.name.local);
        }
        developer.log('📄 Unique elements: ${elementNames.toList()..sort()}');
      }
      
      // If still no NOTAMs, check if this is an error response
      if (notamElements.isEmpty) {
        final errorElements = document.findAllElements('error');
        if (errorElements.isNotEmpty) {
          final errorMsg = errorElements.first.innerText;
          developer.log('❌ API Error: $errorMsg');
          throw Exception('API Error: $errorMsg');
        }
        
        // Check for warnings
        final warningElements = document.findAllElements('warning');
        if (warningElements.isNotEmpty) {
          final warningMsg = warningElements.first.innerText;
          developer.log('⚠️ API Warning: $warningMsg');
        }
        
        // Try alternate structure - sometimes NOTAMs are under 'data' or 'response' elements
        final dataElements = document.findAllElements('data');
        if (dataElements.isNotEmpty) {
          notamElements = dataElements.first.findAllElements('NOTAM');
          developer.log('🔍 Found ${notamElements.length} NOTAM elements under data element');
        }
      }
      
      for (final notamElement in notamElements) {
        try {
          developer.log('📄 Processing NOTAM element');
          
          // Extract NOTAM data - try different possible field names
          final notamId = notamElement.findElements('notamID').firstOrNull?.innerText ??
                         notamElement.findElements('notam_id').firstOrNull?.innerText ??
                         notamElement.findElements('id').firstOrNull?.innerText ?? '';
          
          final facilityId = notamElement.findElements('facilityID').firstOrNull?.innerText ??
                            notamElement.findElements('facility_id').firstOrNull?.innerText ??
                            notamElement.findElements('icaoId').firstOrNull?.innerText ?? icaoCode;
          
          final startDate = notamElement.findElements('startDate').firstOrNull?.innerText ??
                           notamElement.findElements('start_date').firstOrNull?.innerText ??
                           notamElement.findElements('effectiveStart').firstOrNull?.innerText;
          
          final endDate = notamElement.findElements('endDate').firstOrNull?.innerText ??
                         notamElement.findElements('end_date').firstOrNull?.innerText ??
                         notamElement.findElements('effectiveEnd').firstOrNull?.innerText;
          
          final icaoMessage = notamElement.findElements('icaoMessage').firstOrNull?.innerText ??
                             notamElement.findElements('icao_message').firstOrNull?.innerText ??
                             notamElement.findElements('message').firstOrNull?.innerText ??
                             notamElement.findElements('text').firstOrNull?.innerText ?? '';
          
          final traditionalMessage = notamElement.findElements('traditionalMessage').firstOrNull?.innerText ??
                                    notamElement.findElements('traditional_message').firstOrNull?.innerText;
          
          final plainLanguageMessage = notamElement.findElements('plainLanguageMessage').firstOrNull?.innerText ??
                                      notamElement.findElements('plain_language_message').firstOrNull?.innerText ??
                                      notamElement.findElements('translation').firstOrNull?.innerText;
          
          final classification = notamElement.findElements('classification').firstOrNull?.innerText ??
                                notamElement.findElements('notamType').firstOrNull?.innerText;
          
          developer.log('📝 Found NOTAM: $notamId for $facilityId');
          
          // Parse dates
          DateTime? effectiveFrom;
          DateTime? effectiveUntil;
          
          if (startDate != null) {
            effectiveFrom = DateTime.tryParse(startDate)?.toUtc();
          }
          if (endDate != null) {
            effectiveUntil = DateTime.tryParse(endDate)?.toUtc();
          }
          
          // Skip if we couldn't parse the start date
          if (effectiveFrom == null) continue;
          
          // Create unique ID
          final id = '${notamId}_${effectiveFrom.millisecondsSinceEpoch}';
          
          // Parse NOTAM ID components (e.g., "A1234/23")
          String? series;
          String? number;
          String? year;
          String? type;
          
          final notamIdMatch = RegExp(r'([A-Z])(\d+)/(\d+)').firstMatch(notamId);
          if (notamIdMatch != null) {
            series = notamIdMatch.group(1);
            number = notamIdMatch.group(2);
            year = notamIdMatch.group(3);
          }
          
          // Determine type from classification or message
          if (classification?.toUpperCase().contains('NEW') == true) {
            type = 'N';
          } else if (classification?.toUpperCase().contains('REPLACE') == true) {
            type = 'R';
          } else if (classification?.toUpperCase().contains('CANCEL') == true) {
            type = 'C';
          }
          
          // Extract schedule information
          String schedule = '';
          if (icaoMessage.contains('D)')) {
            final scheduleMatch = RegExp(r'D\)\s*([^E\)]+)').firstMatch(icaoMessage);
            if (scheduleMatch != null) {
              schedule = scheduleMatch.group(1)?.trim() ?? '';
            }
          }
          
          // Extract purpose, scope, and traffic from ICAO message
          String? purpose;
          String? scope;
          String? traffic;
          
          if (icaoMessage.contains('A)')) {
            final qLineMatch = RegExp(r'Q\)\s*([^/]+)/([^/]+)/([^/]+)/([^/]+)/([^/]+)').firstMatch(icaoMessage);
            if (qLineMatch != null) {
              // Q) FIR/QMXLC/IV/NBO/A/000/999/...
              scope = qLineMatch.group(2); // QMXLC -> scope codes
              traffic = qLineMatch.group(3); // IV
              purpose = qLineMatch.group(4); // NBO
            }
          }
          
          // Use plain language message if available, otherwise traditional or ICAO
          final displayText = plainLanguageMessage ?? traditionalMessage ?? icaoMessage;
          
          // Categorize the NOTAM
          final category = NotamCategory.categorizeFromText(displayText);
          
          final notam = Notam(
            id: id,
            notamId: notamId,
            icaoCode: facilityId,
            series: series,
            number: number,
            year: year,
            type: type,
            effectiveFrom: effectiveFrom,
            effectiveUntil: effectiveUntil,
            schedule: schedule,
            text: icaoMessage,
            decodedText: plainLanguageMessage ?? traditionalMessage,
            purpose: purpose,
            scope: scope,
            traffic: traffic,
            fetchedAt: DateTime.now().toUtc(),
            category: category,
          );
          
          notams.add(notam);
        } catch (e) {
          developer.log('⚠️ Error parsing individual NOTAM: $e');
          // Continue with next NOTAM
        }
      }
      
      // Sort NOTAMs by importance and then by effective date
      notams.sort((a, b) {
        final importanceCompare = b.importance.index.compareTo(a.importance.index);
        if (importanceCompare != 0) return importanceCompare;
        return b.effectiveFrom.compareTo(a.effectiveFrom);
      });
      
      return notams;
    } catch (e) {
      developer.log('❌ Error parsing NOTAMs XML: $e');
      return [];
    }
  }
  
  /// Get cached NOTAMs for an airport
  Future<List<Notam>> _getCachedNotams(String icaoCode) async {
    final cacheKey = 'notams_$icaoCode';
    final cachedData = await _cacheService.getCachedData(cacheKey);
    
    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = json.decode(cachedData);
        return jsonList.map((json) {
          // Ensure the JSON data is properly typed
          final Map<String, dynamic> notamJson = Map<String, dynamic>.from(json);
          
          // Clean up any corrupted NOTAM IDs
          if (notamJson['notamId'] != null) {
            String notamId = notamJson['notamId'].toString();
            // Remove any URL encoding artifacts
            notamId = notamId.replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '');
            // Remove any null bytes or control characters
            notamId = notamId.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
            notamJson['notamId'] = notamId.trim();
          }
          
          return Notam.fromJson(notamJson);
        }).toList();
      } catch (e) {
        developer.log('❌ Error parsing cached NOTAMs: $e');
        // Clear corrupted cache
        await _cacheService.clearCachedData(cacheKey);
        return [];
      }
    }
    
    return [];
  }
  
  /// Cache NOTAMs for an airport
  Future<void> _cacheNotams(String icaoCode, List<Notam> notams) async {
    final cacheKey = 'notams_$icaoCode';
    
    // Clean up NOTAM data before caching to prevent corruption
    final cleanedNotams = notams.map((notam) {
      final json = notam.toJson();
      
      // Ensure NOTAM ID is clean
      if (json['notamId'] != null) {
        String notamId = json['notamId'].toString();
        // Remove any URL encoding artifacts
        notamId = notamId.replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '');
        // Remove any null bytes or control characters
        notamId = notamId.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
        json['notamId'] = notamId.trim();
      }
      
      return json;
    }).toList();
    
    final jsonData = json.encode(cleanedNotams);
    await _cacheService.cacheData(cacheKey, jsonData);
  }
  
  /// Clear cached NOTAMs for an airport
  Future<void> clearCachedNotams(String icaoCode) async {
    final cacheKey = 'notams_$icaoCode';
    await _cacheService.clearCachedData(cacheKey);
  }
  
  /// Clear all cached NOTAMs
  Future<void> clearAllCachedNotams() async {
    // This would need to be implemented in CacheService to clear by prefix
    developer.log('🧹 Clearing all cached NOTAMs');
  }
}