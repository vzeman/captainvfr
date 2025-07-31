// import 'dart:developer' as developer;
import '../../models/airport.dart';
import '../../models/runway.dart';
import '../../models/unified_runway.dart';
import '../../models/frequency.dart';
import '../../services/weather_service.dart';
import '../../services/runway_service.dart';
import '../../services/bundled_frequency_service.dart';

class AirportDataFetcher {
  final WeatherService weatherService;
  final RunwayService runwayService;
  final BundledFrequencyService frequencyService;

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
        return airport.icao.length == 4 &&
            RegExp(r'^[A-Z]{4}$').hasMatch(airport.icao);
    }
  }

  Future<void> fetchWeather(Airport airport) async {
    // Check if this airport type should have weather data
    if (!shouldFetchWeatherForAirport(airport)) {
      return;
    }

    String? finalMetar;
    String? finalTaf;

    // Always show cached data first if available
    final cachedMetar = weatherService.getCachedMetar(airport.icao);
    final cachedTaf = weatherService.getCachedTaf(airport.icao);

    if (cachedMetar != null) {
      finalMetar = cachedMetar;
    }
    if (cachedTaf != null) {
      finalTaf = cachedTaf;
    }

    // Fetch weather data (this will return cached data immediately and trigger reload if needed)
    final metar = await weatherService.getMetar(airport.icao);
    final taf = await weatherService.getTaf(airport.icao);

    if (metar != null) {
      finalMetar = metar;
    }
    if (taf != null) {
      finalTaf = taf;
    }

    // Batch all updates into a single operation to minimize widget rebuilds
    if (finalMetar != null || finalTaf != null) {
      // Use a deferred update to avoid buildScope issues
      Future.microtask(() {
        if (finalMetar != null) {
          airport.updateWeather(finalMetar);
        }
        if (finalTaf != null && finalTaf != finalMetar) {
          airport.taf = finalTaf;
          airport.lastWeatherUpdate = DateTime.now().toUtc();
        }
      });
    }
  }

  Future<List<Runway>> fetchRunways(Airport airport) async {
    // First check if the airport already has runway data from embedded sources
    if (airport.runways != null && airport.runways!.isNotEmpty) {
      // Convert embedded runway data directly
      final embeddedRunways = <Runway>[];
      final openAIPRunways = airport.openAIPRunways;
      
      if (openAIPRunways.isNotEmpty) {
        // Convert OpenAIP runways to Runway objects
        for (final openAIPRunway in openAIPRunways) {
          final unified = UnifiedRunway.fromOpenAIPRunway(
            openAIPRunway,
            airport.icao,
            airportLat: airport.position.latitude,
            airportLon: airport.position.longitude,
          );
          embeddedRunways.add(unified.toRunway());
        }
        return embeddedRunways;
      }
    }
    
    // Otherwise, load from runway service
    const buffer = 0.5; // degrees - small buffer around airport
    await runwayService.loadRunwaysForArea(
      minLat: airport.position.latitude - buffer,
      maxLat: airport.position.latitude + buffer,
      minLon: airport.position.longitude - buffer,
      maxLon: airport.position.longitude + buffer,
    );
    
    // Don't pass OpenAIP runways to avoid duplication
    return runwayService.getRunwaysForAirport(
      airport.icao,
      openAIPRunways: null, // Don't pass embedded runways to avoid duplication
      airportLat: airport.position.latitude,
      airportLon: airport.position.longitude,
    );
  }
  
  Future<List<UnifiedRunway>> fetchUnifiedRunways(Airport airport) async {
    // First check if the airport already has runway data from embedded sources
    if (airport.runways != null && airport.runways!.isNotEmpty) {
      final openAIPRunways = airport.openAIPRunways;
      
      if (openAIPRunways.isNotEmpty) {
        // Convert OpenAIP runways to UnifiedRunway objects
        return openAIPRunways.map((openAIPRunway) => UnifiedRunway.fromOpenAIPRunway(
          openAIPRunway,
          airport.icao,
          airportLat: airport.position.latitude,
          airportLon: airport.position.longitude,
        )).toList();
      }
    }
    
    // Otherwise, load from runway service
    const buffer = 0.5; // degrees - small buffer around airport
    await runwayService.loadRunwaysForArea(
      minLat: airport.position.latitude - buffer,
      maxLat: airport.position.latitude + buffer,
      minLon: airport.position.longitude - buffer,
      maxLon: airport.position.longitude + buffer,
    );
    
    // Don't pass OpenAIP runways to avoid duplication
    return runwayService.getUnifiedRunwaysForAirport(
      airport.icao,
      openAIPRunways: null, // Don't pass embedded runways to avoid duplication
      airportLat: airport.position.latitude,
      airportLon: airport.position.longitude,
    );
  }

  Future<List<Frequency>> fetchFrequencies(Airport airport) async {
    // First check if the airport already has frequency data from TiledDataLoader
    if (airport.frequencies != null && airport.frequencies!.isNotEmpty) {
      // Convert embedded frequency data to Frequency objects
      final embeddedFrequencies = <Frequency>[];
      
      for (final freqData in airport.frequenciesList) {
        final freqMhz = double.tryParse(freqData['frequency_mhz']?.toString() ?? '') ?? 0.0;
        
        if (freqMhz > 0) {
          final frequency = Frequency(
            id: 0,
            airportIdent: airport.icao,
            type: freqData['type']?.toString() ?? '',
            description: freqData['description']?.toString(),
            frequencyMhz: freqMhz,
          );
          embeddedFrequencies.add(frequency);
        }
      }
      
      if (embeddedFrequencies.isNotEmpty) {
        return embeddedFrequencies;
      }
    }
    
    // For tiled data, we need to load the area around the airport first
    const buffer = 0.5; // degrees - small buffer around airport
    await frequencyService.loadFrequenciesForArea(
      minLat: airport.position.latitude - buffer,
      maxLat: airport.position.latitude + buffer,
      minLon: airport.position.longitude - buffer,
      maxLon: airport.position.longitude + buffer,
    );
    
    // log('🔍 Looking for frequencies for airport: ${airport.icao}');
    // log('📋 Airport details - ICAO: ${airport.icao}, IATA: ${airport.iata}, Local: ${airport.localCode}, GPS: ${airport.gpsCode}');

    List<Frequency> frequencies = frequencyService.getFrequenciesForAirport(
      airport.icao,
    );
    
    // Convert numeric frequency types to readable names for external service frequencies
    frequencies = frequencies.map((freq) {
      if (RegExp(r'^\d+$').hasMatch(freq.type)) {
        return Frequency(
          id: freq.id,
          airportIdent: freq.airportIdent,
          type: _convertFrequencyType(freq.type),
          description: freq.description,
          frequencyMhz: freq.frequencyMhz,
        );
      }
      return freq;
    }).toList();
    // log('📻 Found ${frequencies.length} frequencies for ICAO: ${airport.icao}');

    // Debug: Show some sample frequencies if we have any in the service
    final totalFrequenciesInService = frequencyService.frequencies.length;
    if (totalFrequenciesInService > 0 && frequencies.isEmpty) {
      // log('🔧 DEBUG: Service has frequencies but none found for ${airport.icao}');

      // Try exact case-insensitive search
      final upperIcao = airport.icao.toUpperCase();
      final matchingFreqs = frequencyService.frequencies
          .where((f) => f.airportIdent.toUpperCase() == upperIcao)
          .toList();
      // log('🔧 DEBUG: Case-insensitive match found: ${matchingFreqs.length} frequencies');
      if (matchingFreqs.isNotEmpty) {
        frequencies = matchingFreqs.map((freq) {
          if (RegExp(r'^\d+$').hasMatch(freq.type)) {
            return Frequency(
              id: freq.id,
              airportIdent: freq.airportIdent,
              type: _convertFrequencyType(freq.type),
              description: freq.description,
              frequencyMhz: freq.frequencyMhz,
            );
          }
          return freq;
        }).toList();
      }
    }

    // Try with other identifiers if available
    if (frequencies.isEmpty &&
        airport.iata != null &&
        airport.iata!.isNotEmpty) {
      // log('🔍 Trying with IATA code: ${airport.iata}');
      final iataFrequencies = frequencyService.getFrequenciesForAirport(
        airport.iata!,
      );
      // log('📻 Found ${iataFrequencies.length} frequencies with IATA code');
      if (iataFrequencies.isNotEmpty) {
        final convertedIataFreqs = iataFrequencies.map((freq) {
          if (RegExp(r'^\d+$').hasMatch(freq.type)) {
            return Frequency(
              id: freq.id,
              airportIdent: freq.airportIdent,
              type: _convertFrequencyType(freq.type),
              description: freq.description,
              frequencyMhz: freq.frequencyMhz,
            );
          }
          return freq;
        }).toList();
        frequencies = [...frequencies, ...convertedIataFreqs];
      }
    }

    // Try with local code if available
    if (frequencies.isEmpty &&
        airport.localCode != null &&
        airport.localCode!.isNotEmpty) {
      // log('🔍 Trying with local code: ${airport.localCode}');
      final localFrequencies = frequencyService.getFrequenciesForAirport(
        airport.localCode!,
      );
      // log('📻 Found ${localFrequencies.length} frequencies with local code');
      if (localFrequencies.isNotEmpty) {
        final convertedLocalFreqs = localFrequencies.map((freq) {
          if (RegExp(r'^\d+$').hasMatch(freq.type)) {
            return Frequency(
              id: freq.id,
              airportIdent: freq.airportIdent,
              type: _convertFrequencyType(freq.type),
              description: freq.description,
              frequencyMhz: freq.frequencyMhz,
            );
          }
          return freq;
        }).toList();
        frequencies = [...frequencies, ...convertedLocalFreqs];
      }
    }

    // Try with GPS code if available
    if (frequencies.isEmpty &&
        airport.gpsCode != null &&
        airport.gpsCode!.isNotEmpty) {
      // log('🔍 Trying with GPS code: ${airport.gpsCode}');
      final gpsFrequencies = frequencyService.getFrequenciesForAirport(
        airport.gpsCode!,
      );
      // log('📻 Found ${gpsFrequencies.length} frequencies with GPS code');
      if (gpsFrequencies.isNotEmpty) {
        final convertedGpsFreqs = gpsFrequencies.map((freq) {
          if (RegExp(r'^\d+$').hasMatch(freq.type)) {
            return Frequency(
              id: freq.id,
              airportIdent: freq.airportIdent,
              type: _convertFrequencyType(freq.type),
              description: freq.description,
              frequencyMhz: freq.frequencyMhz,
            );
          }
          return freq;
        }).toList();
        frequencies = [...frequencies, ...convertedGpsFreqs];
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
  
  // Convert OpenAIP frequency type codes to readable types
  String _convertFrequencyType(String type) {
    // OpenAIP frequency type codes (based on common aviation frequencies)
    switch (type) {
      case '0': return 'NORCAL APP';  // Approach Control (NORCAL for San Francisco area)
      case '1': return 'AWOS';
      case '2': return 'AWIB';
      case '3': return 'AWIS';
      case '4': return 'CTAF';
      case '5': return 'MULTICOM';
      case '6': return 'UNICOM';
      case '7': return 'DELIVERY';
      case '8': return 'GROUND';
      case '9': return 'TOWER';
      case '10': return 'APPROACH';
      case '11': return 'DEPARTURE';
      case '12': return 'CENTER';
      case '13': return 'FSS';
      case '14': return 'CLEARANCE';
      case '15': return 'ATIS';        // ATIS Information
      default: return type; // Return original if not a known numeric code
    }
  }
}
