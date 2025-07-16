import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/airport.dart';

class AirportMarker extends StatelessWidget {
  final Airport airport;
  final VoidCallback? onTap;
  final double size;
  final bool showLabel;
  final bool isSelected;
  final double mapZoom;

  const AirportMarker({
    super.key,
    required this.airport,
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

    // Removed debug prints for performance

    // The visual size of the marker based on zoom
    // Use the size parameter which is already adjusted for zoom
    // Make heliport and balloonport markers slightly larger to accommodate their special icons
    final visualSize = (airport.type == 'heliport' || airport.type == 'balloonport') ? size * 1.2 : size;

    // Weather indicator dot size
    final weatherDotSize = visualSize * 0.3;

    return GestureDetector(
      onTap: () {
        onTap?.call();
      },
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
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
                      ? Colors.amber.withAlpha(51)
                      : Colors.white.withAlpha(230),
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
  final ValueChanged<Airport>? onAirportTap;
  final bool showLabels;
  final double markerSize;
  final double mapZoom;

  const AirportMarkersLayer({
    super.key,
    required this.airports,
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
      // Small airports get 25% smaller markers (75% of base size)
      final airportMarkerSize = airport.type == 'small_airport'
          ? baseMarkerSize * 0.75
          : baseMarkerSize;

      return Marker(
        width: airportMarkerSize,
        height: airportMarkerSize,
        point: airport.position,
        child: AirportMarker(
          airport: airport,
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
