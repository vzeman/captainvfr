import 'dart:convert' show json, latin1;
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/notam.dart';
import 'cache_service.dart';
import 'cors_proxy_service.dart';

/// Alternative NOTAM service implementation using ICAO format parsing
class NotamServiceV2 {
  static final NotamServiceV2 _instance = NotamServiceV2._internal();
  factory NotamServiceV2() => _instance;
  NotamServiceV2._internal();

  final CacheService _cacheService = CacheService();
  static const Duration _cacheExpiry = Duration(hours: 6);

  /// Get NOTAMs using direct parsing of ICAO format
  /// Prefetch NOTAMs for multiple airports in parallel
  Future<void> prefetchNotamsForAirports(List<String> icaoCodes) async {
    if (icaoCodes.isEmpty) return;

    developer.log('📋 V2: Prefetching NOTAMs for ${icaoCodes.length} airports');

    // Process in batches to avoid overwhelming the API
    const batchSize = 5;
    for (int i = 0; i < icaoCodes.length; i += batchSize) {
      final batch = icaoCodes.skip(i).take(batchSize).toList();

      // Fetch NOTAMs in parallel for this batch
      await Future.wait(
        batch.map(
          (icao) =>
              getNotamsForAirport(icao, forceRefresh: false).catchError((e) {
                developer.log('⚠️ V2: Failed to prefetch NOTAMs for $icao: $e');
                return <Notam>[];
              }),
        ),
      );

      // Small delay between batches to be nice to the API
      if (i + batchSize < icaoCodes.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    developer.log('✅ V2: Prefetch complete for ${icaoCodes.length} airports');
  }

  Future<List<Notam>> getNotamsForAirport(
    String icaoCode, {
    bool forceRefresh = false,
  }) async {
    developer.log('📋 Fetching NOTAMs for $icaoCode using V2 service');

    // For now, let's create a test NOTAM to verify the UI works
    if (icaoCode == 'TEST') {
      return _createTestNotams();
    }

    // Try cache first
    if (!forceRefresh) {
      try {
        final cachedNotams = await _getCachedNotams(icaoCode);
        if (cachedNotams.isNotEmpty && _isCacheValid(cachedNotams)) {
          developer.log('✅ Using cached NOTAMs for $icaoCode');
          return cachedNotams;
        }
      } catch (e) {
        developer.log('⚠️ Cache error: $e');
      }
    }

    // Try to fetch from API
    try {
      // First, let's try a simple HTTP request to see what we get
      final baseUrl =
          'https://www.notams.faa.gov/dinsQueryWeb/queryRetrievalMapAction.do'
          '?reportType=Raw&retrieveLocId=$icaoCode&actionType=notamRetrievalByICAOs';
      
      // Use CORS proxy for web platform
      final testUrl = CorsProxyService.wrapUrl(baseUrl);

      developer.log('🌐 Trying URL: $testUrl');

      final response = await http
          .get(
            Uri.parse(testUrl),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 30));

      developer.log('📡 Response status: ${response.statusCode}');
      developer.log(
        '📄 Response content-type: ${response.headers['content-type']}',
      );
      developer.log('📏 Response length: ${response.body.length}');

      if (response.statusCode == 200) {
        // Convert ISO-8859-1 to UTF-8 if needed
        String responseBody = response.body;
        if (response.headers['content-type']?.contains('ISO-8859-1') ?? false) {
          try {
            responseBody = latin1.decode(response.bodyBytes);
          } catch (e) {
            developer.log('⚠️ Failed to decode ISO-8859-1: $e');
          }
        }
        
        // Parse HTML response to extract NOTAMs
        final notams = _parseHtmlNotams(responseBody, icaoCode);

        if (notams.isNotEmpty) {
          await _cacheNotams(icaoCode, notams);
        }

        return notams;
      }
    } catch (e) {
      developer.log('❌ Error fetching NOTAMs: $e');
    }

    // Return empty list if all fails
    return [];
  }

  /// Parse NOTAMs from HTML response
  List<Notam> _parseHtmlNotams(String html, String icaoCode) {
    final notams = <Notam>[];

    try {
      // First, decode HTML entities and URL encoding
      String cleanHtml = html
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'")
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&');
      
      // Don't try to URL decode the entire HTML - it's not URL encoded
      // Just clean up any specific URL-encoded characters that might appear
      cleanHtml = cleanHtml.replaceAll('%0A', '\n');
      cleanHtml = cleanHtml.replaceAll('%20', ' ');
      cleanHtml = cleanHtml.replaceAll('%2F', '/');
      cleanHtml = cleanHtml.replaceAll('%3A', ':');
      cleanHtml = cleanHtml.replaceAll('%28', '(');
      cleanHtml = cleanHtml.replaceAll('%29', ')');

      // Debug: Log a sample of the HTML to understand its structure
      if (cleanHtml.length > 1000) {
        developer.log('📄 HTML Sample (first 1000 chars): ${cleanHtml.substring(0, 1000)}');
      }
      
      // Look for NOTAM text patterns in HTML
      // FAA website typically shows NOTAMs in a specific format
      // Try multiple patterns to find NOTAMs
      final patterns = [
        // Pattern 1: Look for content between <PRE> tags (common for FAA NOTAMs)
        RegExp(r'<PRE[^>]*>([\s\S]*?)</PRE>', caseSensitive: false, multiLine: true),
        // Pattern 2: Look for NOTAM ID pattern (like M1031/25 or 1/2345) directly in text
        RegExp(r'(\d/\d{4}[\s\S]*?)(?=(?:\d/\d{4})|(?:</PRE>)|$)', multiLine: true),
        // Pattern 3: Look for traditional NOTAM format (A1234/23)
        RegExp(r'([A-Z]\d{4}/\d{2}[\s\S]*?)(?=(?:[A-Z]\d{4}/\d{2})|$)', multiLine: true),
        // Pattern 4: Table cells that might contain NOTAMs
        RegExp(r'<td[^>]*>([\s\S]*?(?:\d/\d{4}|[A-Z]\d{4}/\d{2})[\s\S]*?)</td>', caseSensitive: false, multiLine: true),
        // Pattern 5: Look for text that starts with the airport code
        RegExp(icaoCode + r'\s+[\s\S]*?(?:E\)|END)', caseSensitive: false, multiLine: true),
      ];
      
      final allMatches = <String>{};
      
      // First try to find all <PRE> content
      final prePattern = RegExp(r'<PRE[^>]*>([\s\S]*?)</PRE>', caseSensitive: false, multiLine: true);
      final preMatches = prePattern.allMatches(cleanHtml);
      
      developer.log('🔍 Found ${preMatches.length} <PRE> blocks');
      
      for (final preMatch in preMatches) {
        final preContent = preMatch.group(1) ?? '';
        if (preContent.trim().isNotEmpty) {
          // Split by double newlines or NOTAM boundaries
          final notamBlocks = preContent.split(RegExp(r'\n\s*\n|\r\n\s*\r\n'));
          for (final block in notamBlocks) {
            if (block.trim().isNotEmpty && 
                (block.contains(RegExp(r'\d/\d{4}')) || 
                 block.contains(RegExp(r'[A-Z]\d{4}/\d{2}')) ||
                 block.contains(icaoCode))) {
              allMatches.add(block.trim());
            }
          }
        }
      }
      
      // If no PRE blocks found, try other patterns
      if (allMatches.isEmpty) {
        for (final pattern in patterns) {
          final matches = pattern.allMatches(cleanHtml);
          for (final match in matches) {
            final text = match.group(match.groupCount > 0 ? 1 : 0) ?? '';
            if (text.trim().isNotEmpty) {
              allMatches.add(text);
            }
          }
        }
      }
      
      developer.log('🔍 Found ${allMatches.length} potential NOTAM blocks');

      for (final notamText in allMatches) {
        String cleanedText = notamText.trim();
        
        // Remove any remaining HTML tags or attributes
        cleanedText = cleanedText.replaceAll(RegExp(r'<[^>]+>'), '');
        
        // Remove HTML entities
        cleanedText = cleanedText
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'");
        
        // Remove any control characters except newlines
        cleanedText = cleanedText.replaceAll(RegExp(r'[\x00-\x08\x0B-\x1F\x7F]'), '');
        
        // Normalize whitespace
        cleanedText = cleanedText.replaceAll(RegExp(r'\s+'), ' ').trim();
        
        if (cleanedText.isNotEmpty && cleanedText.length > 20) {
          developer.log(
            '📄 Found potential NOTAM: ${cleanedText.substring(0, cleanedText.length > 100 ? 100 : cleanedText.length)}...',
          );

          // Try to parse ICAO format NOTAM
          final parsedNotam = _parseIcaoNotam(cleanedText, icaoCode);
          if (parsedNotam != null) {
            notams.add(parsedNotam);
          }
        }
      }
    } catch (e) {
      developer.log('❌ Error parsing HTML NOTAMs: $e');
    }

    return notams;
  }

  /// Parse ICAO format NOTAM text
  Notam? _parseIcaoNotam(String notamText, String icaoCode) {
    try {
      // First, ensure the text is properly cleaned
      String cleanedNotamText = notamText
          .replaceAll(RegExp(r'&quot;'), '"')
          .replaceAll(RegExp(r'&apos;'), "'")
          .replaceAll(RegExp(r'&lt;'), '<')
          .replaceAll(RegExp(r'&gt;'), '>')
          .replaceAll(RegExp(r'&amp;'), '&')
          .replaceAll(RegExp(r'&#\d+;'), '') // Remove numeric entities
          .replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '') // Remove URL encoding
          .trim();
      // ICAO NOTAM format example:
      // A1234/23 NOTAMN
      // Q) ZNY/QMXLC/IV/NBO/A/000/999/4038N07347W005
      // A) KEWR B) 2301011200 C) 2312312359
      // E) RWY 04L/22R CLSD
      // F) SFC G) UNL

      // Extract NOTAM ID - try multiple formats
      String? notamId;
      
      // Try format like M1031/25
      var idMatch = RegExp(r'([A-Z]\d{3,4}/\d{2})').firstMatch(cleanedNotamText);
      if (idMatch != null) {
        notamId = idMatch.group(1);
      } else {
        // Try format like 1/2345
        idMatch = RegExp(r'(\d/\d{4})').firstMatch(cleanedNotamText);
        if (idMatch != null) {
          notamId = idMatch.group(1);
        } else {
          // Try any word/number combination
          idMatch = RegExp(r'([\w\d]+/\d{2,4})').firstMatch(cleanedNotamText);
          if (idMatch != null) {
            notamId = idMatch.group(1);
          }
        }
      }
      
      if (notamId == null) {
        developer.log('⚠️ No NOTAM ID found in: ${cleanedNotamText.substring(0, cleanedNotamText.length > 50 ? 50 : cleanedNotamText.length)}...');
        return null;
      }
      
      notamId = notamId.trim();

      // Extract dates
      DateTime? effectiveFrom;
      DateTime? effectiveUntil;

      final bMatch = RegExp(r'B\)\s*(\d{10})').firstMatch(cleanedNotamText);
      if (bMatch != null) {
        effectiveFrom = _parseNotamDateTime(bMatch.group(1)!);
      }

      final cMatch = RegExp(r'C\)\s*(\d{10}|PERM)').firstMatch(cleanedNotamText);
      if (cMatch != null && cMatch.group(1) != 'PERM') {
        effectiveUntil = _parseNotamDateTime(cMatch.group(1)!);
      }

      // Extract message
      String message;
      
      // Try to find E) section
      final eMatch = RegExp(
        r'E\)\s*([^\n]+(?:\n(?![A-Z]\))[^\n]+)*)',
      ).firstMatch(cleanedNotamText);
      
      if (eMatch != null) {
        message = eMatch.group(1)?.trim() ?? '';
      } else {
        // If no E) section, try to extract the main content
        // Look for the NOTAM ID and take everything after it
        final idIndex = cleanedNotamText.indexOf(notamId);
        if (idIndex >= 0) {
          message = cleanedNotamText.substring(idIndex + notamId.length).trim();
          // Remove any leading punctuation or whitespace
          message = message.replaceFirst(RegExp(r'^[%\s\-_]+'), '');
        } else {
          message = cleanedNotamText;
        }
      }
      
      // Clean the message further
      message = message
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .replaceAll(RegExp(r'<[^>]+>'), '') // Remove any remaining HTML tags
          .replaceAll(RegExp(r'id\s*=\s*"[^"]*"'), '') // Remove id attributes
          .replaceAll(RegExp(r'%\d+'), '') // Remove %0 type artifacts
          .trim();

      // Set effective from to now if not found
      effectiveFrom ??= DateTime.now().toUtc();

      return Notam(
        id: '${notamId}_${effectiveFrom.millisecondsSinceEpoch}',
        notamId: notamId,
        icaoCode: icaoCode,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
        schedule: '',
        text: cleanedNotamText, // Use cleaned text
        decodedText: message,
        fetchedAt: DateTime.now().toUtc(),
        category: NotamCategory.categorizeFromText(message),
      );
    } catch (e) {
      developer.log('⚠️ Error parsing ICAO NOTAM: $e');
      return null;
    }
  }

