import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';
import '../models/navaid.dart';
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

    debugPrint('OptimizedMarkerLayer: ${visibleMarkers.length} of ${markerPositions.length} markers visible');

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
    final positions = airports.map((a) => a.position).toList();
    
    return OptimizedMarkerLayer(
      markerPositions: positions,
      markerWidth: markerSize,
      markerHeight: markerSize,
      markerBuilder: (index, position) {
        final airport = airports[index];
        return AirportMarker(
          airport: airport,
          onTap: onAirportTap != null ? () => onAirportTap!(airport) : null,
          size: markerSize,
          showLabel: showLabels,
          isSelected: false,
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
    final positions = navaids.map((n) => n.position).toList();
    
    return OptimizedMarkerLayer(
      markerPositions: positions,
      markerWidth: markerSize,
      markerHeight: markerSize,
      markerBuilder: (index, position) {
        final navaid = navaids[index];
        return NavaidMarker(
          navaid: navaid,
          onTap: onNavaidTap != null ? () => onNavaidTap!(navaid) : null,
          size: markerSize,
        );
      },
    );
  }
}