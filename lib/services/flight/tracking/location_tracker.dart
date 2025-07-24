import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../models/flight_point.dart';

/// Manages location tracking for flights
class LocationTracker {
  StreamSubscription<Position>? _positionSubscription;
  final Function(FlightPoint) onLocationUpdate;
  final Function(String) onError;
  
  LocationTracker({
    required this.onLocationUpdate,
    required this.onError,
  });
  
  /// Start tracking location
  Future<void> startTracking() async {
    // Check and request permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError('Location services are disabled');
      return;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onError('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      onError('Location permissions are permanently denied');
      return;
    }
    
    // Configure location settings for aviation use
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, // Update every 5 meters
    );
    
    // Start position stream
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        // Create flight point from position
        final flightPoint = FlightPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          speed: position.speed,
          heading: position.heading,
          timestamp: DateTime.now(),
          accuracy: position.accuracy,
          pressure: 0.0, // Will be filled by barometer service
        );
        
        onLocationUpdate(flightPoint);
      },
      onError: (error) {
        onError('Location tracking error: $error');
      },
    );
  }
  
  /// Stop tracking location
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }
  
  /// Check if currently tracking
  bool get isTracking => _positionSubscription != null;
  
  /// Dispose of resources
  void dispose() {
    stopTracking();
  }
}