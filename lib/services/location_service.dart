import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

class LocationService {
  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  
  /// Checks if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    if (!kIsWeb && Platform.isMacOS) {
      // On macOS, we'll simulate location services being enabled
      // since the plugin might not work the same way as on mobile
      return true;
    }
    return await _geolocator.isLocationServiceEnabled();
  }

  /// Requests location permissions from the user
  Future<LocationPermission> requestPermission() async {
    if (!kIsWeb && Platform.isMacOS) {
      // On macOS, we'll simulate having location permissions
      // since the plugin might not work the same way as on mobile
      return LocationPermission.whileInUse;
    }

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
    
    return permission;
  }

  /// Gets the current position of the device
  Future<Position> getCurrentLocation() async {
    if (!kIsWeb && Platform.isMacOS) {
      // Return a default position for macOS
      return Position(
        latitude: 37.7749,  // Default to San Francisco
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }

    await requestPermission();
    return await _geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  /// Gets the position stream for continuous location updates
  Stream<Position> getPositionStream() {
    if (!kIsWeb && Platform.isMacOS) {
      // On macOS, return a stream with a single default position
      // since we can't get real location updates
      return Stream.value(Position(
        latitude: 37.7749,  // Default to San Francisco
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ));
    }

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
