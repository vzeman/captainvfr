import '../../../models/flight_point.dart';
import '../../../models/flight_segment.dart';
import '../../../models/moving_segment.dart';
import '../calculations/flight_calculator.dart';
import '../models/flight_constants.dart';
import '../models/flight_state.dart';

/// Manages flight segment tracking and detection
class SegmentTracker {
  final FlightState flightState;
  
  SegmentTracker({required this.flightState});
  
  /// Process a new flight point and update segments
  void processFlightPoint(FlightPoint point) {
    _updateMovingState(point);
    _checkForNewSegment(point);
  }
  
  /// Update moving state based on speed
  void _updateMovingState(FlightPoint point) {
    final wasMoving = flightState.isCurrentlyMoving;
    final isMovingNow = FlightCalculator.isMoving(point.speed);
    
    if (!wasMoving && isMovingNow) {
      // Started moving
      _startMovingSegment(point);
    } else if (wasMoving && !isMovingNow) {
      // Stopped moving
      _endMovingSegment(point);
    } else if (isMovingNow) {
      // Continue moving - update segment data
      _updateCurrentMovingSegment(point);
    }
  }
  
  /// Start a new moving segment
  void _startMovingSegment(FlightPoint point) {
    flightState.setCurrentlyMoving(true);
    flightState.setCurrentMovingSegmentStart(point.timestamp);
    flightState.setCurrentMovingSegmentStartPoint(point);
    flightState.clearCurrentMovingSegmentData();
    
    // Set global moving started time if not set
    if (flightState.movingStartedZulu == null) {
      flightState.setMovingStarted(point.timestamp);
    }
  }
  
  /// End current moving segment
  void _endMovingSegment(FlightPoint endPoint) {
    if (flightState.currentMovingSegmentStart != null && 
        flightState.currentMovingSegmentStartPoint != null) {
      // Calculate averages
      final avgSpeed = flightState.currentMovingSegmentSpeeds.isNotEmpty
          ? flightState.currentMovingSegmentSpeeds.reduce((a, b) => a + b) / 
            flightState.currentMovingSegmentSpeeds.length
          : 0.0;
      
      final avgHeading = flightState.currentMovingSegmentHeadings.isNotEmpty
          ? flightState.currentMovingSegmentHeadings.reduce((a, b) => a + b) / 
            flightState.currentMovingSegmentHeadings.length
          : 0.0;
      
      final avgAltitude = flightState.currentMovingSegmentAltitudes.isNotEmpty
          ? flightState.currentMovingSegmentAltitudes.reduce((a, b) => a + b) / 
            flightState.currentMovingSegmentAltitudes.length
          : 0.0;
      
      // Calculate altitude values
      final startAlt = flightState.currentMovingSegmentStartPoint!.altitude;
      final endAlt = endPoint.altitude;
      final maxAlt = flightState.currentMovingSegmentAltitudes.isNotEmpty
          ? flightState.currentMovingSegmentAltitudes.reduce((a, b) => a > b ? a : b)
          : endAlt;
      final minAlt = flightState.currentMovingSegmentAltitudes.isNotEmpty
          ? flightState.currentMovingSegmentAltitudes.reduce((a, b) => a < b ? a : b)
          : endAlt;
      
      // Create moving segment
      final segment = MovingSegment(
        start: flightState.currentMovingSegmentStart!,
        end: endPoint.timestamp,
        duration: endPoint.timestamp.difference(flightState.currentMovingSegmentStart!),
        distance: flightState.currentMovingSegmentDistance,
        averageSpeed: avgSpeed,
        averageHeading: avgHeading,
        startAltitude: startAlt,
        endAltitude: endAlt,
        averageAltitude: avgAltitude,
        maxAltitude: maxAlt,
        minAltitude: minAlt,
      );
      
      flightState.addMovingSegment(segment);
    }
    
    // Add pause point
    flightState.addPausePoint(endPoint);
    
    // Reset current segment tracking
    flightState.setCurrentlyMoving(false);
    flightState.setCurrentMovingSegmentStart(null);
    flightState.setCurrentMovingSegmentStartPoint(null);
    flightState.clearCurrentMovingSegmentData();
    
    // Update global moving stopped time
    flightState.setMovingStopped(endPoint.timestamp);
  }
  
  /// Update current moving segment with new data
  void _updateCurrentMovingSegment(FlightPoint point) {
    if (flightState.currentMovingSegmentStartPoint != null) {
      // Update distance
      final segmentDistance = FlightCalculator.calculateDistance(
        flightState.currentMovingSegmentStartPoint!,
        point,
      );
      flightState.updateCurrentMovingSegmentDistance(segmentDistance);
      
      // Add data points
      flightState.addCurrentMovingSegmentSpeed(point.speed);
      flightState.addCurrentMovingSegmentHeading(point.heading);
      flightState.addCurrentMovingSegmentAltitude(point.altitude);
    }
  }
  
  /// Check if a new flight segment should be created
  void _checkForNewSegment(FlightPoint point) {
    final lastPoint = flightState.lastSegmentPoint;
    
    if (lastPoint == null) {
      // First segment point
      flightState.setLastSegmentPoint(point);
      return;
    }
    
    // Check conditions for new segment
    final distance = FlightCalculator.calculateDistance(lastPoint, point);
    final headingChanged = FlightCalculator.isSignificantHeadingChange(
      lastPoint.heading,
      point.heading,
    );
    final altitudeChanged = FlightCalculator.isSignificantAltitudeChange(
      lastPoint.altitude,
      point.altitude,
    );
    
    if (distance >= FlightConstants.minSegmentDistance || 
        headingChanged || 
        altitudeChanged) {
      // Create new segment
      final segmentPoints = [lastPoint, point];
      final segment = FlightSegment(
        startTime: lastPoint.timestamp,
        endTime: point.timestamp,
        points: segmentPoints,
        distance: distance,
        averageSpeed: (lastPoint.speed + point.speed) / 2,
        averageHeading: point.heading,
        startAltitude: lastPoint.altitude,
        endAltitude: point.altitude,
        averageAltitude: (lastPoint.altitude + point.altitude) / 2,
        maxAltitude: lastPoint.altitude > point.altitude ? lastPoint.altitude : point.altitude,
        minAltitude: lastPoint.altitude < point.altitude ? lastPoint.altitude : point.altitude,
      );
      
      flightState.addFlightSegment(segment);
      flightState.setLastSegmentPoint(point);
    }
  }
  
  /// Complete any open segments when tracking stops
  void completeOpenSegments(FlightPoint? finalPoint) {
    if (flightState.isCurrentlyMoving && finalPoint != null) {
      _endMovingSegment(finalPoint);
    }
  }
}