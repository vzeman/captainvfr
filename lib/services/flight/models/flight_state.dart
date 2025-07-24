import 'package:flutter/foundation.dart';
import '../../../models/flight_point.dart';
import '../../../models/flight_segment.dart';
import '../../../models/moving_segment.dart';
import '../../../models/aircraft.dart';

/// Manages the state of a flight recording
class FlightState extends ChangeNotifier {
  // Flight path data
  final List<FlightPoint> _flightPath = [];
  final List<FlightSegment> _flightSegments = [];
  
  // Time tracking
  DateTime? _recordingStartedZulu;
  DateTime? _recordingStoppedZulu;
  DateTime? _movingStartedZulu;
  DateTime? _movingStoppedZulu;
  final List<MovingSegment> _movingSegments = [];
  bool _isCurrentlyMoving = false;
  DateTime? _currentMovingSegmentStart;
  double _currentMovingSegmentDistance = 0.0;
  final List<double> _currentMovingSegmentSpeeds = [];
  final List<double> _currentMovingSegmentHeadings = [];
  final List<double> _currentMovingSegmentAltitudes = [];
  FlightPoint? _currentMovingSegmentStartPoint;
  final List<FlightPoint> _pausePoints = [];
  
  // Flight tracking state
  bool _isTracking = false;
  DateTime? _startTime;
  double _totalDistance = 0.0;
  double _averageSpeed = 0.0;
  
  // Flight segment tracking
  FlightPoint? _lastSegmentPoint;
  
  // Selected aircraft
  Aircraft? _selectedAircraft;
  
  // Current sensor values
  double? _currentHeading;
  double? _currentBaroAltitude;
  double _currentPressure = 1013.25;
  
  // Getters
  List<FlightPoint> get flightPath => List.unmodifiable(_flightPath);
  List<FlightSegment> get flightSegments => List.unmodifiable(_flightSegments);
  bool get isTracking => _isTracking;
  DateTime? get startTime => _startTime;
  double get totalDistance => _totalDistance;
  double get averageSpeed => _averageSpeed;
  Aircraft? get selectedAircraft => _selectedAircraft;
  double? get currentHeading => _currentHeading;
  double? get currentBaroAltitude => _currentBaroAltitude;
  double get currentPressure => _currentPressure;
  
  // Time tracking getters
  DateTime? get recordingStartedZulu => _recordingStartedZulu;
  DateTime? get recordingStoppedZulu => _recordingStoppedZulu;
  DateTime? get movingStartedZulu => _movingStartedZulu;
  DateTime? get movingStoppedZulu => _movingStoppedZulu;
  List<MovingSegment> get movingSegments => List.unmodifiable(_movingSegments);
  bool get isCurrentlyMoving => _isCurrentlyMoving;
  List<FlightPoint> get pausePoints => List.unmodifiable(_pausePoints);
  
  // Methods to update state
  void setTracking(bool tracking) {
    _isTracking = tracking;
    notifyListeners();
  }
  
  void setStartTime(DateTime? time) {
    _startTime = time;
    notifyListeners();
  }
  
  void setRecordingStarted(DateTime time) {
    _recordingStartedZulu = time;
    notifyListeners();
  }
  
  void setRecordingStopped(DateTime time) {
    _recordingStoppedZulu = time;
    notifyListeners();
  }
  
  void setMovingStarted(DateTime time) {
    _movingStartedZulu = time;
    notifyListeners();
  }
  
  void setMovingStopped(DateTime time) {
    _movingStoppedZulu = time;
    notifyListeners();
  }
  
  void setCurrentlyMoving(bool moving) {
    _isCurrentlyMoving = moving;
    notifyListeners();
  }
  
  void setCurrentMovingSegmentStart(DateTime? time) {
    _currentMovingSegmentStart = time;
  }
  
  void setCurrentMovingSegmentStartPoint(FlightPoint? point) {
    _currentMovingSegmentStartPoint = point;
  }
  
