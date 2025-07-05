import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/airspace.dart';
import '../services/openaip_service.dart';
import '../utils/airspace_utils.dart';
import 'dart:math' as math;

class AirspaceFlightInfo extends StatefulWidget {
  final LatLng currentPosition;
  final double currentAltitude;
  final double currentHeading;
  final double currentSpeed; // in m/s
  final OpenAIPService openAIPService;
  final Function(Airspace)? onAirspaceSelected;

  const AirspaceFlightInfo({
    super.key,
    required this.currentPosition,
    required this.currentAltitude,
    required this.currentHeading,
    required this.currentSpeed,
    required this.openAIPService,
    this.onAirspaceSelected,
  });

  @override
  State<AirspaceFlightInfo> createState() => _AirspaceFlightInfoState();
}

class _AirspaceFlightInfoState extends State<AirspaceFlightInfo> {
  List<Airspace> _currentAirspaces = [];
  Airspace? _nextAirspace;
  double? _distanceToNext;
  double? _timeToNext;

  @override
  void didUpdateWidget(AirspaceFlightInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update airspace info when position changes significantly
    if (_hasSignificantChange(oldWidget)) {
      _updateAirspaceInfo();
    }
  }

  bool _hasSignificantChange(AirspaceFlightInfo oldWidget) {
    // Check if position changed by more than 100 meters
    final distance = Distance().as(
      LengthUnit.Meter,
      widget.currentPosition,
      LatLng(oldWidget.currentPosition.latitude, oldWidget.currentPosition.longitude),
    );
    
    return distance > 100 || 
           (widget.currentAltitude - oldWidget.currentAltitude).abs() > 30 ||
           (widget.currentHeading - oldWidget.currentHeading).abs() > 15;
  }

  @override
  void initState() {
    super.initState();
    _updateAirspaceInfo();
  }

  Future<void> _updateAirspaceInfo() async {
    try {
      // Get current airspaces
      final currentAirspaces = await widget.openAIPService.getAirspacesAtPosition(
        widget.currentPosition,
        widget.currentAltitude,
      );

      // Find next airspace in flight path
      final nextAirspace = await _findNextAirspace();

      setState(() {
        _currentAirspaces = currentAirspaces;
        _nextAirspace = nextAirspace;
      });
    } catch (e) {
      debugPrint('Error updating airspace info: $e');
    }
  }

  Future<Airspace?> _findNextAirspace() async {
    if (widget.currentSpeed < 1) return null; // Not moving

    try {
      // Search ahead in the direction of travel
      final searchDistanceKm = 50.0; // Search 50km ahead
      final bearing = widget.currentHeading;
      
      // Calculate search points along the flight path
      final searchPoints = <LatLng>[];
      for (double distKm = 1; distKm <= searchDistanceKm; distKm += 2) {
        final point = _calculateDestination(
          widget.currentPosition,
          bearing,
          distKm * 1000, // Convert to meters
        );
        searchPoints.add(point);
      }

      // Get all airspaces near the flight path
      final allAirspaces = <Airspace>[];
      for (final point in searchPoints) {
        final airspaces = await widget.openAIPService.getAirspacesAtPosition(
          point,
          widget.currentAltitude,
        );
        allAirspaces.addAll(airspaces);
      }

      // Remove duplicates and current airspaces
      final uniqueAirspaces = allAirspaces
          .where((a) => !_currentAirspaces.any((ca) => ca.id == a.id))
          .toSet()
          .toList();

      if (uniqueAirspaces.isEmpty) return null;

      // Find the closest airspace in the direction of travel
      Airspace? closestAirspace;
      double minDistance = double.infinity;

      for (final airspace in uniqueAirspaces) {
        // Find the closest point on the airspace boundary
        double? closestDist = _getDistanceToAirspace(airspace);
        if (closestDist != null && closestDist < minDistance) {
          minDistance = closestDist;
          closestAirspace = airspace;
        }
      }

      if (closestAirspace != null) {
        _distanceToNext = minDistance;
        _timeToNext = widget.currentSpeed > 0 ? minDistance / widget.currentSpeed : null;
      }

      return closestAirspace;
    } catch (e) {
      debugPrint('Error finding next airspace: $e');
      return null;
    }
  }

