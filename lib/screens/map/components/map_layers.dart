import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/airport.dart';
import '../../../models/runway.dart';
import '../../../models/navaid.dart';
import '../../../models/obstacle.dart';
import '../../../models/hotspot.dart';
import '../../../models/airspace.dart';
import '../../../models/reporting_point.dart';
import '../../../services/flight_plan_service.dart';
import '../../../services/offline_map_service.dart';
import '../../../services/offline_tile_provider.dart';
import '../../../services/spatial_airspace_service.dart';
import '../../../widgets/optimized_marker_layer.dart';
import '../../../widgets/metar_overlay.dart';
import '../../../widgets/flight_plan_overlay.dart';
import '../../../widgets/optimized_spatial_airspaces_overlay.dart';

class MapLayersBuilder extends StatelessWidget {
  final bool servicesInitialized;
  final OfflineMapService? offlineMapService;
  final SpatialAirspaceService spatialAirspaceService;
  final bool showAirspaces;
  final bool showHeliports;
  final bool showNavaids;
  final bool showMetar;
  final bool showObstacles;
  final bool showHotspots;
  final List<Airport> airports;
  final Map<String, List<Runway>> airportRunways;
  final List<Navaid> navaids;
  final List<ReportingPoint> reportingPoints;
  final List<Obstacle> obstacles;
  final List<Hotspot> hotspots;
  final Position? currentPosition;
  final Function(Airspace) onAirspaceTap;
  final Function(ReportingPoint) onReportingPointTap;
  final Function(Obstacle) onObstacleTap;
  final Function(Hotspot) onHotspotTap;
  final Function(Airport) onAirportTap;
  final Function(Navaid) onNavaidTap;
  final Function(int, LatLng) onFlightPathSegmentTapped;
  final Widget? currentPositionMarker;
  final List<Widget>? additionalLayers;

  const MapLayersBuilder({
    super.key,
    required this.servicesInitialized,
    required this.offlineMapService,
    required this.spatialAirspaceService,
    required this.showAirspaces,
    required this.showHeliports,
    required this.showNavaids,
    required this.showMetar,
    required this.showObstacles,
    required this.showHotspots,
    required this.airports,
    required this.airportRunways,
    required this.navaids,
    required this.reportingPoints,
    required this.obstacles,
    required this.hotspots,
    required this.currentPosition,
    required this.onAirspaceTap,
    required this.onReportingPointTap,
    required this.onObstacleTap,
    required this.onHotspotTap,
    required this.onAirportTap,
    required this.onNavaidTap,
    required this.onFlightPathSegmentTapped,
    this.currentPositionMarker,
    this.additionalLayers,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.captainvfr',
          tileProvider: servicesInitialized && offlineMapService != null
              ? OfflineTileProvider(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  offlineMapService: offlineMapService!,
                  userAgentPackageName: 'com.example.captainvfr',
                )
              : null,
        ),
        
        // Airspaces overlay
        if (showAirspaces)
          OptimizedSpatialAirspacesOverlay(
            spatialService: spatialAirspaceService,
            showAirspacesLayer: showAirspaces,
            onAirspaceTap: onAirspaceTap,
            currentAltitude: currentPosition?.altitude ?? 0,
          ),
        
        // Reporting points overlay
        if (showAirspaces && reportingPoints.isNotEmpty)
          OptimizedReportingPointsLayer(
            reportingPoints: reportingPoints,
            onReportingPointTap: onReportingPointTap,
          ),
        
        // Obstacles overlay
        if (showObstacles && obstacles.isNotEmpty)
          OptimizedObstaclesLayer(
            obstacles: obstacles,
            onObstacleTap: onObstacleTap,
          ),
        
        // Hotspots overlay
        if (showHotspots && hotspots.isNotEmpty)
          OptimizedHotspotsLayer(
            hotspots: hotspots,
            onHotspotTap: onHotspotTap,
          ),
        
        // Airport markers
        OptimizedAirportMarkersLayer(
          airports: airports.where((airport) {
            // Filter heliports and balloonports based on toggle
            if ((airport.type == 'heliport' || airport.type == 'balloonport') && !showHeliports) {
              return false;
            }
            return true;
          }).toList(),
          airportRunways: airportRunways,
          onAirportTap: onAirportTap,
          showHeliports: showHeliports,
        ),
        
        // Navaid markers
        if (showNavaids && navaids.isNotEmpty)
          OptimizedNavaidMarkersLayer(
            navaids: navaids,
            onNavaidTap: onNavaidTap,
          ),
        
        // METAR overlay
        if (showMetar)
          MetarOverlay(
            airports: airports,
            showMetarLayer: showMetar,
            onAirportTap: onAirportTap,
          ),
        
        // Flight plan overlay
        Consumer<FlightPlanService>(
          builder: (context, flightPlanService, child) {
            final flightPlan = flightPlanService.currentFlightPlan;
            if (flightPlan == null ||
                flightPlan.waypoints.isEmpty ||
                !flightPlanService.isFlightPlanVisible) {
              return const SizedBox.shrink();
            }

            return Stack(
              children: [
                // Flight plan paths
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: flightPlan.waypoints.map((w) => w.position).toList(),
                      color: Colors.blue,
                      strokeWidth: 3.0,
                    ),
                  ],
                ),
                // Waypoint markers would go here
              ],
            );
          },
        ),
        
        // Current position marker
        if (currentPositionMarker != null) currentPositionMarker!,
        
        // Additional layers
        if (additionalLayers != null) ...additionalLayers!,
      ],
    );
  }
}