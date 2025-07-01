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
          width: 40,
          height: 40,
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
    final labels = <Marker>[];

    for (int i = 0; i < flightPlan.waypoints.length; i++) {
      final waypoint = flightPlan.waypoints[i];

      labels.add(
        Marker(
          point: waypoint.latLng,
          width: 200,
          height: 50,
          child: Transform.translate(
            offset: const Offset(0, -35),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    waypoint.name ?? 'WP${i + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${waypoint.altitude.toStringAsFixed(0)} ft',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return labels;
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
    final labels = <Marker>[];
    final segments = flightPlan.segments;

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final midPoint = _calculateMidpoint(segment.from.latLng, segment.to.latLng);

      labels.add(
        Marker(
          point: midPoint,
          width: 120,
          height: 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.yellow.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${segment.distance.toStringAsFixed(1)} NM',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${segment.bearing.toStringAsFixed(0)}°',
                      style: const TextStyle(fontSize: 8),
                    ),
                    if (segment.flightTime > 0) ...[
                      const Text(' • ', style: TextStyle(fontSize: 8)),
                      Text(
                        '${segment.flightTime.toStringAsFixed(0)}m',
                        style: const TextStyle(fontSize: 8),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return labels;
  }

  static LatLng _calculateMidpoint(LatLng point1, LatLng point2) {
    return LatLng(
      (point1.latitude + point2.latitude) / 2,
      (point1.longitude + point2.longitude) / 2,
    );
  }
}