  void updateCurrentMovingSegmentDistance(double distance) {
    _currentMovingSegmentDistance = distance;
  }
  
  void addCurrentMovingSegmentSpeed(double speed) {
    _currentMovingSegmentSpeeds.add(speed);
  }
  
  void addCurrentMovingSegmentHeading(double heading) {
    _currentMovingSegmentHeadings.add(heading);
  }
  
  void addCurrentMovingSegmentAltitude(double altitude) {
    _currentMovingSegmentAltitudes.add(altitude);
  }
  
  void clearCurrentMovingSegmentData() {
    _currentMovingSegmentDistance = 0.0;
    _currentMovingSegmentSpeeds.clear();
    _currentMovingSegmentHeadings.clear();
    _currentMovingSegmentAltitudes.clear();
  }
  
  void setAircraft(Aircraft? aircraft) {
    _selectedAircraft = aircraft;
    notifyListeners();
  }
  
  void setCurrentHeading(double? heading) {
    _currentHeading = heading;
    notifyListeners();
  }
  
  void setCurrentBaroAltitude(double? altitude) {
    _currentBaroAltitude = altitude;
    notifyListeners();
  }
  
  void setCurrentPressure(double pressure) {
    _currentPressure = pressure;
    notifyListeners();
  }
  
  void updateTotalDistance(double distance) {
    _totalDistance = distance;
    notifyListeners();
  }
  
  void updateAverageSpeed(double speed) {
    _averageSpeed = speed;
    notifyListeners();
  }
  
  void setLastSegmentPoint(FlightPoint? point) {
    _lastSegmentPoint = point;
  }
  
  FlightPoint? get lastSegmentPoint => _lastSegmentPoint;
  DateTime? get currentMovingSegmentStart => _currentMovingSegmentStart;
  double get currentMovingSegmentDistance => _currentMovingSegmentDistance;
  List<double> get currentMovingSegmentSpeeds => _currentMovingSegmentSpeeds;
  List<double> get currentMovingSegmentHeadings => _currentMovingSegmentHeadings;
  List<double> get currentMovingSegmentAltitudes => _currentMovingSegmentAltitudes;
  FlightPoint? get currentMovingSegmentStartPoint => _currentMovingSegmentStartPoint;
  
  // Flight path management
  void addFlightPoint(FlightPoint point) {
    _flightPath.add(point);
  }
  
  void clearFlightPath() {
    _flightPath.clear();
  }
  
  // Flight segments management
  void addFlightSegment(FlightSegment segment) {
    _flightSegments.add(segment);
  }
  
  void clearFlightSegments() {
    _flightSegments.clear();
  }
  
  // Moving segments management
  void addMovingSegment(MovingSegment segment) {
    _movingSegments.add(segment);
  }
  
  void clearMovingSegments() {
    _movingSegments.clear();
  }
  
  // Pause points management
  void addPausePoint(FlightPoint point) {
    _pausePoints.add(point);
  }
  
  void clearPausePoints() {
    _pausePoints.clear();
  }
  
  // Reset all state
  void reset() {
    _flightPath.clear();
    _flightSegments.clear();
    _movingSegments.clear();
    _pausePoints.clear();
    _isTracking = false;
    _startTime = null;
    _recordingStartedZulu = null;
    _recordingStoppedZulu = null;
    _movingStartedZulu = null;
    _movingStoppedZulu = null;
    _isCurrentlyMoving = false;
    _currentMovingSegmentStart = null;
    _currentMovingSegmentDistance = 0.0;
    _currentMovingSegmentSpeeds.clear();
    _currentMovingSegmentHeadings.clear();
    _currentMovingSegmentAltitudes.clear();
    _currentMovingSegmentStartPoint = null;
    _lastSegmentPoint = null;
    _totalDistance = 0.0;
    _averageSpeed = 0.0;
    notifyListeners();
  }
}