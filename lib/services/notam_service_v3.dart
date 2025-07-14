import 'dart:convert';
import 'dart:developer' as developer;
import '../models/notam.dart';
import 'cache_service.dart';

/// NOTAM service using alternative data sources
class NotamServiceV3 {
  static final NotamServiceV3 _instance = NotamServiceV3._internal();
  factory NotamServiceV3() => _instance;
  NotamServiceV3._internal();

  final CacheService _cacheService = CacheService();
  static const Duration _cacheExpiry = Duration(hours: 6);

  /// Prefetch NOTAMs for multiple airports in parallel
  Future<void> prefetchNotamsForAirports(List<String> icaoCodes) async {
    if (icaoCodes.isEmpty) return;

    developer.log('📋 V3: Prefetching NOTAMs for ${icaoCodes.length} airports');

    // Process in batches to avoid overwhelming the cache
    const batchSize = 10; // V3 is just mock data, so we can handle more
    for (int i = 0; i < icaoCodes.length; i += batchSize) {
      final batch = icaoCodes.skip(i).take(batchSize).toList();

      // Fetch NOTAMs in parallel for this batch
      await Future.wait(
        batch.map(
          (icao) =>
              getNotamsForAirport(icao, forceRefresh: false).catchError((e) {
                developer.log('⚠️ V3: Failed to prefetch NOTAMs for $icao: $e');
                return <Notam>[];
              }),
        ),
      );
    }

    developer.log('✅ V3: Prefetch complete for ${icaoCodes.length} airports');
  }

  /// Mock NOTAM data for demonstration
  /// In a real implementation, this would fetch from ICAO API or other sources
  Future<List<Notam>> getNotamsForAirport(
    String icaoCode, {
    bool forceRefresh = false,
  }) async {
    developer.log('📋 Fetching NOTAMs for $icaoCode using V3 service');

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

    // Generate realistic NOTAMs for demonstration
    // In production, replace this with actual API calls
    final notams = _generateRealisticNotams(icaoCode);

    // Cache the results
    if (notams.isNotEmpty) {
      await _cacheNotams(icaoCode, notams);
    }

    return notams;
  }

  /// Generate realistic NOTAM data for demonstration
  List<Notam> _generateRealisticNotams(String icaoCode) {
    final now = DateTime.now().toUtc();
    final notams = <Notam>[];

    // Common NOTAM scenarios based on airport code
    if (icaoCode == 'KEWR' || icaoCode == 'KJFK' || icaoCode == 'KLGA') {
      // New York area airports - common NOTAMs
      notams.addAll([
        Notam(
          id: 'A2156/24_${now.millisecondsSinceEpoch}',
          notamId: 'A2156/24',
          icaoCode: icaoCode,
          type: 'N',
          effectiveFrom: now.subtract(const Duration(days: 2)),
          effectiveUntil: now.add(const Duration(days: 5)),
          schedule: 'DLY 0600-1400',
          text:
              'A2156/24 NOTAMN\nQ) ZNY/QMXLC/IV/NBO/A/000/999/4038N07347W005\nA) $icaoCode\nB) 2401151200\nC) 2401252359\nE) TWY A BTN TWY B AND TWY C CLSD',
          decodedText: 'Taxiway A between Taxiway B and Taxiway C closed',
          purpose: 'NBO',
          scope: 'A',
          traffic: 'IV',
          fetchedAt: now,
          category: NotamCategory.taxiway,
        ),
        Notam(
          id: 'A2203/24_${now.millisecondsSinceEpoch}',
          notamId: 'A2203/24',
          icaoCode: icaoCode,
          type: 'N',
          effectiveFrom: now.subtract(const Duration(hours: 12)),
          effectiveUntil: null, // Permanent
          schedule: '',
          text: 'A2203/24 NOTAMN\nE) ILS RWY 22L GLIDE SLOPE U/S',
          decodedText: 'ILS Runway 22L glide slope unserviceable',
          fetchedAt: now,
          category: NotamCategory.navaid,
        ),
        Notam(
          id: 'A2198/24_${now.millisecondsSinceEpoch}',
          notamId: 'A2198/24',
          icaoCode: icaoCode,
          type: 'N',
          effectiveFrom: now.subtract(const Duration(days: 1)),
          effectiveUntil: now.add(const Duration(days: 14)),
          schedule: 'MON-FRI 1300-2100',
          text:
              'A2198/24 NOTAMN\nE) CRANE ERECTED 1500FT SE OF RWY 04R THR, 180FT AGL/223FT MSL, LGTD',
          decodedText:
              'Crane erected 1500 feet southeast of Runway 04R threshold, 180 feet above ground level/223 feet mean sea level, lighted',
          fetchedAt: now,
          category: NotamCategory.obstacle,
        ),
      ]);
    }

    // Add NOTAMs for other major airports
    if (icaoCode == 'KORD' || icaoCode == 'KATL' || icaoCode == 'KLAX') {
      // Major US airports might have operational NOTAMs
      notams.add(
        Notam(
          id: 'A1847/24_${now.millisecondsSinceEpoch}',
          notamId: 'A1847/24',
          icaoCode: icaoCode,
          type: 'N',
          effectiveFrom: now.subtract(const Duration(days: 1)),
          effectiveUntil: now.add(const Duration(days: 7)),
          schedule: 'DLY 2200-0600',
          text: 'A1847/24 NOTAMN\nE) RWY 28L/10R CLSD DUE TO MAINT',
          decodedText: 'Runway 28L/10R closed due to maintenance',
          fetchedAt: now,
          category: NotamCategory.runway,
        ),
      );
    }

    // Add NOTAMs for some European airports
    if (icaoCode == 'EGLL' || icaoCode == 'LFPG' || icaoCode == 'EDDF') {
      notams.add(
        Notam(
          id: 'B0756/24_${now.millisecondsSinceEpoch}',
          notamId: 'B0756/24',
          icaoCode: icaoCode,
          type: 'N',
          effectiveFrom: now.subtract(const Duration(hours: 6)),
          effectiveUntil: now.add(const Duration(days: 2)),
          schedule: '',
          text: 'B0756/24 NOTAMN\nE) APRON STAND 45-48 CLSD',
          decodedText: 'Apron stands 45-48 closed',
          fetchedAt: now,
          category: NotamCategory.apron,
        ),
      );
    }

    // Small airfields like LZDV typically don't have NOTAMs
    // Return empty list for most airports

    // Sort by importance and date
    notams.sort((a, b) {
      final importanceCompare = b.importance.index.compareTo(
        a.importance.index,
      );
      if (importanceCompare != 0) return importanceCompare;
      return b.effectiveFrom.compareTo(a.effectiveFrom);
    });

    return notams;
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
    developer.log('📋 Checking cache for key: $cacheKey');
    final cachedData = await _cacheService.getCachedData(cacheKey);

    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = json.decode(cachedData);
        final notams = jsonList.map((json) {
          // Ensure the JSON data is properly typed
          final Map<String, dynamic> notamJson = Map<String, dynamic>.from(
            json,
          );

          // Clean up any corrupted NOTAM IDs
          if (notamJson['notamId'] != null) {
            String notamId = notamJson['notamId'].toString();
            
            // Extract just the NOTAM ID pattern (e.g., A1234/24)
            final notamIdMatch = RegExp(r'([A-Z]\d{4}/\d{2})').firstMatch(notamId);
            if (notamIdMatch != null) {
              // Use only the extracted NOTAM ID, discarding any corruption
              notamId = notamIdMatch.group(0) ?? '';
            } else {
              // If no valid pattern found, clean up the string
              // Remove any HTML tags or fragments
              notamId = notamId.replaceAll(RegExp(r'<[^>]*>'), '');
              // Remove any URL encoding artifacts
              notamId = notamId.replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '');
              // Remove any null bytes or control characters
              notamId = notamId.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
              // Remove any special HTML entities
              notamId = notamId.replaceAll(RegExp(r'&[a-zA-Z]+;'), '');
              notamId = notamId.trim();
            }
            
            notamJson['notamId'] = notamId;
          }

          return Notam.fromJson(notamJson);
        }).toList();

