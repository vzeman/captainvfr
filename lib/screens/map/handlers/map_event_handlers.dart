import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/airport.dart';
import '../../../models/navaid.dart';
import '../../../models/airspace.dart';
import '../../../models/obstacle.dart';
import '../../../models/hotspot.dart';
import '../../../models/reporting_point.dart';
import '../../../models/flight_plan.dart';
import '../../../services/flight_plan_service.dart';
import '../../../services/spatial_airspace_service.dart';

/// Handles all map interaction events
class MapEventHandlers {
  final BuildContext context;
  final FlightPlanService flightPlanService;
  final SpatialAirspaceService spatialAirspaceService;
  final bool showFlightPlanning;
  final bool showAirspaces;
  final Function(List<Airspace>, LatLng) onAirspacesAtPoint;
  final Function(Airport) onAirportSelected;
  final Function(Navaid) onNavaidSelected;
  final Function(Obstacle) onObstacleSelected;
  final Function(Hotspot) onHotspotSelected;
  final Function(ReportingPoint) onReportingPointSelected;
  final Function(Airspace) onAirspaceSelected;
  final Function(int, LatLng) onFlightPathSegmentTapped;
  final Function(LatLng, String?, {bool isNearby}) onWaypointDropped;

  // Flag to prevent airspace popup when waypoint is tapped
  bool _waypointJustTapped = false;

  MapEventHandlers({
    required this.context,
    required this.flightPlanService,
    required this.spatialAirspaceService,
    required this.showFlightPlanning,
    required this.showAirspaces,
    required this.onAirspacesAtPoint,
    required this.onAirportSelected,
    required this.onNavaidSelected,
    required this.onObstacleSelected,
    required this.onHotspotSelected,
    required this.onReportingPointSelected,
    required this.onAirspaceSelected,
    required this.onFlightPathSegmentTapped,
    required this.onWaypointDropped,
  });

  void setWaypointJustTapped(bool value) {
    _waypointJustTapped = value;
  }

  /// Handle map tap events
  Future<void> handleMapTap(TapPosition tapPosition, LatLng point) async {
    // If a waypoint was just tapped, ignore this map tap
    if (_waypointJustTapped) {
      return;
    }

    // If in flight planning mode and panel is visible, add waypoint
    // Only allow adding waypoints when the flight planning panel is shown and in edit mode
    if (flightPlanService.isPlanning && showFlightPlanning) {
      flightPlanService.addWaypoint(point);
      return;
    }

    // Check if any airspaces contain the tapped point
    if (showAirspaces) {
      // Use spatial service to find airspaces at the tapped point
      final tappedAirspaces = await spatialAirspaceService.getAirspacesAtPoint(point);

      if (tappedAirspaces.isNotEmpty) {
        onAirspacesAtPoint(tappedAirspaces, point);
        return;
      }
    }

    // Otherwise, close any open dialogs or menus
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Handle long press on map
  Future<void> handleMapLongPress(TapPosition tapPosition, LatLng point) async {
    // Add logic for long press if needed
    // For example, showing context menu or adding special waypoints
  }

  /// Handle waypoint tap
  void handleWaypointTap(int index) {
    setWaypointJustTapped(true);
    
    // Reset flag after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      setWaypointJustTapped(false);
    });
    
    // Handle waypoint selection logic
    if (flightPlanService.isPlanning) {
      // TODO: Implement selectWaypoint in FlightPlanService
      // flightPlanService.selectWaypoint(index);
    }
  }

  /// Handle waypoint drag start
  void handleWaypointDragStart(int index) {
    if (flightPlanService.isPlanning) {
      // TODO: Implement startDraggingWaypoint in FlightPlanService
      // flightPlanService.startDraggingWaypoint(index);
    }
  }

  /// Handle waypoint drag update
  void handleWaypointDragUpdate(int index, LatLng newPosition) {
    if (flightPlanService.isPlanning) {
      // TODO: Check isDraggingWaypoint property
      flightPlanService.updateWaypointPosition(index, newPosition);
    }
  }

  /// Handle waypoint drag end
  void handleWaypointDragEnd(int index, LatLng finalPosition) {
    if (flightPlanService.isPlanning) {
      // TODO: Implement endDraggingWaypoint in FlightPlanService
      // flightPlanService.endDraggingWaypoint();
      
      // Check if dropped near an airport/navaid
      onWaypointDropped(finalPosition, null);
    }
  }

  /// Handle flight path segment tap for waypoint insertion
  void handleFlightPathSegmentTap(int segmentIndex, LatLng position) {
    if (!flightPlanService.isPlanning || !showFlightPlanning) {
      return;
    }

    // Insert waypoint at the specified position in the flight path
    flightPlanService.insertWaypointAt(segmentIndex, position);
    
    // Notify about the segment tap
    onFlightPathSegmentTapped(segmentIndex, position);
  }
}