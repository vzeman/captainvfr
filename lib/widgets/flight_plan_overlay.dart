import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/flight_plan.dart';

class FlightPlanOverlay {
  static List<Marker> buildWaypointMarkers(
    FlightPlan flightPlan,
    Function(int) onWaypointTap,
  ) {
    final markers = <Marker>[];

    for (int i = 0; i < flightPlan.waypoints.length; i++) {
      final waypoint = flightPlan.waypoints[i];
      final isFirst = i == 0;
      final isLast = i == flightPlan.waypoints.length - 1;

      markers.add(
        Marker(
          point: waypoint.latLng,
          width: 20,
          height: 20,
          child: GestureDetector(
            onTap: () => onWaypointTap(i),
            child: Container(
              decoration: BoxDecoration(
                color: isFirst
                    ? Colors.green
                    : isLast
                        ? Colors.red
                        : Colors.blue,
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

  static List<Marker> buildWaypointLabels(FlightPlan flightPlan) {
    // Labels removed during flight planning - information is available in flight plan details
    return [];
  }

  static List<Polyline> buildFlightPath(FlightPlan flightPlan) {
    if (flightPlan.waypoints.length < 2) return [];

    final points = flightPlan.waypoints.map((w) => w.latLng).toList();

    return [
      Polyline(
        points: points,
        strokeWidth: 3.0,
        color: Colors.blue,
      ),
    ];
  }

  static List<Marker> buildSegmentLabels(FlightPlan flightPlan) {
    // Segment labels removed during flight planning - information is available in flight plan details
    return [];
  }
}