        developer.log('📋 Found ${notams.length} cached NOTAMs for $icaoCode');
        // Log first NOTAM ID to debug
        if (notams.isNotEmpty) {
          developer.log(
            '📋 First cached NOTAM ID: ${notams.first.notamId} for ${notams.first.icaoCode}',
          );
        }
        return notams;
      } catch (e) {
        developer.log('❌ Error parsing cached NOTAMs: $e');
        // Clear corrupted cache
        await _cacheService.clearCachedData(cacheKey);
        return [];
      }
    }

    developer.log('📋 No cached NOTAMs found for $icaoCode');
    return [];
  }

  Future<void> _cacheNotams(String icaoCode, List<Notam> notams) async {
    final cacheKey = 'notams_$icaoCode';
    developer.log(
      '📋 Caching ${notams.length} NOTAMs for $icaoCode with key: $cacheKey',
    );
    if (notams.isNotEmpty) {
      developer.log(
        '📋 First NOTAM to cache: ${notams.first.notamId} for ${notams.first.icaoCode}',
      );
    }

    // Clean up NOTAM data before caching to prevent corruption
    final cleanedNotams = notams.map((notam) {
      final json = notam.toJson();

      // Ensure NOTAM ID is clean
      if (json['notamId'] != null) {
        String notamId = json['notamId'].toString();
        
        // Extract just the NOTAM ID pattern (e.g., A1234/24)
        final notamIdMatch = RegExp(r'([A-Z]\d{4}/\d{2})').firstMatch(notamId);
        if (notamIdMatch != null) {
          // Use only the extracted NOTAM ID, discarding any corruption
          notamId = notamIdMatch.group(0) ?? '';
        } else {
          // If no valid pattern found, clean up the string
          // Remove any HTML tags or fragments
          notamId = notamId.replaceAll(RegExp(r'<[^>]*>'), '');
          // Remove any URL encoding artifacts
          notamId = notamId.replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '');
          // Remove any null bytes or control characters
          notamId = notamId.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
          // Remove any special HTML entities
          notamId = notamId.replaceAll(RegExp(r'&[a-zA-Z]+;'), '');
          notamId = notamId.trim();
        }
        
        json['notamId'] = notamId;
      }

      return json;
    }).toList();

    final jsonData = json.encode(cleanedNotams);
    await _cacheService.cacheData(cacheKey, jsonData);
  }
}
