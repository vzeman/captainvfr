import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';
import '../models/navaid.dart';
import '../models/reporting_point.dart';
import 'airport_marker.dart';
import 'navaid_marker.dart';

/// An optimized marker layer that only builds markers within the visible bounds
class OptimizedMarkerLayer extends StatelessWidget {
  final List<LatLng> markerPositions;
  final Widget Function(int index, LatLng position) markerBuilder;
  final double markerWidth;
  final double markerHeight;
  final double boundsPadding; // Extra padding around visible bounds in degrees

  const OptimizedMarkerLayer({
    super.key,
    required this.markerPositions,
    required this.markerBuilder,
    this.markerWidth = 40.0,
    this.markerHeight = 40.0,
    this.boundsPadding = 0.1, // 0.1 degrees padding
  });

  @override
  Widget build(BuildContext context) {
    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final bounds = mapController.camera.visibleBounds;

    // Add padding to bounds to ensure smooth scrolling
    final paddedBounds = LatLngBounds(
      LatLng(
        bounds.southWest.latitude - boundsPadding,
        bounds.southWest.longitude - boundsPadding,
      ),
      LatLng(
        bounds.northEast.latitude + boundsPadding,
        bounds.northEast.longitude + boundsPadding,
      ),
    );

    // Filter markers to only those within padded bounds
    final visibleMarkers = <Marker>[];

    for (int i = 0; i < markerPositions.length; i++) {
      final position = markerPositions[i];

      // Check if marker is within padded bounds
      if (paddedBounds.contains(position)) {
        visibleMarkers.add(
          Marker(
            point: position,
            width: markerWidth,
            height: markerHeight,
            child: markerBuilder(i, position),
          ),
        );
      }
    }

    return MarkerLayer(markers: visibleMarkers);
  }
}

/// Optimized airport markers layer that only renders visible airports
class OptimizedAirportMarkersLayer extends StatelessWidget {
  final List<Airport> airports;
  final ValueChanged<Airport>? onAirportTap;
  final bool showLabels;
  final double markerSize;

  const OptimizedAirportMarkersLayer({
    super.key,
    required this.airports,
    this.onAirportTap,
    this.showLabels = true,
    this.markerSize = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    // Get map controller from context to access zoom
    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final currentZoom = mapController.camera.zoom;

    // Filter airports based on zoom level - more aggressive filtering
    // This reduces clutter on the map when zoomed out
    List<Airport> visibleAirports = airports;
    
    if (currentZoom < 7) {
      // Only show large airports when very zoomed out
      visibleAirports = airports
          .where((a) => a.type == 'large_airport')
          .toList();
    } else if (currentZoom < 9) {
      // Show large and medium airports (hide small airports and heliports)
      visibleAirports = airports
          .where((a) => a.type == 'large_airport' || a.type == 'medium_airport')
          .toList();
    } else if (currentZoom < 9) {
      // Show all airports except heliports
      visibleAirports = airports
          .where((a) => a.type != 'heliport')
          .toList();
    }
    // At zoom >= 11, show all airports (including small airports and heliports)

    final positions = visibleAirports.map((a) => a.position).toList();

    // Calculate base marker size with smooth interpolation based on zoom level
    double baseMarkerSize;
    if (currentZoom >= 12) {
      // Linear interpolation from zoom 12 to 15
      baseMarkerSize = 40.0 + (currentZoom - 12) * 3.0; // 40 at zoom 12, up to 49 at zoom 15
    } else if (currentZoom >= 8) {
      // Linear interpolation from zoom 8 to 12
      baseMarkerSize = 24.0 + (currentZoom - 8) * 4.0; // 24 at zoom 8, 40 at zoom 12
    } else if (currentZoom >= 5) {
      // Linear interpolation from zoom 5 to 8
      baseMarkerSize = 15.0 + (currentZoom - 5) * 3.0; // 15 at zoom 5, 24 at zoom 8
    } else {
      // Minimum size for very far zoom
      baseMarkerSize = 15.0;
    }
    
    // Clamp to reasonable bounds
    baseMarkerSize = baseMarkerSize.clamp(15.0, 50.0);

    // Find the maximum marker size to use for the layer
    double maxMarkerSize = baseMarkerSize;
    // Check if we have any large airports
    if (visibleAirports.any((a) => a.type == 'large_airport')) {
      maxMarkerSize = baseMarkerSize;
    } else if (visibleAirports.any((a) => a.type == 'medium_airport')) {
      maxMarkerSize = baseMarkerSize * 0.85;
    } else if (visibleAirports.any((a) => a.type == 'small_airport')) {
      maxMarkerSize = baseMarkerSize * 0.7;
    } else {
      // Only heliports
      maxMarkerSize = baseMarkerSize * 0.6;
    }

    return OptimizedMarkerLayer(
      markerPositions: positions,
      markerWidth: maxMarkerSize,
      markerHeight: maxMarkerSize,
      markerBuilder: (index, position) {
        final airport = visibleAirports[index];
        // Adjust marker size based on airport type
        double airportMarkerSize;
        if (airport.type == 'small_airport') {
          airportMarkerSize = baseMarkerSize * 0.7; // 30% smaller
        } else if (airport.type == 'heliport') {
          airportMarkerSize = baseMarkerSize * 0.6; // 40% smaller
        } else if (airport.type == 'medium_airport') {
          airportMarkerSize = baseMarkerSize * 0.85; // 15% smaller
        } else {
          airportMarkerSize = baseMarkerSize; // Full size for large airports
        }

        return AirportMarker(
          airport: airport,
          onTap: onAirportTap != null ? () => onAirportTap!(airport) : null,
          size: airportMarkerSize,
          showLabel: showLabels,
          isSelected: false,
          mapZoom: currentZoom,
        );
      },
    );
  }
}

/// Optimized navaid markers layer that only renders visible navaids
class OptimizedNavaidMarkersLayer extends StatelessWidget {
  final List<Navaid> navaids;
  final ValueChanged<Navaid>? onNavaidTap;
  final bool showLabels;
  final double markerSize;

