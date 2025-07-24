import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' as math;
import '../models/airport.dart';
import '../models/runway.dart';
import '../models/openaip_runway.dart';
import 'runway_painter.dart';
import '../utils/magnetic_declination_simple.dart';

class AirportMarker extends StatelessWidget {
  final Airport airport;
  final List<Runway>? runways;
  final VoidCallback? onTap;
  final double size;
  final bool showLabel;
  final bool isSelected;
  final double mapZoom;

  const AirportMarker({
    super.key,
    required this.airport,
    this.runways,
    this.onTap,
    this.size = 24.0,
    this.showLabel = true,
    this.isSelected = false,
    this.mapZoom = 10,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _getAirportIcon(airport.type);
    final color = _getAirportColor(airport.type);
    final borderColor = isSelected ? Colors.amber : color;
    final borderWidth = isSelected ? 3.0 : 2.0;


    // The visual size of the marker based on zoom
    // Use the size parameter which is already adjusted for zoom
    // Make heliport markers slightly larger to accommodate their special icons
    final visualSize = airport.type == 'heliport' ? size * 1.2 : size;

    // Weather indicator dot size
    final weatherDotSize = visualSize * 0.3;

    // Calculate runway visualization size based on actual runway dimensions
    double runwayVisualizationSize = 0.0;
    if (mapZoom >= 5) {
      // Calculate meters per pixel at this zoom and latitude
      const double earthCircumference = 40075016.686;
      final double metersPerPixel = earthCircumference * math.cos(airport.position.latitude * math.pi / 180) / math.pow(2, mapZoom + 8);
      
      // Find the longest runway
      double maxLengthM = 0;
      if (runways != null && runways!.isNotEmpty) {
        for (final runway in runways!) {
          final lengthM = runway.lengthFt * 0.3048; // Convert feet to meters
          if (lengthM > maxLengthM) maxLengthM = lengthM;
        }
      } else if (airport.openAIPRunways.isNotEmpty) {
        // For OpenAIP runways
        for (final runway in airport.openAIPRunways) {
          final lengthM = runway.lengthM?.toDouble();
          if (lengthM != null && lengthM > maxLengthM) maxLengthM = lengthM;
        }
      }
      
      // Set size based on longest runway, with minimum size
      if (maxLengthM > 0) {
        runwayVisualizationSize = math.max(visualSize * 2, (maxLengthM / metersPerPixel) * 1.2);
      } else {
        runwayVisualizationSize = visualSize * 3.5; // Default size
      }
    }

    return GestureDetector(
      onTap: () {
        onTap?.call();
      },
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Runway visualization (behind the marker)
            if (mapZoom >= 5)
              if (runways != null && runways!.isNotEmpty)
                Positioned(
                  child: RunwayVisualization(
                    runways: runways!,
                    zoom: mapZoom,
                    size: runwayVisualizationSize,
                    runwayColor: isSelected ? Colors.amber : Colors.black87,
                    latitude: airport.position.latitude,
                    longitude: airport.position.longitude,
                  ),
                )
              else if (airport.openAIPRunways.isNotEmpty)
                Positioned(
                  child: _buildRunwayVisualizationFromOpenAIP(
                    airport.openAIPRunways,
                    runwayVisualizationSize,
                    isSelected,
                  ),
                ),
            
            // Main marker
            OverflowBox(
              // Allow the marker to visually overflow its bounds
              maxWidth: visualSize,
              maxHeight: visualSize,
              child: Container(
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.amber.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x33000000),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: airport.type == 'heliport' 
                    ? Center(
                        child: Transform.translate(
                          offset: Offset(visualSize * 0.02, visualSize * 0.02), // Slight offset to compensate for icon's visual weight
                          child: FaIcon(FontAwesomeIcons.helicopter, size: visualSize * 0.45, color: color),
                        ),
                      )
                    : airport.type == 'balloonport'
                    ? Center(
                        child: Icon(Icons.air, size: visualSize * 0.5, color: color),
                      )
                    : Icon(icon, size: visualSize * 0.6, color: color),
              ),
            ),

            // Weather indicator dot (top-right corner)
            if (airport.hasWeatherData)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: weatherDotSize,
                  height: weatherDotSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Get appropriate icon based on airport type
  IconData _getAirportIcon(String type) {
    switch (type) {
      case 'heliport':
        return Icons.circle; // Circle represents helipad landing area
      case 'balloonport':
        return Icons.air; // Hot air balloon icon for balloonports
      case 'seaplane_base':
        return Icons.airplanemode_active;
      case 'large_airport':
        return Icons.flight;
      case 'medium_airport':
        return Icons.flight_takeoff;
      case 'small_airport':
      default:
        return Icons.flight_land;
    }
  }

  // Build runway visualization from OpenAIP runway data
  Widget _buildRunwayVisualizationFromOpenAIP(
    List<OpenAIPRunway> openAIPRunways,
    double size,
    bool isSelected,
  ) {
    // Convert OpenAIP runways to simple visualization
    return CustomPaint(
      size: Size(size, size),
      painter: SimpleRunwayPainter(
        runways: openAIPRunways,
        runwayColor: isSelected ? Colors.amber : Colors.black87,
        strokeWidth: 1.0, // Base width, will be scaled based on actual runway width
        zoom: mapZoom,
        latitude: airport.position.latitude,
        longitude: airport.position.longitude,
      ),
    );
  }

  // Get color based on flight category or airport type
  Color _getAirportColor(String type) {
    // If we have weather data, use the flight category color
    final category = airport.flightCategory;
    if (category != null) {
      switch (category) {
        case 'VFR':
          return Colors.green;
        case 'MVFR':
          return Colors.blue;
        case 'IFR':
          return Colors.red;
        case 'LIFR':
          return Colors.purple;
        default:
          break;
      }
    }

    // Fall back to airport type if no weather data
    switch (type) {
      case 'large_airport':
        return Colors.blue;
      case 'medium_airport':
        return Colors.green;
      case 'heliport':
        return Colors.purple;
      case 'seaplane_base':
        return Colors.blue[300]!;
      case 'small_airport':
      default:
        return Colors.grey;
    }
  }
}

// Airport marker layer for the map
class AirportMarkersLayer extends StatelessWidget {
  final List<Airport> airports;
  final Map<String, List<Runway>>? airportRunways;
  final ValueChanged<Airport>? onAirportTap;
  final bool showLabels;
  final double markerSize;
  final double mapZoom;

  const AirportMarkersLayer({
    super.key,
    required this.airports,
    this.airportRunways,
    this.onAirportTap,
    this.showLabels = true,
    this.markerSize = 24.0,
    this.mapZoom = 10,
  });

  @override
  Widget build(BuildContext context) {
    // Base marker size based on zoom
    final baseMarkerSize = mapZoom >= 12 ? 40.0 : 28.0;

    final markers = airports.map((airport) {
      // Small airports and balloonports get 25% smaller markers (75% of base size)
      final airportMarkerSize = (airport.type == 'small_airport' || airport.type == 'balloonport')
          ? baseMarkerSize * 0.75
          : baseMarkerSize;

      // Get runway data for this airport
      final runways = airportRunways?[airport.icao];

      // Calculate actual runway bounds
      double markerBounds = airportMarkerSize;
      if (mapZoom >= 5) {
        // Calculate meters per pixel at this zoom and latitude
        const double earthCircumference = 40075016.686;
        final double metersPerPixel = earthCircumference * math.cos(airport.position.latitude * math.pi / 180) / math.pow(2, mapZoom + 8);
        
        // Find the longest runway
        double maxLengthM = 0;
        final airportRunwayData = airportRunways?[airport.icao];
        if (airportRunwayData != null && airportRunwayData.isNotEmpty) {
          for (final runway in airportRunwayData) {
            final lengthM = runway.lengthFt * 0.3048;
            if (lengthM > maxLengthM) maxLengthM = lengthM;
          }
        }
        
        if (maxLengthM > 0) {
          markerBounds = math.max(airportMarkerSize, (maxLengthM / metersPerPixel) * 1.2);
        }
      }

      return Marker(
        width: markerBounds,
        height: markerBounds,
        point: airport.position,
        child: AirportMarker(
          airport: airport,
          runways: runways,
          onTap: onAirportTap != null ? () => onAirportTap!(airport) : null,
          size: airportMarkerSize,
          showLabel: showLabels,
          isSelected:
              false, // Default to false, can be set based on selection state
          mapZoom: mapZoom,
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}

// Simple runway painter for OpenAIP runway data
class SimpleRunwayPainter extends CustomPainter {
  final List<OpenAIPRunway> runways;
  final Color runwayColor;
  final double strokeWidth;
  final double zoom;
  final double? latitude;
  final double? longitude;

  SimpleRunwayPainter({
    required this.runways,
    required this.runwayColor,
    required this.strokeWidth,
    this.zoom = 13,
    this.latitude,
    this.longitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (runways.isEmpty) return;

    final paint = Paint()
      ..color = runwayColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Calculate accurate scale using Web Mercator projection formula
    final lat = latitude ?? 45.0; // Default to 45° if no data
    
    // Standard Web Mercator formula: meters per pixel at given latitude and zoom
    const double earthCircumference = 40075016.686; // meters at equator
    final double metersPerPixel = earthCircumference * math.cos(lat * math.pi / 180) / math.pow(2, zoom + 8);
    
    // Track drawn runways to avoid duplicates
    final drawnRunways = <String>{};

    for (final runway in runways) {
      // Extract runway data
      final designator = runway.designator;
      final lengthM = runway.lengthM;
      final widthM = runway.widthM;
      
      // Extract numeric part from designator
      final match = RegExp(r'^(\d{1,2})').firstMatch(designator);
      if (match == null) continue;
      
      final runwayNumber = int.tryParse(match.group(1)!);
      if (runwayNumber == null) continue;
      
      final magneticHeading = runwayNumber * 10; // Convert to degrees
      
      // Convert magnetic heading to true heading using magnetic declination
      final lat = latitude ?? 45.0;
      final lon = longitude ?? 0.0;
      final declination = MagneticDeclinationSimple.calculate(lat, lon);
      // Apply declination: True = Magnetic + Declination
      final heading = MagneticDeclinationSimple.magneticToTrue(magneticHeading.toDouble(), declination);
      
      // Create unique key including length to allow different length runways at same heading
      final runwayKey = '$heading-${lengthM ?? 'unknown'}';
      
      // Skip if we've already drawn this exact runway
      if (drawnRunways.contains(runwayKey)) continue;
      drawnRunways.add(runwayKey);

      // Calculate actual runway length in pixels
      // Default to 1000m if no length data available
      final actualLengthM = lengthM ?? 1000;
      final runwayLengthPx = actualLengthM / metersPerPixel;
      
      // No capping - we want exact representation
      final visualLength = runwayLengthPx;

      // Convert heading to radians
      final radians = heading * (math.pi / 180);
      
      // Calculate runway endpoints
      // Rotate by -90 degrees because 0 degrees is north, not east
      final adjustedRadians = radians - (math.pi / 2);
      
      final dx = math.cos(adjustedRadians) * visualLength / 2;
      final dy = math.sin(adjustedRadians) * visualLength / 2;

      final start = Offset(center.dx - dx, center.dy - dy);
      final end = Offset(center.dx + dx, center.dy + dy);

      // Calculate runway width in pixels
      double runwayStrokeWidth = strokeWidth;
      if (widthM != null && widthM > 0) {
        // Convert runway width to pixels using same scale
        final widthPx = widthM / metersPerPixel;
        // Ensure minimum visibility
        runwayStrokeWidth = math.max(1.0, widthPx);
      }
      
      final runwayPaint = Paint()
        ..color = runwayColor
        ..strokeWidth = runwayStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt; // Use butt cap for exact length

      // Draw runway line
      canvas.drawLine(start, end, runwayPaint);

      // Draw runway end markers
      final markerLength = visualLength * 0.1;
      final perpRadians = adjustedRadians + (math.pi / 2);
      final mdx = math.cos(perpRadians) * markerLength / 2;
      final mdy = math.sin(perpRadians) * markerLength / 2;

      // Start end marker
      canvas.drawLine(
        Offset(start.dx - mdx, start.dy - mdy),
        Offset(start.dx + mdx, start.dy + mdy),
        paint,
      );

      // End marker
      canvas.drawLine(
        Offset(end.dx - mdx, end.dy - mdy),
        Offset(end.dx + mdx, end.dy + mdy),
        paint,
      );
      
      // Add length label for longer runways at higher zoom levels
      if (zoom >= 14 && lengthM != null && lengthM >= 1000) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: lengthM >= 1000 ? '${(lengthM / 1000.0).toStringAsFixed(1)}km' : '${lengthM}m',
            style: TextStyle(
              color: runwayColor.withAlpha(200),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        // Position text along the runway
        final midpoint = Offset(
          (start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2,
        );
        
        // Rotate text to align with runway
        canvas.save();
        canvas.translate(midpoint.dx, midpoint.dy);
        
        // Adjust rotation so text is always readable (not upside down)
        var textAngle = adjustedRadians;
        if (textAngle > math.pi / 2 || textAngle < -math.pi / 2) {
          textAngle += math.pi;
        }
        
        canvas.rotate(textAngle);
        textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(SimpleRunwayPainter oldDelegate) {
    return oldDelegate.runways != runways ||
        oldDelegate.runwayColor != runwayColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
