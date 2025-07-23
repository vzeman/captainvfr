import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

class LocationService {
  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  Position? _lastKnownPosition;

  /// Checks if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await _geolocator.isLocationServiceEnabled();
  }

  /// Requests location permissions from the user
  Future<LocationPermission> requestPermission() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await _geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied');
    }

    // Request background location permission for tracking (mobile only)
    if (!kIsWeb && !Platform.isMacOS && permission == LocationPermission.whileInUse) {
      // Try to get always permission for background tracking
      // Note: On iOS, this will show another permission dialog
      // On Android 10+, this requires separate permission request
      permission = await _geolocator.requestPermission();
    }

    return permission;
  }

  /// Gets the current position of the device
  Future<Position> getCurrentLocation() async {
    await requestPermission();
    final position = await _geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    _lastKnownPosition = position;
    return position;
  }

  /// Gets the last known position quickly, or current position if no last known position
  Future<Position> getLastKnownOrCurrentLocation() async {
    // If we have a last known position, return it immediately
    if (_lastKnownPosition != null) {
      // Update position in background for next time
      getCurrentLocation()
          .then((position) {
            _lastKnownPosition = position;
          })
          .catchError((_) {});
      return _lastKnownPosition!;
    }

    // Otherwise get current position
    return getCurrentLocation();
  }

  /// Gets the position stream for continuous location updates
  Stream<Position> getPositionStream() {
    return _geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // Update every 5 meters
      ),
    );
  }

  /// Calculates the distance between two coordinates in meters
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return _geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculates the bearing between two coordinates in degrees
  double calculateBearing(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return _geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
