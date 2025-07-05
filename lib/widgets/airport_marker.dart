import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/airport.dart';

class AirportMarker extends StatelessWidget {
  final Airport airport;
  final VoidCallback? onTap;
  final double size;
  final bool showLabel;
  final bool isSelected;

  const AirportMarker({
    super.key,
    required this.airport,
    this.onTap,
    this.size = 24.0,
    this.showLabel = true,
    this.isSelected = false,
  });
  


  @override
  Widget build(BuildContext context) {
    final icon = _getAirportIcon(airport.type);
    final color = _getAirportColor(airport.type);
    final borderColor = isSelected ? Colors.amber : color;
    final borderWidth = isSelected ? 3.0 : 2.0;
    
    // Removed debug prints for performance
    
    // The visual size of the marker
    const visualSize = 32.0;
    
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
                  border: Border.all(
                    color: borderColor,
                    width: borderWidth,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x33000000),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: visualSize * 0.6,
                  color: color,
                ),
              ),
            ),
            
            // Weather indicator dot (top-right corner)
            if (airport.hasWeatherData) Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: weatherDotSize,
                height: weatherDotSize,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
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
        return Icons.adjust; // Circular target-like icon representing helipad
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

  const AirportMarkersLayer({
    super.key,
    required this.airports,
    this.onAirportTap,
    this.showLabels = true,
    this.markerSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed size for markers
    const markerSize = 40.0;
    
    final markers = airports
        .map(
          (airport) => Marker(
            width: markerSize,
            height: markerSize,
            point: airport.position,
            child: AirportMarker(
              airport: airport,
              onTap: onAirportTap != null ? () => onAirportTap!(airport) : null,
              size: markerSize,
              showLabel: showLabels,
              isSelected: false, // Default to false, can be set based on selection state
            ),
          ),
        )
        .toList();

    return MarkerLayer(markers: markers);
  }
}
