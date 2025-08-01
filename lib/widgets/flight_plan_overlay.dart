import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../models/flight_plan.dart';
import 'draggable_waypoint_marker.dart';
import '../constants/app_theme.dart';

class FlightPlanOverlay {
  /// Build flight path polylines for the entire plan.
  static List<Polyline> buildFlightPath(FlightPlan flightPlan) {
    if (flightPlan.waypoints.length < 2) return [];
    final points = flightPlan.waypoints.map((wp) => wp.latLng).toList();
    return [
      Polyline(points: points, strokeWidth: 5.0, color: Colors.green.shade600),
    ];
  }

  /// Build clickable flight path segments for waypoint insertion.
  static List<Polyline> buildClickableFlightPath(
    FlightPlan flightPlan,
    Function(int segmentIndex, LatLng position) onSegmentTapped,
    bool isEditMode,
  ) {
    if (flightPlan.waypoints.length < 2) {
      return [];
    }

    // Always show the flight path, make it thicker in edit mode
    final points = flightPlan.waypoints.map((wp) => wp.latLng).toList();
    return [
      Polyline(
        points: points,
        strokeWidth: isEditMode ? 7.0 : 5.0,
        color: Colors.green.shade600,
      ),
    ];
  }

  /// Build clickable markers along flight path segments for waypoint insertion.
  /// Creates a fixed set of markers that will be visible at appropriate zoom levels.
  static List<Marker> buildSegmentClickMarkers(
    FlightPlan flightPlan,
    Function(int segmentIndex, LatLng position) onSegmentTapped,
    bool isEditMode,
  ) {
    if (flightPlan.waypoints.length < 2 || !isEditMode) {
      return [];
    }

    // For simplicity, we'll create multiple markers per segment
    // and let them naturally space out based on zoom level
    // At high zoom, all markers are visible and well-spaced
    // At low zoom, markers overlap but that's okay since segments are short on screen
    
    List<Marker> markers = [];
    const int markersPerLongSegment = 5;
    
    for (int i = 0; i < flightPlan.waypoints.length - 1; i++) {
      final from = flightPlan.waypoints[i].latLng;
      final to = flightPlan.waypoints[i + 1].latLng;
      
      // Calculate segment length to determine marker count
      final distanceMeters = const Distance().as(LengthUnit.Meter, from, to);
      final distanceNm = distanceMeters / 1852.0;
      
      // Determine marker count based on distance
      // Short segments (< 10nm): 1 marker
      // Medium segments (10-50nm): 2-3 markers
      // Long segments (> 50nm): 4-5 markers
      int markerCount = 1;
      if (distanceNm > 50) {
        markerCount = markersPerLongSegment;
      } else if (distanceNm > 25) {
        markerCount = 3;
      } else if (distanceNm > 10) {
        markerCount = 2;
      }
      
      // Create evenly spaced markers along the segment
      for (int j = 0; j < markerCount; j++) {
        final t = (j + 1) / (markerCount + 1);
        final markerPos = LatLng(
          from.latitude + t * (to.latitude - from.latitude),
          from.longitude + t * (to.longitude - from.longitude),
        );
        
        markers.add(
          Marker(
            point: markerPos,
            width: 30,
            height: 30,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                onSegmentTapped(i + 1, markerPos);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green.shade600,
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
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
      Polyline(points: [a, b], strokeWidth: 6.0, color: Colors.blue),
    ];
  }

  // Build interactive waypoint markers with drag support
  static List<Marker> buildWaypointMarkers(
    FlightPlan flightPlan,
    Function(int index) onWaypointTapped,
    Function(int index, LatLng newPosition, {bool isDragging}) onWaypointMoved,
    int? selectedWaypointIndex,
    Function(bool isDragging)? onDraggingChanged,
    GlobalKey mapKey,
    bool isEditMode,
  ) {
    List<Marker> markers = [];

    for (int i = 0; i < flightPlan.waypoints.length; i++) {
      final waypoint = flightPlan.waypoints[i];

      markers.add(
        Marker(
          point: waypoint.latLng,
          width: 30,
          height: 30,
          child: DraggableWaypointMarker(
            waypointIndex: i,
            waypoint: waypoint,
            onWaypointTapped: onWaypointTapped,
            onWaypointMoved: onWaypointMoved,
            isSelected: selectedWaypointIndex == i,
            onDraggingChanged: onDraggingChanged,
            mapKey: mapKey,
            isEditMode: isEditMode,
          ),
        ),
      );
    }

    return markers;
  }

  // Build waypoint name labels
  static List<Marker> buildWaypointLabels(
    FlightPlan flightPlan,
    int? selectedWaypointIndex,
  ) {
    List<Marker> markers = [];

    for (int i = 0; i < flightPlan.waypoints.length; i++) {
      final waypoint = flightPlan.waypoints[i];
      final isSelected = selectedWaypointIndex == i;

      markers.add(
        Marker(
          point: waypoint.latLng,
          width: 80,
          height: 20,
          child: Transform.translate(
            offset: const Offset(20, -5), // Position to the right of the marker
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.yellow.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: AppTheme.smallRadius,
                border: Border.all(
                  color: isSelected ? Colors.orange : Colors.black54,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                waypoint.name ?? 'WP${i + 1}',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.black87,
                  fontSize: isSelected ? 10 : 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
  static List<Marker> buildSegmentLabels(
    FlightPlan flightPlan,
    BuildContext context,
  ) {
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

      // Build label parts
      List<String> labelParts = [];
      labelParts.add('${distance.toStringAsFixed(1)}nm');
      labelParts.add('${bearing.toStringAsFixed(0)}°');

      if (segment.flightTime > 0) {
        final minutes = segment.flightTime.round();
        if (minutes < 60) {
          labelParts.add('${minutes}m');
        } else {
          final hours = minutes ~/ 60;
          final mins = minutes % 60;
          labelParts.add('${hours}h${mins > 0 ? mins.toString() : ''}');
        }
      }

      final labelText = labelParts.join(' ');

      // Calculate dynamic width based on text length
      final labelWidth = labelText.length * 5.0 + 10.0;

      markers.add(
        Marker(
          point: midpoint,
          width: labelWidth,
          height: 16,
          child: _SegmentLabel(
            from: from.latLng,
            to: to.latLng,
            labelWidth: labelWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: AppTheme.smallRadius,
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.7),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                labelText,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }
}

// Widget that shows/hides label based on rendered segment length
class _SegmentLabel extends StatelessWidget {
  final LatLng from;
  final LatLng to;
  final double labelWidth;
  final Widget child;

  const _SegmentLabel({
    required this.from,
    required this.to,
    required this.labelWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final mapCamera = MapCamera.maybeOf(context);
    if (mapCamera == null) return const SizedBox.shrink();

    try {
      // Try to get screen points - this will depend on flutter_map version
      // For flutter_map 8.x, we need to use a different approach
      // Since direct coordinate conversion isn't working, we'll use a simpler heuristic

      // Calculate approximate pixel distance based on zoom level
      // At higher zoom levels, segments appear longer on screen
      final zoom = mapCamera.zoom;
      final distance =
          const Distance().as(LengthUnit.Meter, from, to) /
          1852.0; // Convert meters to nautical miles

      // Rough approximation: at zoom 10, 1 NM ≈ 20 pixels
      // This scales exponentially with zoom level
      final pixelsPerNM = 20 * math.pow(2, zoom - 10);
      final estimatedPixelLength = distance * pixelsPerNM;

      // Hide label if estimated pixel length is less than 2x label width
      if (estimatedPixelLength < labelWidth * 2) {
        return const SizedBox.shrink();
      }

      return child;
    } catch (e) {
      // If there's any error, show the label by default
      return child;
    }
  }
}