  double? _getDistanceToAirspace(Airspace airspace) {
    if (airspace.geometry.isEmpty) return null;

    double minDistance = double.infinity;
    final distance = Distance();

    for (final point in airspace.geometry) {
      final dist = distance.as(LengthUnit.Meter, widget.currentPosition, point);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    return minDistance;
  }

  LatLng _calculateDestination(LatLng start, double bearing, double distanceMeters) {
    const earthRadius = 6371000.0; // Earth's radius in meters
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;
    final brng = bearing * math.pi / 180;
    final d = distanceMeters / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(brng)
    );
    final lon2 = lon1 + math.atan2(
      math.sin(brng) * math.sin(d) * math.cos(lat1),
      math.cos(d) - math.sin(lat1) * math.sin(lat2)
    );

    return LatLng(
      lat2 * 180 / math.pi,
      (lon2 * 180 / math.pi + 540) % 360 - 180,
    );
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAirspaces.isEmpty && _nextAirspace == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentAirspaces.isNotEmpty) ...[
            const Text(
              'CURRENT AIRSPACE',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            ..._currentAirspaces.map((airspace) => GestureDetector(
              onTap: widget.onAirspaceSelected != null 
                  ? () => widget.onAirspaceSelected!(airspace)
                  : null,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Row(
                  children: [
                    Icon(
                      _getAirspaceIcon(airspace.type),
                      size: 12,
                      color: _getAirspaceColor(airspace.type),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${airspace.name} (${AirspaceUtils.getAirspaceTypeName(airspace.type)})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      airspace.altitudeRange,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
          if (_nextAirspace != null && _currentAirspaces.isNotEmpty)
            const Divider(color: Colors.grey, height: 8),
          if (_nextAirspace != null) ...[
            const Text(
              'NEXT AIRSPACE',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: widget.onAirspaceSelected != null && _nextAirspace != null
                  ? () => widget.onAirspaceSelected!(_nextAirspace!)
                  : null,
              child: Row(
                children: [
                  Icon(
                    _getAirspaceIcon(_nextAirspace!.type),
                    size: 12,
                    color: _getAirspaceColor(_nextAirspace!.type),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_nextAirspace!.name} (${_nextAirspace!.type ?? 'Unknown'})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_distanceToNext != null) ...[
                    Text(
                      '${(_distanceToNext! / 1000).toStringAsFixed(1)}km',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                      ),
                    ),
                    if (_timeToNext != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_timeToNext!),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getAirspaceIcon(String? type) {
    final typeName = AirspaceUtils.getAirspaceTypeName(type);
    
    switch (typeName.toUpperCase()) {
      case 'CTR':
      case 'ATZ':
        return Icons.flight_land;
      case 'D':
      case 'DANGER':
      case 'P':
      case 'PROHIBITED':
        return Icons.warning;
      case 'R':
      case 'RESTRICTED':
        return Icons.block;
      case 'TMA':
        return Icons.flight_takeoff;
      case 'TMZ':
      case 'RMZ':
        return Icons.radio;
      default:
        return Icons.layers;
    }
  }

  Color _getAirspaceColor(String? type) {
    final typeName = AirspaceUtils.getAirspaceTypeName(type);
    
    switch (typeName.toUpperCase()) {
      case 'CTR':
      case 'D':
      case 'DANGER':
      case 'P':
      case 'PROHIBITED':
        return Colors.red;
      case 'TMA':
      case 'R':
      case 'RESTRICTED':
        return Colors.orange;
      case 'ATZ':
        return Colors.blue;
      case 'TMZ':
      case 'RMZ':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }
}