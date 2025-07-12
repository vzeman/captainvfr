// import 'dart:developer' show log;
import '../../models/airport.dart';
import '../../models/runway.dart';
import '../../models/frequency.dart';
import '../../services/weather_service.dart';
import '../../services/runway_service.dart';
import '../../services/frequency_service.dart';

class AirportDataFetcher {
  final WeatherService weatherService;
  final RunwayService runwayService;
  final FrequencyService frequencyService;

  AirportDataFetcher({
    required this.weatherService,
    required this.runwayService,
    required this.frequencyService,
  });

  /// Check if weather data should be fetched for this airport type
  bool shouldFetchWeatherForAirport(Airport airport) {
    // Only fetch weather for medium and large airports
    // Small airports, heliports, seaplane bases typically don't have weather stations
    switch (airport.type.toLowerCase()) {
      case 'large_airport':
      case 'medium_airport':
        return true;
      case 'small_airport':
      case 'heliport':
      case 'seaplane_base':
      case 'closed':
        return false;
      default:
        // For unknown types, check if it has an ICAO code
        // Airports with proper ICAO codes are more likely to have weather data
        return airport.icao.length == 4 && RegExp(r'^[A-Z]{4}$').hasMatch(airport.icao);
    }
  }

  Future<void> fetchWeather(Airport airport) async {
    // Check if this airport type should have weather data
    if (!shouldFetchWeatherForAirport(airport)) {
      return;
    }

    // Always show cached data first if available
    final cachedMetar = weatherService.getCachedMetar(airport.icao);
    final cachedTaf = weatherService.getCachedTaf(airport.icao);

    if (cachedMetar != null) {
      airport.updateWeather(cachedMetar);
    }
    if (cachedTaf != null) {
      airport.taf = cachedTaf;
      airport.lastWeatherUpdate = DateTime.now().toUtc();
    }

    // Fetch weather data (this will return cached data immediately and trigger reload if needed)
    final metar = await weatherService.getMetar(airport.icao);
    final taf = await weatherService.getTaf(airport.icao);

    if (metar != null) {
      airport.updateWeather(metar);
    }
    if (taf != null) {
      airport.taf = taf;
      airport.lastWeatherUpdate = DateTime.now().toUtc();
    }
  }

  List<Runway> fetchRunways(String icao) {
    return runwayService.getRunwaysForAirport(icao);
  }

  List<Frequency> fetchFrequencies(Airport airport) {
    // log('🔍 Looking for frequencies for airport: ${airport.icao}');
    // log('📋 Airport details - ICAO: ${airport.icao}, IATA: ${airport.iata}, Local: ${airport.localCode}, GPS: ${airport.gpsCode}');

    List<Frequency> frequencies = frequencyService.getFrequenciesForAirport(airport.icao);
    // log('📻 Found ${frequencies.length} frequencies for ICAO: ${airport.icao}');

    // Debug: Show some sample frequencies if we have any in the service
    final totalFrequenciesInService = frequencyService.frequencies.length;
    if (totalFrequenciesInService > 0 && frequencies.isEmpty) {
      // log('🔧 DEBUG: Service has frequencies but none found for ${airport.icao}');

      // Try exact case-insensitive search
      final upperIcao = airport.icao.toUpperCase();
      final matchingFreqs = frequencyService.frequencies.where((f) =>
        f.airportIdent.toUpperCase() == upperIcao).toList();
      // log('🔧 DEBUG: Case-insensitive match found: ${matchingFreqs.length} frequencies');
      if (matchingFreqs.isNotEmpty) {
        frequencies = matchingFreqs;
      }
    }

    // Try with other identifiers if available
    if (frequencies.isEmpty && airport.iata != null && airport.iata!.isNotEmpty) {
      // log('🔍 Trying with IATA code: ${airport.iata}');
      final iataFrequencies = frequencyService.getFrequenciesForAirport(airport.iata!);
      // log('📻 Found ${iataFrequencies.length} frequencies with IATA code');
      if (iataFrequencies.isNotEmpty) {
        frequencies = [...frequencies, ...iataFrequencies];
      }
    }

    // Try with local code if available
    if (frequencies.isEmpty && airport.localCode != null && airport.localCode!.isNotEmpty) {
      // log('🔍 Trying with local code: ${airport.localCode}');
      final localFrequencies = frequencyService.getFrequenciesForAirport(airport.localCode!);
      // log('📻 Found ${localFrequencies.length} frequencies with local code');
      if (localFrequencies.isNotEmpty) {
        frequencies = [...frequencies, ...localFrequencies];
      }
    }

    // Try with GPS code if available
    if (frequencies.isEmpty && airport.gpsCode != null && airport.gpsCode!.isNotEmpty) {
      // log('🔍 Trying with GPS code: ${airport.gpsCode}');
      final gpsFrequencies = frequencyService.getFrequenciesForAirport(airport.gpsCode!);
      // log('📻 Found ${gpsFrequencies.length} frequencies with GPS code');
      if (gpsFrequencies.isNotEmpty) {
        frequencies = [...frequencies, ...gpsFrequencies];
      }
    }

    // log('📻 Total frequencies found: ${frequencies.length}');

    // Debug: Log the actual frequencies found
    // if (frequencies.isNotEmpty) {
    //   // log('🔧 DEBUG: Found frequencies:');
    //   for (final freq in frequencies) {
    //     // log('   - ${freq.type}: ${freq.frequencyMhz} MHz (${freq.description ?? 'No description'})');
    //   }
    // } else {
    //   // log('🔧 DEBUG: No frequencies found for this airport');
    // }

    return frequencies;
  }
}
