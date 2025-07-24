import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../constants/map_constants.dart';

class MapUtils {
  MapUtils._();

  // Calculate radius in kilometers based on zoom level
  static double calculateRadiusForZoom(double zoom) {
    // Use base radius of 200km at zoom 9, halve for each zoom level increase
    final double baseRadius = 200.0; // km at zoom 9
    final int zoomDiff = zoom.round() - 9;
    return baseRadius / math.pow(2, zoomDiff);
  }

  // Get search radius in meters for waypoint drop detection
  static double getSearchRadiusForZoom(double zoom) {
    final int zoomLevel = zoom.round().clamp(5, 18);
    return MapConstants.searchRadiusLookup[zoomLevel] ?? MapConstants.baseSearchRadius;
  }

  // Calculate bounds for flight plan with padding
  static LatLngBounds calculateFlightPlanBounds(List<LatLng> waypoints) {
    if (waypoints.isEmpty) {
      throw ArgumentError('Waypoints list cannot be empty');
    }
    
    if (waypoints.length == 1) {
      // For single waypoint, create a small bounds around it
      final point = waypoints.first;
      const offset = 0.01; // ~1km at equator
      return LatLngBounds(
        LatLng(point.latitude - offset, point.longitude - offset),
        LatLng(point.latitude + offset, point.longitude + offset),
      );
    }
    
    // Calculate bounds for multiple waypoints
    double minLat = waypoints.first.latitude;
    double maxLat = waypoints.first.latitude;
    double minLng = waypoints.first.longitude;
    double maxLng = waypoints.first.longitude;
    
    for (final waypoint in waypoints) {
      minLat = math.min(minLat, waypoint.latitude);
      maxLat = math.max(maxLat, waypoint.latitude);
      minLng = math.min(minLng, waypoint.longitude);
      maxLng = math.max(maxLng, waypoint.longitude);
    }
    
    // Add padding
    final latPadding = (maxLat - minLat) * MapConstants.boundsPaddingFactor;
    final lngPadding = (maxLng - minLng) * MapConstants.boundsPaddingFactor;
    
    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  // Check if any input field has focus
  static bool hasInputFieldFocus() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    
    final context = primaryFocus.context;
    if (context == null) return false;
    
    // Check if the focused widget is a text input field
    return context.widget is EditableText;
  }

  // Format countdown for display
  static String formatCountdown(int seconds) {
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '${minutes}m';
      }
      return '${minutes}m ${remainingSeconds}s';
    }
    return '${seconds}s';
  }

  // Calculate distance between two points in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  // Check if a point is within bounds
  static bool isPointInBounds(LatLng point, LatLngBounds bounds) {
    return point.latitude >= bounds.south &&
           point.latitude <= bounds.north &&
           point.longitude >= bounds.west &&
           point.longitude <= bounds.east;
  }
}