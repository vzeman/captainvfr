import 'dart:async';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/frequency.dart';
import 'cache_service.dart';

class FrequencyService {
  static const String _baseUrl = 'https://davidmegginson.github.io/ourairports-data';
  static const String _frequenciesUrl = '$_baseUrl/airport-frequencies.csv';

  List<Frequency> _frequencies = [];
  bool _isLoading = false;
  final CacheService _cacheService = CacheService();

  // Singleton pattern
  static final FrequencyService _instance = FrequencyService._internal();
  factory FrequencyService() => _instance;
  FrequencyService._internal();

  bool get isLoading => _isLoading;
  List<Frequency> get frequencies => List.unmodifiable(_frequencies);

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    await _cacheService.initialize();
    await _loadCachedFrequencies();
  }

  /// Load frequencies from cache
  Future<void> _loadCachedFrequencies() async {
    try {
      final cachedFrequencies = await _cacheService.getCachedFrequencies();
      if (cachedFrequencies.isNotEmpty) {
        _frequencies = cachedFrequencies;
        developer.log('✅ Loaded ${_frequencies.length} frequencies from cache');
      }
    } catch (e) {
      developer.log('❌ Error loading cached frequencies: $e');
    }
  }

  /// Fetch frequencies from remote source
  Future<void> fetchFrequencies({bool forceRefresh = false}) async {
    if (_isLoading) return;

    // Check if we need to refresh
    if (!forceRefresh && _frequencies.isNotEmpty) {
      final lastFetch = await _cacheService.getFrequenciesLastFetch();
      if (lastFetch != null) {
        final hoursSinceLastFetch = DateTime.now().difference(lastFetch).inHours;
        if (hoursSinceLastFetch < 24) {
          developer.log('🔄 Frequencies data is recent, skipping fetch');
          return;
        }
      }
    }

    _isLoading = true;

    try {
      developer.log('🌐 Fetching frequencies data from remote source...');

      final response = await http.get(
        Uri.parse(_frequenciesUrl),
        headers: {'Accept': 'text/csv'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final csvData = response.body;
        final frequencies = await _parseFrequenciesCsv(csvData);

        _frequencies = frequencies;

        // Cache the data
        await _cacheService.cacheFrequencies(frequencies);
        await _cacheService.setFrequenciesLastFetch(DateTime.now());

        developer.log('✅ Successfully fetched and cached ${frequencies.length} frequencies');
      } else {
        throw Exception('Failed to fetch frequencies: HTTP ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Error fetching frequencies: $e');
      // If we have cached data, continue using it
      if (_frequencies.isEmpty) {
        rethrow;
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Parse CSV data into frequency objects
  Future<List<Frequency>> _parseFrequenciesCsv(String csvData) async {
    final frequencies = <Frequency>[];

    try {
      final lines = csvData.split('\n');

      // Skip header row
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          final frequency = Frequency.fromCsv(line);
          frequencies.add(frequency);
        } catch (e) {
          // Skip malformed rows
          developer.log('⚠️ Skipping malformed frequency row: $e');
          continue;
        }
      }

      developer.log('📊 Parsed ${frequencies.length} frequencies from CSV');
      return frequencies;
    } catch (e) {
      developer.log('❌ Error parsing frequencies CSV: $e');
      rethrow;
    }
  }

  /// Get frequencies for a specific airport
  List<Frequency> getFrequenciesForAirport(String airportIdent) {
    return _frequencies.where((frequency) =>
      frequency.airportIdent.toUpperCase() == airportIdent.toUpperCase()
    ).toList();
  }

  /// Get frequencies for multiple airports
  Map<String, List<Frequency>> getFrequenciesForAirports(List<String> airportIdents) {
    final result = <String, List<Frequency>>{};

    for (final ident in airportIdents) {
      result[ident] = getFrequenciesForAirport(ident);
    }

    return result;
  }

  /// Search frequencies by various criteria
  List<Frequency> searchFrequencies({
    String? airportIdent,
    String? type,
    double? minFrequency,
    double? maxFrequency,
  }) {
    return _frequencies.where((frequency) {
      if (airportIdent != null &&
          !frequency.airportIdent.toUpperCase().contains(airportIdent.toUpperCase())) {
        return false;
      }

      if (type != null &&
          !frequency.type.toUpperCase().contains(type.toUpperCase())) {
        return false;
      }

      if (minFrequency != null && frequency.frequencyMhz < minFrequency) {
        return false;
      }

      if (maxFrequency != null && frequency.frequencyMhz > maxFrequency) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Get all unique frequency types
  List<String> getFrequencyTypes() {
    final types = _frequencies.map((f) => f.type).toSet().toList();
    types.sort();
    return types;
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await _cacheService.clearFrequenciesCache();
    _frequencies.clear();
    developer.log('🗑️ Cleared frequencies cache');
  }
}
