import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/notam.dart';
import 'cache_service.dart';

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
      final testUrl =
          'https://www.notams.faa.gov/dinsQueryWeb/queryRetrievalMapAction.do'
          '?reportType=Raw&retrieveLocId=$icaoCode&actionType=notamRetrievalByICAOs';

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
        // Parse HTML response to extract NOTAMs
        final notams = _parseHtmlNotams(response.body, icaoCode);

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
      
      // Remove URL encoding artifacts
      try {
        cleanHtml = Uri.decodeComponent(cleanHtml);
      } catch (e) {
        // If decoding fails, just use the original
        developer.log('⚠️ Failed to decode URI: $e');
      }

      // Look for NOTAM text patterns in HTML
      // NOTAMs typically start with location code and have specific format
      final notamPattern = RegExp(
        r'<pre[^>]*>([\s\S]*?)</pre>|'
        r'<div[^>]*class="notam[^"]*"[^>]*>([\s\S]*?)</div>',
        multiLine: true,
        dotAll: true,
      );

      final matches = notamPattern.allMatches(cleanHtml);
      developer.log(
        '🔍 Found ${matches.length} potential NOTAM matches in HTML',
      );

      for (final match in matches) {
        String notamText =
            match.group(1) ?? match.group(2) ?? match.group(3) ?? '';
        
        // Clean up the text
        notamText = notamText.trim();
        
        // Remove any remaining HTML tags or attributes
        notamText = notamText.replaceAll(RegExp(r'<[^>]+>'), '');
        
        // Remove any URL encoding remnants
        notamText = notamText.replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '');
        
        // Remove any control characters
        notamText = notamText.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
        
        if (notamText.isNotEmpty && notamText.length > 20) {
          // Additional cleaning for edge cases
          // Remove any quotes and HTML attributes that might have slipped through
          notamText = notamText
              .replaceAll(RegExp(r'"[^"]*"'), '') // Remove quoted attributes
              .replaceAll(RegExp(r'id\s*=\s*\S+'), '') // Remove id attributes
              .replaceAll(RegExp(r'[<>"]'), '') // Remove any remaining HTML chars
              .trim();
          
          developer.log(
            '📄 Cleaned NOTAM text: ${notamText.substring(0, notamText.length > 100 ? 100 : notamText.length)}...',
          );

          // Try to parse ICAO format NOTAM
          final parsedNotam = _parseIcaoNotam(notamText, icaoCode);
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
      // ICAO NOTAM format example:
      // A1234/23 NOTAMN
      // Q) ZNY/QMXLC/IV/NBO/A/000/999/4038N07347W005
      // A) KEWR B) 2301011200 C) 2312312359
      // E) RWY 04L/22R CLSD
      // F) SFC G) UNL

      // Extract NOTAM ID
      final idMatch = RegExp(r'([A-Z]\d{4}/\d{2})').firstMatch(notamText);
      if (idMatch == null) return null;

      String notamId = idMatch.group(1)!;
      
      // Clean up NOTAM ID - remove any URL encoding or control characters
      notamId = notamId.replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '');
      notamId = notamId.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
      notamId = notamId.trim();

      // Extract dates
      DateTime? effectiveFrom;
      DateTime? effectiveUntil;

      final bMatch = RegExp(r'B\)\s*(\d{10})').firstMatch(notamText);
      if (bMatch != null) {
        effectiveFrom = _parseNotamDateTime(bMatch.group(1)!);
      }

      final cMatch = RegExp(r'C\)\s*(\d{10}|PERM)').firstMatch(notamText);
      if (cMatch != null && cMatch.group(1) != 'PERM') {
        effectiveUntil = _parseNotamDateTime(cMatch.group(1)!);
      }

      // Extract message
      final eMatch = RegExp(
        r'E\)\s*([^\n]+(?:\n(?![A-Z]\))[^\n]+)*)',
      ).firstMatch(notamText);
      final message = eMatch?.group(1)?.trim() ?? notamText;

      // Set effective from to now if not found
      effectiveFrom ??= DateTime.now().toUtc();

      return Notam(
        id: '${notamId}_${effectiveFrom.millisecondsSinceEpoch}',
        notamId: notamId,
        icaoCode: icaoCode,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
        schedule: '',
        text: notamText,
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
