import '../../../models/flight.dart';
import '../../flight_storage_service.dart';
import '../helpers/analytics_wrapper.dart';

/// Manages flight history storage and retrieval
class FlightHistoryManager {
  List<Flight> _flights = [];
  
  List<Flight> get flights => List.unmodifiable(_flights);
  
  /// Initialize and load saved flights
  Future<void> initialize() async {
    await FlightStorageService.init();
    await loadFlights();
  }
  
  /// Load saved flights from storage
  Future<void> loadFlights() async {
    try {
      _flights = await FlightStorageService.getAllFlights();
      // Sort by date, newest first
      _flights.sort((a, b) => b.startTime.compareTo(a.startTime));
    } catch (e) {
      // Handle error
      _flights = [];
    }
  }
  
  /// Save a completed flight
  Future<void> saveFlight(Flight flight) async {
    try {
      await FlightStorageService.saveFlight(flight);
      
      // Track analytics
      AnalyticsWrapper.track(
        'flight_completed',
        properties: {
          'duration_minutes': flight.duration.inMinutes,
          'distance_km': (flight.distanceTraveled / 1000).toStringAsFixed(1),
          'max_altitude_ft': (flight.maxAltitude * 3.28084).toStringAsFixed(0),
          'waypoints': flight.path.length,
        },
      );
      
      // Reload flights to include the new one
      await loadFlights();
    } catch (e) {
      throw Exception('Failed to save flight: $e');
    }
  }
  
  /// Delete a flight
  Future<void> deleteFlight(int index) async {
    if (index < 0 || index >= _flights.length) return;
    
    try {
      final flight = _flights[index];
      await FlightStorageService.deleteFlight(flight.id);
      
      // Track analytics
      AnalyticsWrapper.track('flight_deleted');
      
      // Reload flights
      await loadFlights();
    } catch (e) {
      throw Exception('Failed to delete flight: $e');
    }
  }
  
  /// Export flight data
  Future<String> exportFlight(Flight flight, {String format = 'gpx'}) async {
    try {
      switch (format.toLowerCase()) {
        case 'gpx':
          return _exportAsGPX(flight);
        case 'kml':
          return _exportAsKML(flight);
        default:
          throw Exception('Unsupported export format: $format');
      }
    } catch (e) {
      throw Exception('Failed to export flight: $e');
    }
  }
  
  /// Export flight as GPX
  String _exportAsGPX(Flight flight) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="CaptainVFR">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>Flight ${flight.startTime.toIso8601String()}</name>');
    buffer.writeln('    <time>${flight.startTime.toIso8601String()}</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>Flight Track</name>');
    buffer.writeln('    <trkseg>');
    
    for (final point in flight.path) {
      buffer.writeln('      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      buffer.writeln('        <ele>${point.altitude}</ele>');
      buffer.writeln('        <time>${point.timestamp.toIso8601String()}</time>');
      buffer.writeln('        <speed>${point.speed}</speed>');
      buffer.writeln('        <course>${point.heading}</course>');
      buffer.writeln('      </trkpt>');
    }
    
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');
    
    return buffer.toString();
  }
  
  /// Export flight as KML
  String _exportAsKML(Flight flight) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln('    <name>Flight ${flight.startTime.toIso8601String()}</name>');
    buffer.writeln('    <Placemark>');
    buffer.writeln('      <name>Flight Track</name>');
    buffer.writeln('      <LineString>');
    buffer.writeln('        <extrude>1</extrude>');
    buffer.writeln('        <tessellate>1</tessellate>');
    buffer.writeln('        <altitudeMode>absolute</altitudeMode>');
    buffer.writeln('        <coordinates>');
    
    for (final point in flight.path) {
      buffer.writeln('          ${point.longitude},${point.latitude},${point.altitude}');
    }
    
    buffer.writeln('        </coordinates>');
    buffer.writeln('      </LineString>');
    buffer.writeln('    </Placemark>');
    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');
    
    return buffer.toString();
  }
}