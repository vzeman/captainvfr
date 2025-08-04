import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/airport.dart';
import '../models/runway.dart';
import '../models/navaid.dart';
import '../models/reporting_point.dart';
import '../models/obstacle.dart';
import '../models/hotspot.dart';
import 'airport_marker.dart';
import 'navaid_marker.dart';
import 'obstacle_marker.dart';
import 'hotspot_marker.dart';
import '../utils/geo_constants.dart';
import '../constants/map_marker_constants.dart';
import '../constants/app_theme.dart';

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
  final Map<String, List<Runway>>? airportRunways;
  final ValueChanged<Airport>? onAirportTap;
  final bool showLabels;
  final double markerSize;
  final bool showHeliports;
  final String? distanceUnit;

  const OptimizedAirportMarkersLayer({
    super.key,
    required this.airports,
    this.airportRunways,
    this.onAirportTap,
    this.showLabels = true,
    this.markerSize = 40.0,
    this.showHeliports = false,
    this.distanceUnit,
  });

  @override
  Widget build(BuildContext context) {
    // Get map controller from context to access zoom
    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final currentZoom = mapController.camera.zoom;
    final visibleBounds = mapController.camera.visibleBounds;
    
    // First, filter to only airports within the visible bounds
    List<Airport> airportsInBounds = airports.where((airport) {
      return visibleBounds.contains(airport.position);
    }).toList();

    // Then apply zoom-based filtering
    // This reduces clutter on the map when zoomed out
    List<Airport> visibleAirports = airportsInBounds;
    
    if (currentZoom < 7) {
      // Only show large airports when very zoomed out
      visibleAirports = airportsInBounds
          .where((a) => a.type == 'large_airport')
          .toList();
    } else if (currentZoom < 9) {
      // Show large and medium airports
      visibleAirports = airportsInBounds.where((a) {
        if (a.type == 'large_airport' || a.type == 'medium_airport') return true;
        // Show heliports if toggle is on, regardless of zoom
        if ((a.type == 'heliport' || a.type == 'balloonport') && showHeliports) return true;
        return false;
      }).toList();
    } else if (currentZoom < 11) {
      // Show all airports based on toggles
      visibleAirports = airportsInBounds.where((a) {
        // Always show large and medium airports
        if (a.type == 'large_airport' || a.type == 'medium_airport' || a.type == 'small_airport') return true;
        // Show heliports based on toggle (override zoom restriction)
        if ((a.type == 'heliport' || a.type == 'balloonport') && showHeliports) return true;
        // Show other types
        if (a.type == 'seaplane_base') return true;
        return false;
      }).toList();
    } else {
      // At zoom >= 11, use the pre-filtered airports from map_screen
      visibleAirports = airportsInBounds;
    }
    

    // Performance optimization: Limit number of markers to prevent slow frames
    // Since we're now only showing airports in visible bounds, we can use higher limits
    int maxMarkers;
    if (currentZoom < 8) {
      maxMarkers = 50;
    } else if (currentZoom < 10) {
      maxMarkers = 200;
    } else if (currentZoom < 12) {
      maxMarkers = 400;
    } else {
      maxMarkers = 800;
    }
    
    // When heliports are shown, increase the limit slightly
    if (showHeliports && currentZoom >= 10) {
      maxMarkers = (maxMarkers * 1.5).round();
    }
    
    // If we have too many airports, prioritize by type and distance from center
    if (visibleAirports.length > maxMarkers) {
      final mapController = MapController.maybeOf(context);
      if (mapController != null) {
        final center = mapController.camera.center;
        
        // Sort by priority and distance
        visibleAirports.sort((a, b) {
          // First, always show large and medium airports regardless of toggle
          const basePriorities = {
            'large_airport': 0,
            'medium_airport': 1,
            'small_airport': 3,
            'heliport': 4,
            'balloonport': 4,
            'seaplane_base': 3,
            'closed': 5,
          };
          
          var aPriority = basePriorities[a.type] ?? 5;
          var bPriority = basePriorities[b.type] ?? 5;
          
          // When heliports are toggled on, give them priority similar to small airports
          if (showHeliports) {
            if (a.type == 'heliport') aPriority = 2;  // Between medium and small airports
            if (b.type == 'heliport') bPriority = 2;  // Between medium and small airports
          }
          
          // Sort by distance first for same priority to ensure closest items are shown
          if (aPriority == bPriority) {
            final aDistance = Geolocator.distanceBetween(
              center.latitude, center.longitude,
              a.position.latitude, a.position.longitude,
            );
            final bDistance = Geolocator.distanceBetween(
              center.latitude, center.longitude,
              b.position.latitude, b.position.longitude,
            );
            return aDistance.compareTo(bDistance);
          }
          
          return aPriority.compareTo(bPriority);
        });
        
        visibleAirports = visibleAirports.take(maxMarkers).toList();
        
      }
    }

    final positions = visibleAirports.map((a) => a.position).toList();
    

    // Calculate base marker size with smooth interpolation based on zoom level
    // At zoom 10-13, use smaller markers to not overlap with runway visualizations
    // At higher zoom levels, scale up for better visibility
    double baseMarkerSize;
    if (currentZoom >= 14) {
      // Scale up at very high zoom for visibility
      baseMarkerSize = 16.0 + (currentZoom - 14) * 2.0; // 16 at zoom 14, up to 24 at zoom 18
    } else if (currentZoom >= 10) {
      // Smaller size when runways are visible but not too zoomed in
      baseMarkerSize = 14.0;
    } else if (currentZoom >= 8) {
      // Reduced base size at zoom 8 for better differentiation
      baseMarkerSize = 18.0 - (currentZoom - 8) * 2.0; // 18 at zoom 8, down to 14 at zoom 10
    } else if (currentZoom >= 5) {
      // Linear interpolation from zoom 5 to 8
      baseMarkerSize = 12.0 + (currentZoom - 5) * 2.0; // 12 at zoom 5, 18 at zoom 8
    } else {
      // Minimum size for very far zoom
      baseMarkerSize = 12.0;
    }
    
    // Clamp to reasonable bounds
    baseMarkerSize = baseMarkerSize.clamp(12.0, 40.0);

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
    
    // Don't increase marker bounds for runway visualization
    // Keep markers small when runways are visible to avoid overlap
    
    // Calculate marker dimensions with label space
    // Labels are shown only between zoom levels 4 and 10
    final showLabelNow = showLabels && currentZoom >= 4 && currentZoom <= 10;
    // Need to account for runway visualization size which can be larger than marker
    double maxWidth = maxMarkerSize;
    double maxHeight = maxMarkerSize;
    
    // At high zoom with runways visible, account for runway size
    if (currentZoom >= GeoConstants.minZoomForRunways) {
      // Calculate maximum runway visualization size for visible airports
      double maxRunwaySize = 0;
      for (final airport in visibleAirports) {
        final runwayData = airportRunways?[airport.icao];
        if (runwayData != null && runwayData.isNotEmpty || airport.openAIPRunways.isNotEmpty) {
          final metersPerPixel = GeoConstants.metersPerPixel(airport.position.latitude, currentZoom);
          double maxLengthM = 0;
          
          if (runwayData != null && runwayData.isNotEmpty) {
            for (final runway in runwayData) {
              final lengthM = runway.lengthFt * GeoConstants.metersPerFoot;
              if (lengthM > maxLengthM) maxLengthM = lengthM;
            }
          } else if (airport.openAIPRunways.isNotEmpty) {
            for (final runway in airport.openAIPRunways) {
              final lengthM = runway.lengthM?.toDouble() ?? 0;
              if (lengthM > maxLengthM) maxLengthM = lengthM;
            }
          }
          
          if (maxLengthM > 0) {
            final runwaySize = (maxLengthM / metersPerPixel) * 1.05;
            if (runwaySize > maxRunwaySize) maxRunwaySize = runwaySize;
          }
        }
      }
      
      if (maxRunwaySize > 0) {
        maxWidth = maxRunwaySize;
        maxHeight = maxRunwaySize;
      }
    }
    
    // Add label space
    if (showLabelNow) {
      maxHeight += 25.0; // Extra height for label
      maxWidth = maxWidth < 100.0 ? 100.0 : maxWidth; // Ensure minimum width for label
    }

    return OptimizedMarkerLayer(
      markerPositions: positions,
      markerWidth: maxWidth,
      markerHeight: maxHeight,
      markerBuilder: (index, position) {
        final airport = visibleAirports[index];
        
        // Adjust marker size based on airport type with more aggressive differentiation
        double airportMarkerSize;
        if (airport.type == 'small_airport') {
          // Much smaller for small airports, especially at lower zoom levels
          airportMarkerSize = currentZoom <= 8 ? baseMarkerSize * 0.4 : baseMarkerSize * 0.5;
        } else if (airport.type == 'heliport' || airport.type == 'balloonport') {
          airportMarkerSize = currentZoom <= 8 ? baseMarkerSize * 0.45 : baseMarkerSize * 0.55;
          // Ensure minimum size for heliports and balloonports
          airportMarkerSize = airportMarkerSize.clamp(8.0, 40.0);
        } else if (airport.type == 'seaplane_base') {
          airportMarkerSize = currentZoom <= 8 ? baseMarkerSize * 0.5 : baseMarkerSize * 0.6;
        } else if (airport.type == 'medium_airport') {
          airportMarkerSize = currentZoom <= 8 ? baseMarkerSize * 0.7 : baseMarkerSize * 0.75;
        } else {
          airportMarkerSize = baseMarkerSize; // Full size for large airports
        }
        

        return AirportMarker(
          airport: airport,
          runways: airportRunways?[airport.icao],
          onTap: onAirportTap != null ? () => onAirportTap!(airport) : null,
          size: airportMarkerSize,
          showLabel: showLabels,
          isSelected: false,
          mapZoom: currentZoom,
          distanceUnit: distanceUnit,
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
    
    // Calculate marker dimensions with label space
    // Labels are shown at zoom level 11 and above for navaids
    final showLabelNow = showLabels && currentZoom >= MapMarkerConstants.navaidLabelShowZoom;
    final labelHeight = showLabelNow ? MapMarkerConstants.navaidLabelHeight : 0;
    final markerHeight = dynamicMarkerSize + labelHeight;
    final markerWidth = showLabelNow ? MapMarkerConstants.navaidLabelWidth : dynamicMarkerSize;

    return OptimizedMarkerLayer(
      markerPositions: positions,
      markerWidth: markerWidth,
      markerHeight: markerHeight,
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
                borderRadius: AppTheme.defaultRadius,
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

/// Optimized obstacles layer that only renders visible obstacles
class OptimizedObstaclesLayer extends StatelessWidget {
  final List<Obstacle> obstacles;
  final ValueChanged<Obstacle>? onObstacleTap;

  const OptimizedObstaclesLayer({
    super.key,
    required this.obstacles,
    this.onObstacleTap,
  });

  @override
  Widget build(BuildContext context) {
    // Get map controller from context to access zoom
    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final currentZoom = mapController.camera.zoom;

    // Only show obstacles when zoomed in enough
    if (currentZoom < 9) {
      return const SizedBox.shrink();
    }

    // Filter obstacles based on zoom level and height
    List<Obstacle> visibleObstacles = obstacles;


    final positions = visibleObstacles.map((o) => o.position).toList();

    // Calculate dynamic marker size based on zoom level - same as navaid/reporting points
    final markerSize = currentZoom >= 12 ? 20.0 : 14.0;
    final showLabel = currentZoom >= 11;
    // Add extra height for label if shown
    final totalHeight = showLabel ? markerSize + 25.0 : markerSize;

    return OptimizedMarkerLayer(
      markerPositions: positions,
      markerWidth: markerSize,
      markerHeight: totalHeight,
      boundsPadding: 0.2,
      markerBuilder: (index, position) {
        final obstacle = visibleObstacles[index];
        return ObstacleMarker(
          obstacle: obstacle,
          onTap: onObstacleTap != null ? () => onObstacleTap!(obstacle) : null,
          size: markerSize,
          mapZoom: currentZoom,
        );
      },
    );
  }
}

/// Optimized hotspots layer that only renders visible hotspots
class OptimizedHotspotsLayer extends StatelessWidget {
  final List<Hotspot> hotspots;
  final ValueChanged<Hotspot>? onHotspotTap;

  const OptimizedHotspotsLayer({
    super.key,
    required this.hotspots,
    this.onHotspotTap,
  });

  @override
  Widget build(BuildContext context) {
    // Get map controller from context to access zoom
    final mapController = MapController.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    final currentZoom = mapController.camera.zoom;

    // Only show hotspots when zoomed in enough
    if (currentZoom < 8) {
      return const SizedBox.shrink();
    }

    // Filter hotspots based on reliability at lower zoom levels
    List<Hotspot> visibleHotspots = hotspots;
    
    if (currentZoom < 10) {
      // Only show high reliability hotspots when very zoomed out
      visibleHotspots = hotspots.where((h) {
        final reliability = h.reliability?.toLowerCase();
        return reliability == 'high' || reliability == '2';
      }).toList();
    }

    // Limit number of markers based on zoom
    final maxMarkers = currentZoom >= 12 ? 150 : 75;
    
    if (visibleHotspots.length > maxMarkers) {
      // Prioritize by reliability
      visibleHotspots.sort((a, b) {
        const reliabilityOrder = {'high': 0, '2': 0, 'medium': 1, '1': 1, 'low': 2, '0': 2};
        final aOrder = reliabilityOrder[a.reliability?.toLowerCase()] ?? 3;
        final bOrder = reliabilityOrder[b.reliability?.toLowerCase()] ?? 3;
        return aOrder.compareTo(bOrder);
      });
      visibleHotspots = visibleHotspots.take(maxMarkers).toList();
    }

    final positions = visibleHotspots.map((h) => h.position).toList();

    // Calculate dynamic marker size based on zoom level - same as navaid/obstacle/reporting points
    final markerSize = currentZoom >= 12 ? 20.0 : 14.0;

    return OptimizedMarkerLayer(
      markerPositions: positions,
      markerWidth: markerSize * 3, // Extra width for label
      markerHeight: markerSize + (currentZoom >= 11 ? 20 : 0), // Extra height for label
      boundsPadding: 0.2,
      markerBuilder: (index, position) {
        final hotspot = visibleHotspots[index];
        return HotspotMarker(
          hotspot: hotspot,
          onTap: onHotspotTap != null ? () => onHotspotTap!(hotspot) : null,
          size: markerSize,
          mapZoom: currentZoom,
        );
      },
    );
  }
}
