import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../models/airport.dart';
import '../constants/app_theme.dart';
import '../constants/map_marker_constants.dart';
import '../utils/geo_constants.dart';

class MetarOverlay extends StatelessWidget {
  final List<Airport> airports;
  final bool showMetarLayer;
  final Function(Airport)? onAirportTap;

  const MetarOverlay({
    super.key,
    required this.airports,
    required this.showMetarLayer,
    this.onAirportTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!showMetarLayer) return const SizedBox.shrink();

    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final bounds = mapController.camera.visibleBounds;
    final zoom = mapController.camera.zoom;
    
    // Add padding to bounds
    final paddedBounds = LatLngBounds(
      LatLng(bounds.southWest.latitude - 0.1, bounds.southWest.longitude - 0.1),
      LatLng(bounds.northEast.latitude + 0.1, bounds.northEast.longitude + 0.1),
    );

    final visibleAirportsWithMetar = airports
        .where(
          (airport) =>
              airport.rawMetar != null &&
              paddedBounds.contains(airport.position),
        )
        .toList();

    return MarkerLayer(
      markers: [
        ...visibleAirportsWithMetar.map(
          (airport) => _buildMetarMarker(airport, zoom),
        ),
      ],
    );
  }

  /// Calculate font size based on zoom level
  double _getFontSize(double zoom) {
    if (zoom >= 12) return 11.0;  // Close zoom
    if (zoom >= 10) return 10.0;  // Medium zoom
    if (zoom >= 8) return 9.0;    // Far zoom
    return 8.0;                    // Very far zoom
  }

  Marker _buildMetarMarker(Airport airport, double zoom) {
    final windData = _parseWindFromMetar(airport.rawMetar!);
    
    final fontSize = _getFontSize(zoom);
    
    // Calculate icon container size based on zoom
    final iconContainerSize = _getIconContainerSize(zoom);
    final iconSize = _getIconSize(zoom);

    // Only show wind data if available and zoom is sufficient
    if (windData == null || zoom < MapMarkerConstants.windInfoShowZoom) {
      return Marker(
        point: airport.position,
        width: 0,
        height: 0,
        child: const SizedBox.shrink(),
      );
    }

    // Calculate dynamic positioning based on zoom and airport type
    final airportMarkerSize = _getAirportMarkerSize(airport, zoom);
    final runwayVisualizationSize = _getRunwayVisualizationSize(airport, zoom);
    
    // Calculate base offset based on the larger of airport marker or runway visualization
    final baseOffset = math.max(airportMarkerSize, runwayVisualizationSize) / 2;
    
    // Add significant extra offset for lower zoom levels to ensure clear separation
    double zoomAdjustment;
    if (zoom < 8) {
      zoomAdjustment = 75.0;  // Very far zoom - need lots of space
    } else if (zoom < 10) {
      zoomAdjustment = 60.0;  // Far zoom - need good separation
    } else {
      zoomAdjustment = 35.0;  // Close zoom - smaller offset needed
    }
    
    // Dynamic bottom padding: account for marker size + zoom adjustment + buffer
    final dynamicBottomPadding = baseOffset + zoomAdjustment + 20;
    
    // Dynamic height to accommodate the positioning
    final dynamicHeight = dynamicBottomPadding + 50;

    return Marker(
      point: airport.position,
      width: 120, // Width for wind label
      height: dynamicHeight,
      child: GestureDetector(
        onTap: () => onAirportTap?.call(airport),
        child: Align(
          alignment: Alignment.bottomCenter, // Align to bottom so it appears above marker
          child: Padding(
            padding: EdgeInsets.only(bottom: dynamicBottomPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // Wind direction arrow - scales with zoom
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: (windData.direction + 180) * math.pi / 180, // Add 180 to point where wind is going
                    child: Icon(
                      Icons.navigation, // Better arrow icon for direction
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            SizedBox(width: 4),
            // Wind speed text - smaller label
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: fontSize * 0.3,
                vertical: fontSize * 0.1,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Text(
                '${windData.speed}${windData.gust != null ? 'G${windData.gust}' : ''}kt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ],
          ),
        ),
        ),
      ),
    );
  }
  
  /// Calculate icon container size based on zoom level
  double _getIconContainerSize(double zoom) {
    if (zoom >= 12) return 24.0;  // Close zoom
    if (zoom >= 10) return 20.0;  // Medium zoom
    if (zoom >= 8) return 16.0;   // Far zoom
    return 14.0;                   // Very far zoom
  }
  
  /// Calculate icon size based on zoom level
  double _getIconSize(double zoom) {
    if (zoom >= 12) return 16.0;  // Close zoom
    if (zoom >= 10) return 14.0;  // Medium zoom
    if (zoom >= 8) return 11.0;   // Far zoom
    return 9.0;                    // Very far zoom
  }


  /// Calculate airport marker size based on type and zoom
  double _getAirportMarkerSize(Airport airport, double zoom) {
    // Match the actual airport marker sizes from AirportMarkersLayer
    final baseSize = zoom >= 10 ? 16.0 : 30.0;
    
    // Adjust for airport type
    if (airport.type == 'small_airport' || airport.type == 'balloonport') {
      return baseSize * 0.75;
    } else if (airport.type == 'heliport') {
      return baseSize * 0.8;
    } else if (airport.type == 'medium_airport') {
      return baseSize * 0.85;
    }
    return baseSize;
  }
  
  /// Calculate runway visualization size if applicable
  double _getRunwayVisualizationSize(Airport airport, double zoom) {
    if (zoom < GeoConstants.minZoomForRunways) {
      return 0;
    }
    
    // This is a simplified calculation - in reality it depends on runway length
    // For now, return a reasonable estimate
    final baseSize = _getAirportMarkerSize(airport, zoom);
    return baseSize * 3.5; // Default runway visualization multiplier
  }

  // Parse wind data from METAR
  WindData? _parseWindFromMetar(String metar) {
    // Updated regex pattern to handle more formats
    final windRegex = RegExp(
      r'(?:METAR\s+)?[A-Z]{4}\s+\d{6}Z?\s+(?:AUTO\s+)?(\d{3}|VRB)(\d{2,3})(?:G(\d{2,3}))?KT',
    );
    final match = windRegex.firstMatch(metar);

    if (match != null) {
      final directionStr = match.group(1);
      final speedStr = match.group(2);
      final gustStr = match.group(3);

      // Handle variable wind direction
      final direction = directionStr == 'VRB' ? 0 : int.tryParse(directionStr!) ?? 0;
      final speed = int.tryParse(speedStr!) ?? 0;
      final gust = gustStr != null ? int.tryParse(gustStr) : null;

      return WindData(
        direction: direction.toDouble(),
        speed: speed,
        gust: gust,
      );
    }
    return null;
  }
}

class WindData {
  final double direction;
  final int speed;
  final int? gust;

  WindData({
    required this.direction,
    required this.speed,
    this.gust,
  });
}

