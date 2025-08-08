import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;
import '../models/airport.dart';
import '../models/runway.dart';
import 'unified_runway_painter.dart';
import '../utils/geo_constants.dart';

class AirportMarker extends StatelessWidget {
  final Airport airport;
  final List<Runway>? runways;
  final VoidCallback? onTap;
  final double size;
  final bool showLabel;
  final bool isSelected;
  final double mapZoom;
  final String? distanceUnit;

  const AirportMarker({
    super.key,
    required this.airport,
    this.runways,
    this.onTap,
    this.size = 24.0,
    this.showLabel = true,
    this.isSelected = false,
    this.mapZoom = 10,
    this.distanceUnit,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _getAirportIcon(airport.type);
    final color = _getAirportColor(airport.type);
    final borderColor = isSelected ? Colors.amber : color;
    // Adjust border width based on zoom level - thinner at lower zoom levels
    final borderWidth = isSelected ? (mapZoom >= 10 ? 2.0 : 1.5) : (mapZoom >= 10 ? 1.5 : 1.0);


    // The visual size of the marker based on zoom
    // Ensure minimum size to prevent NaN errors
    final visualSize = size > 0 ? size : 24.0;

    // Calculate runway visualization size based on actual runway dimensions
    double runwayVisualizationSize = 0.0;
    if (mapZoom >= GeoConstants.minZoomForRunways) {
      // Calculate meters per pixel at this zoom and latitude
      final double metersPerPixel = GeoConstants.metersPerPixel(airport.position.latitude, mapZoom);
      
      // Find the longest runway
      double maxLengthM = 0;
      if (runways != null && runways!.isNotEmpty) {
        for (final runway in runways!) {
          final lengthM = runway.lengthFt * GeoConstants.metersPerFoot; // Convert feet to meters
          if (lengthM > maxLengthM) maxLengthM = lengthM;
        }
      } else if (airport.openAIPRunways.isNotEmpty) {
        // For OpenAIP runways
        for (final runway in airport.openAIPRunways) {
          final lengthM = runway.lengthM?.toDouble();
          if (lengthM != null && lengthM > maxLengthM) maxLengthM = lengthM;
        }
      }
      
      // Set size based on longest runway
      if (maxLengthM > 0 && metersPerPixel > 0) {
        // Calculate pixel size for runway visualization
        // Add small buffer (1.05) for visual clarity
        final calculatedSize = (maxLengthM / metersPerPixel) * 1.05;
        
        // Ensure the size is valid (not NaN or infinite)
        if (calculatedSize.isFinite && calculatedSize > 0) {
          // Ensure minimum size for visibility
          // At zoom 10+, use actual calculated size to show realistic runway proportions
          // At lower zooms, use a reasonable size for visibility
          runwayVisualizationSize = mapZoom >= 10 ? calculatedSize : visualSize * 2.0;
        } else {
          runwayVisualizationSize = visualSize * 3.5; // Default size
        }
      } else {
        runwayVisualizationSize = visualSize * 3.5; // Default size
      }
    }

    // Determine if label should be shown based on zoom
    // Show labels only between zoom levels 4 and 10 AND only if airport has ICAO code
    final shouldShowLabel = showLabel && mapZoom >= 4 && mapZoom <= 10 && airport.icao.isNotEmpty;
    final fontSize = mapZoom >= 8 ? 11.0 : 9.0;

    return GestureDetector(
      onTap: () {
        onTap?.call();
      },
      child: FittedBox(
        fit: BoxFit.contain,
        child: IntrinsicHeight(
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // Stack for marker and runway visualization
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                // Runway visualization (behind the marker)
                if (mapZoom >= GeoConstants.minZoomForRunways && runwayVisualizationSize > 0)
                  if (runways != null && runways!.isNotEmpty)
                    UnifiedRunwayVisualization(
                      runways: runways!,
                      airportIdent: airport.icao,
                      zoom: mapZoom,
                      size: runwayVisualizationSize,
                      runwayColor: isSelected ? Colors.amber : Colors.black87,
                      latitude: airport.position.latitude,
                      longitude: airport.position.longitude,
                      distanceUnit: distanceUnit,
                    )
                  else if (airport.openAIPRunways.isNotEmpty)
                    UnifiedRunwayVisualization(
                      openAIPRunways: airport.openAIPRunways,
                      airportIdent: airport.icao,
                      zoom: mapZoom,
                      size: runwayVisualizationSize,
                      runwayColor: isSelected ? Colors.amber : Colors.black87,
                      latitude: airport.position.latitude,
                      longitude: airport.position.longitude,
                      distanceUnit: distanceUnit,
                    ),
                
                // Main marker
                Container(
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
                            child: Container(
                              width: visualSize * 0.6,
                              height: visualSize * 0.6,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  'H',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: visualSize * 0.3,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : airport.type == 'balloonport'
                        ? Center(
                            child: Icon(Icons.air, size: visualSize * 0.5, color: color),
                          )
                        : Icon(icon, size: visualSize * 0.6, color: color),
                ),
              ],
            ),
            // Show label when zoomed in enough
            if (shouldShowLabel)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  airport.icao.isNotEmpty ? airport.icao : airport.name,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ],
            ),
          ),
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
  final String? distanceUnit;

  const AirportMarkersLayer({
    super.key,
    required this.airports,
    this.airportRunways,
    this.onAirportTap,
    this.showLabels = true,
    this.markerSize = 24.0,
    this.mapZoom = 10,
    this.distanceUnit,
  });

  @override
  Widget build(BuildContext context) {
    // Base marker size based on zoom
    // At zoom 10+, use smaller markers (10px) to not overlap runway visualizations
    // At lower zooms, use larger markers (24px) for better visibility
    final baseMarkerSize = mapZoom >= 10 ? 16.0 : 30.0;

    final markers = airports.map((airport) {
      // Small airports and balloonports get 25% smaller markers (75% of base size)
      final airportMarkerSize = (airport.type == 'small_airport' || airport.type == 'balloonport')
          ? baseMarkerSize * 0.75
          : baseMarkerSize;

      // Get runway data for this airport
      final runways = airportRunways?[airport.icao];

      // Calculate actual runway bounds
      double markerBounds = airportMarkerSize;
      if (mapZoom >= GeoConstants.minZoomForRunways) {
        // Calculate meters per pixel at this zoom and latitude
        final double metersPerPixel = GeoConstants.metersPerPixel(airport.position.latitude, mapZoom);
        
        // Find the longest runway
        double maxLengthM = 0;
        final airportRunwayData = airportRunways?[airport.icao];
        if (airportRunwayData != null && airportRunwayData.isNotEmpty) {
          for (final runway in airportRunwayData) {
            final lengthM = runway.lengthFt * GeoConstants.metersPerFoot;
            if (lengthM > maxLengthM) maxLengthM = lengthM;
          }
        }
        
        if (maxLengthM > 0) {
          // Use actual runway length with small buffer
          markerBounds = math.max(airportMarkerSize, (maxLengthM / metersPerPixel) * 1.05);
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
          distanceUnit: distanceUnit,
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}