  const OptimizedNavaidMarkersLayer({
    super.key,
    required this.navaids,
    this.onNavaidTap,
    this.showLabels = true,
    this.markerSize = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    // Get map controller from context to access zoom
    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final currentZoom = mapController.camera.zoom;

    // Only show navaids when zoomed in enough (same threshold as reporting points)
    if (currentZoom < 9) {
      return const SizedBox.shrink();
    }

    final positions = navaids.map((n) => n.position).toList();

    // Calculate dynamic marker size based on zoom level
    // Same sizing as reporting points: smaller when zoomed out, larger when zoomed in
    final dynamicMarkerSize = currentZoom >= 12 ? 20.0 : 14.0;

    return OptimizedMarkerLayer(
      markerPositions: positions,
      markerWidth: dynamicMarkerSize,
      markerHeight: dynamicMarkerSize,
      markerBuilder: (index, position) {
        final navaid = navaids[index];
        return NavaidMarker(
          navaid: navaid,
          onTap: onNavaidTap != null ? () => onNavaidTap!(navaid) : null,
          size: dynamicMarkerSize,
          mapZoom: currentZoom,
        );
      },
    );
  }
}

/// Optimized reporting points layer that only renders visible points
class OptimizedReportingPointsLayer extends StatelessWidget {
  final List<ReportingPoint> reportingPoints;
  final ValueChanged<ReportingPoint>? onReportingPointTap;

  const OptimizedReportingPointsLayer({
    super.key,
    required this.reportingPoints,
    this.onReportingPointTap,
  });

  @override
  Widget build(BuildContext context) {
    // Get map controller from context to access zoom
    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final currentZoom = mapController.camera.zoom;

    // Only show reporting points when zoomed in enough (same as small airports)
    if (currentZoom < 9) {
      return const SizedBox.shrink();
    }

    final positions = reportingPoints.map((p) => p.position).toList();

    // Calculate dynamic marker size based on zoom level
    final markerSize = currentZoom >= 12 ? 20.0 : 14.0;
    final showLabel = currentZoom >= 11;
    // Add extra height for label: marker + margin(2) + padding(2) + text(~14)
    final totalHeight = showLabel ? markerSize + 25.0 : markerSize;
    final markerWidth = showLabel ? 100.0 : markerSize;

    return OptimizedMarkerLayer(
      markerPositions: positions,
      markerWidth: markerWidth,
      markerHeight: totalHeight,
      boundsPadding: 0.2, // Slightly larger padding for reporting points
      markerBuilder: (index, position) {
        final point = reportingPoints[index];
        return _buildReportingPointMarker(point, currentZoom);
      },
    );
  }

  Widget _buildReportingPointMarker(ReportingPoint point, double zoom) {
    final markerSize = zoom >= 12 ? 20.0 : 14.0;
    final iconSize = zoom >= 12 ? 14.0 : 10.0;
    final fontSize = zoom >= 12 ? 11.0 : 9.0;
    final showLabel = zoom >= 11;

    return GestureDetector(
      onTap: () => onReportingPointTap?.call(point),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: markerSize,
              height: markerSize,
              decoration: BoxDecoration(
                color: _getPointColor(point.type).withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _getPointIcon(point.type),
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
            ),
            // Show name label when zoomed in
            if (showLabel)
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
                  point.name,
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
    );
  }

  Color _getPointColor(String? type) {
    if (type == null) return Colors.purple;

    switch (type.toUpperCase()) {
      case 'COMPULSORY':
      case 'MANDATORY':
        return Colors.red;
      case 'OPTIONAL':
      case 'VOLUNTARY':
        return Colors.blue;
      case 'VFR':
        return Colors.green;
      case 'IFR':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  IconData _getPointIcon(String? type) {
    if (type == null) return Icons.place;

    switch (type.toUpperCase()) {
      case 'COMPULSORY':
      case 'MANDATORY':
        return Icons.flag;
      case 'OPTIONAL':
      case 'VOLUNTARY':
        return Icons.location_on;
      case 'VFR':
        return Icons.flight;
      case 'IFR':
        return Icons.navigation;
      default:
        return Icons.place;
    }
  }
}