  /// Parse NOTAM datetime format (YYMMDDHHmm)
  DateTime? _parseNotamDateTime(String dateStr) {
    try {
      if (dateStr.length != 10) return null;

      final year = 2000 + int.parse(dateStr.substring(0, 2));
      final month = int.parse(dateStr.substring(2, 4));
      final day = int.parse(dateStr.substring(4, 6));
      final hour = int.parse(dateStr.substring(6, 8));
      final minute = int.parse(dateStr.substring(8, 10));

      return DateTime.utc(year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  /// Create test NOTAMs for UI verification
  List<Notam> _createTestNotams() {
    final now = DateTime.now().toUtc();

    return [
      Notam(
        id: 'test1',
        notamId: 'A1234/23',
        icaoCode: 'TEST',
        type: 'N',
        effectiveFrom: now.subtract(const Duration(days: 1)),
        effectiveUntil: now.add(const Duration(days: 7)),
        schedule: 'DAILY 1200-1800',
        text:
            'A1234/23 NOTAMN\nQ) ZNY/QMXLC/IV/NBO/A/000/999/4038N07347W005\nA) KEWR B) 2301011200 C) 2312312359\nE) RWY 04L/22R CLSD DUE TO CONSTRUCTION',
        decodedText: 'RWY 04L/22R CLSD DUE TO CONSTRUCTION',
        purpose: 'NBO',
        scope: 'A',
        traffic: 'IV',
        fetchedAt: now,
        category: NotamCategory.runway,
      ),
      Notam(
        id: 'test2',
        notamId: 'A5678/23',
        icaoCode: 'TEST',
        type: 'N',
        effectiveFrom: now.subtract(const Duration(hours: 12)),
        effectiveUntil: now.add(const Duration(days: 2)),
        schedule: '',
        text: 'A5678/23 NOTAMN\nE) ILS RWY 22L OUT OF SERVICE',
        decodedText: 'ILS RWY 22L OUT OF SERVICE',
        fetchedAt: now,
        category: NotamCategory.navaid,
      ),
      Notam(
        id: 'test3',
        notamId: 'A9012/23',
        icaoCode: 'TEST',
        type: 'N',
        effectiveFrom: now.add(const Duration(days: 2)),
        effectiveUntil: now.add(const Duration(days: 5)),
        schedule: 'MON-FRI 0800-1700',
        text: 'A9012/23 NOTAMN\nE) CRANE ERECTED 500FT EAST OF RWY 04R',
        decodedText: 'CRANE ERECTED 500FT EAST OF RWY 04R, 150FT AGL',
        fetchedAt: now,
        category: NotamCategory.obstacle,
      ),
    ];
  }

  bool _isCacheValid(List<Notam> notams) {
    if (notams.isEmpty) return false;

    final oldestFetch = notams
        .map((n) => n.fetchedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    return DateTime.now().difference(oldestFetch) < _cacheExpiry;
  }

  Future<List<Notam>> _getCachedNotams(String icaoCode) async {
    final cacheKey = 'notams_$icaoCode';
    final cachedData = await _cacheService.getCachedData(cacheKey);

    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = json.decode(cachedData);
        return jsonList.map((json) {
          // Ensure the JSON data is properly typed
          final Map<String, dynamic> notamJson = Map<String, dynamic>.from(
            json,
          );

          // Clean up any corrupted NOTAM IDs
          if (notamJson['notamId'] != null) {
            String notamId = notamJson['notamId'].toString();
            // Remove any URL encoding artifacts
            notamId = notamId.replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '');
            // Remove any null bytes or control characters
            notamId = notamId.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
            // Remove any HTML fragments that might have been cached
            notamId = notamId.replaceAll(RegExp(r'"[^"]*"'), '');
            notamId = notamId.replaceAll(RegExp(r'id\s*=\s*\S+'), '');
            notamId = notamId.replaceAll(RegExp(r'[<>"]'), '');
            // Extract just the NOTAM ID pattern
            final idMatch = RegExp(r'([A-Z]\d{4}/\d{2})').firstMatch(notamId);
            if (idMatch != null) {
              notamId = idMatch.group(1)!;
            }
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
        // Remove any HTML fragments
        notamId = notamId.replaceAll(RegExp(r'"[^"]*"'), '');
        notamId = notamId.replaceAll(RegExp(r'id\s*=\s*\S+'), '');
        notamId = notamId.replaceAll(RegExp(r'[<>"]'), '');
        // Extract just the NOTAM ID pattern
        final idMatch = RegExp(r'([A-Z]\d{4}/\d{2})').firstMatch(notamId);
        if (idMatch != null) {
          notamId = idMatch.group(1)!;
        }
        json['notamId'] = notamId.trim();
      }

      return json;
    }).toList();

    final jsonData = json.encode(cleanedNotams);
    await _cacheService.cacheData(cacheKey, jsonData);
  }

  // Expose parsing method for testing
  List<Notam> parseHtmlNotamsForTesting(String html, String icaoCode) {
    return _parseHtmlNotams(html, icaoCode);
  }
}
