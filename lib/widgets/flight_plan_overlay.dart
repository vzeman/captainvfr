import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/flight_plan.dart';

class FlightPlanOverlay {
  /// Build flight path polylines for the entire plan.
  static List<Polyline> buildFlightPath(FlightPlan flightPlan) {
    if (flightPlan.waypoints.length < 2) return [];
    final points = flightPlan.waypoints.map((wp) => wp.latLng).toList();
    return [
      Polyline(
        points: points,
        strokeWidth: 3.0,
        color: Colors.grey.shade400,
      ),
    ];
  }

  /// Highlight the next segment in the plan based on current position.
  static List<Polyline> buildNextSegment(
    FlightPlan flightPlan,
    LatLng? currentPos,
  ) {
    if (currentPos == null || flightPlan.waypoints.length < 2) return [];
    // Find first waypoint not yet reached (simple distance check)
    final waypoints = flightPlan.waypoints;
    int nextIdx = waypoints.indexWhere((wp) {
      final dist = Distance().as(LengthUnit.Meter, currentPos, wp.latLng);
      return dist > 100; // threshold of 100m
    });
    if (nextIdx <= 0) return [];
    final a = waypoints[nextIdx - 1].latLng;
    final b = waypoints[nextIdx].latLng;
    return [
      Polyline(points: [a, b], strokeWidth: 4.0, color: Colors.blueAccent),
    ];
  }

  // Build interactive waypoint markers
  static List<Marker> buildWaypointMarkers(
    FlightPlan flightPlan,
    Function(int index) onWaypointTapped,
  ) {
    List<Marker> markers = [];

    for (int i = 0; i < flightPlan.waypoints.length; i++) {
      final waypoint = flightPlan.waypoints[i];
      
      markers.add(
        Marker(
          point: waypoint.latLng,
          width: 20,
          height: 20,
          child: GestureDetector(
            onTap: () => onWaypointTapped(i),
            child: Container(
              decoration: BoxDecoration(
                color: _getWaypointColor(waypoint.type),
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
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // Build waypoint name labels
  static List<Marker> buildWaypointLabels(FlightPlan flightPlan) {
    List<Marker> markers = [];

    for (int i = 0; i < flightPlan.waypoints.length; i++) {
      final waypoint = flightPlan.waypoints[i];
      
      markers.add(
        Marker(
          point: waypoint.latLng,
          width: 100,
          height: 25,
          child: Transform.translate(
            offset: const Offset(0, -35),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                waypoint.name ?? 'WP${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // Build segment information labels (distance, heading, time)
  static List<Marker> buildSegmentLabels(FlightPlan flightPlan) {
    List<Marker> markers = [];

    if (flightPlan.waypoints.length < 2) return markers;

    for (int i = 0; i < flightPlan.waypoints.length - 1; i++) {
      final from = flightPlan.waypoints[i];
      final to = flightPlan.waypoints[i + 1];
      
      // Calculate midpoint
      final lat = (from.latitude + to.latitude) / 2;
      final lng = (from.longitude + to.longitude) / 2;
      final midpoint = LatLng(lat, lng);

      // Calculate segment info
      final distance = from.distanceTo(to);
      final bearing = from.bearingTo(to);
      final segment = flightPlan.segments[i];
      
      String labelText = '${distance.toStringAsFixed(1)} NM\n${bearing.toStringAsFixed(0)}°';
      if (segment.flightTime > 0) {
        final minutes = segment.flightTime.round();
        labelText += '\n${minutes}min';
      }

      markers.add(
        Marker(
          point: midpoint,
          width: 80,
          height: 60,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue, width: 1),
            ),
            child: Text(
              labelText,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // Get waypoint color based on type
  static Color _getWaypointColor(WaypointType type) {
    switch (type) {
      case WaypointType.airport:
        return Colors.green;
      case WaypointType.navaid:
        return Colors.purple;
      case WaypointType.fix:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
