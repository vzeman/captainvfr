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
  static const Duration _cacheExpiry = Duration(hours: 1);
  
  /// Mock NOTAM data for demonstration
  /// In a real implementation, this would fetch from ICAO API or other sources
  Future<List<Notam>> getNotamsForAirport(String icaoCode, {bool forceRefresh = false}) async {
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
          text: 'A2156/24 NOTAMN\nQ) ZNY/QMXLC/IV/NBO/A/000/999/4038N07347W005\nA) $icaoCode B) 2401151200 C) 2401252359\nE) TWY A BTN TWY B AND TWY C CLSD',
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
          text: 'A2198/24 NOTAMN\nE) CRANE ERECTED 1500FT SE OF RWY 04R THR, 180FT AGL/223FT MSL, LGTD',
          decodedText: 'Crane erected 1500 feet southeast of Runway 04R threshold, 180 feet above ground level/223 feet mean sea level, lighted',
          fetchedAt: now,
          category: NotamCategory.obstacle,
        ),
      ]);
    }
    
    // Add generic NOTAMs for all airports
    notams.addAll([
      Notam(
        id: 'C0847/24_${now.millisecondsSinceEpoch}',
        notamId: 'C0847/24',
        icaoCode: icaoCode,
        type: 'N',
        effectiveFrom: now.add(const Duration(days: 3)),
        effectiveUntil: now.add(const Duration(days: 4)),
        schedule: '0800-1700',
        text: 'C0847/24 NOTAMN\nE) AIRSPACE CLSD WI 5NM RADIUS OF $icaoCode SFC-3000FT AGL DUE TO AEROBATIC ACT',
          decodedText: 'Airspace closed within 5 nautical mile radius of $icaoCode surface to 3000 feet above ground level due to aerobatic activity',
        fetchedAt: now,
        category: NotamCategory.airspace,
      ),
      Notam(
        id: 'C0892/24_${now.millisecondsSinceEpoch}',
        notamId: 'C0892/24',
        icaoCode: icaoCode,
        type: 'N',
        effectiveFrom: now.subtract(const Duration(days: 7)),
        effectiveUntil: now.add(const Duration(days: 30)),
        schedule: '',
        text: 'C0892/24 NOTAMN\nE) APRON NORTH CARGO AREA MARKING AND LIGHTING U/S',
        decodedText: 'Apron north cargo area marking and lighting unserviceable',
        fetchedAt: now,
        category: NotamCategory.apron,
      ),
    ]);
    
    // Sort by importance and date
    notams.sort((a, b) {
      final importanceCompare = b.importance.index.compareTo(a.importance.index);
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
    final cachedData = await _cacheService.getCachedData(cacheKey);
    
    if (cachedData != null) {
      final List<dynamic> jsonList = json.decode(cachedData);
      return jsonList.map((json) => Notam.fromJson(json)).toList();
    }
    
    return [];
  }
  
  Future<void> _cacheNotams(String icaoCode, List<Notam> notams) async {
    final cacheKey = 'notams_$icaoCode';
    final jsonData = json.encode(notams.map((n) => n.toJson()).toList());
    await _cacheService.cacheData(cacheKey, jsonData);
  }
}