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
  final VoidCallback? onClose;

  const AirspaceFlightInfo({
    super.key,
    required this.currentPosition,
    required this.currentAltitude,
    required this.currentHeading,
    required this.currentSpeed,
    required this.openAIPService,
    this.onAirspaceSelected,
    this.onClose,
  });

  @override
  State<AirspaceFlightInfo> createState() => _AirspaceFlightInfoState();
}

class _AirspaceFlightInfoState extends State<AirspaceFlightInfo> {
  List<Airspace> _currentAirspaces = [];
  Airspace? _nextAirspace;
  double? _distanceToNext;
  double? _timeToNext;
  double? _distanceToExit;
  double? _timeToExit;

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
      LatLng(
        oldWidget.currentPosition.latitude,
        oldWidget.currentPosition.longitude,
      ),
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
      final currentAirspaces = await widget.openAIPService
          .getAirspacesAtPosition(
            widget.currentPosition,
            widget.currentAltitude,
          );

      // Find next airspace in flight path
      final nextAirspace = await _findNextAirspace();

      // Calculate distance to exit current airspace if no next airspace
      if (currentAirspaces.isNotEmpty &&
          nextAirspace == null &&
          widget.currentSpeed > 1) {
        _calculateExitDistance(currentAirspaces.first);
      } else {
        _distanceToExit = null;
        _timeToExit = null;
      }

      setState(() {
        _currentAirspaces = currentAirspaces;
        _nextAirspace = nextAirspace;
      });
    } catch (e) {
      // Error updating airspace info: $e
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
        _timeToNext = widget.currentSpeed > 0
            ? minDistance / widget.currentSpeed
            : null;
      }

      return closestAirspace;
    } catch (e) {
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

  void _calculateExitDistance(Airspace currentAirspace) {
    if (currentAirspace.geometry.isEmpty || widget.currentSpeed < 1) {
      _distanceToExit = null;
      _timeToExit = null;
      return;
    }

    // Search for airspace boundary in the direction of travel
    final bearing = widget.currentHeading;
    double? exitDistance;

    // Check points along the flight path to find where we exit the airspace
    for (double distKm = 0.5; distKm <= 50; distKm += 0.5) {
      final checkPoint = _calculateDestination(
        widget.currentPosition,
        bearing,
        distKm * 1000, // Convert to meters
      );

      // Check if this point is still inside the airspace
      final inAirspace = _isPointInAirspace(checkPoint, currentAirspace);

      if (!inAirspace) {
        // Found the exit point
        exitDistance = distKm * 1000; // Convert to meters
        break;
      }
    }

    if (exitDistance != null) {
      _distanceToExit = exitDistance;
      _timeToExit = exitDistance / widget.currentSpeed;
    } else {
      _distanceToExit = null;
      _timeToExit = null;
    }
  }

  bool _isPointInAirspace(LatLng point, Airspace airspace) {
    // Simple point-in-polygon check
    // This is a basic implementation - in production, use a proper
    // point-in-polygon algorithm considering the airspace geometry
    if (airspace.geometry.isEmpty) return false;

    // For now, check if the point is within a certain distance of any boundary point
    // This is a simplification - real implementation would need proper polygon checking
    final distance = Distance();
    const double threshold = 1000; // 1km threshold

    for (final boundaryPoint in airspace.geometry) {
      final dist = distance.as(LengthUnit.Meter, point, boundaryPoint);
      if (dist < threshold) {
        return true;
      }
    }

    return false;
  }

  LatLng _calculateDestination(
    LatLng start,
    double bearing,
    double distanceMeters,
  ) {
    const earthRadius = 6371000.0; // Earth's radius in meters
    final lat1 = start.latitude * math.pi / 180;
    final lon1 = start.longitude * math.pi / 180;
    final brng = bearing * math.pi / 180;
    final d = distanceMeters / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(d) +
          math.cos(lat1) * math.sin(d) * math.cos(brng),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(brng) * math.sin(d) * math.cos(lat1),
          math.cos(d) - math.sin(lat1) * math.sin(lat2),
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
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CURRENT AIRSPACE',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'No airspace at current position',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final horizontalMargin = isPhone
        ? 8.0
        : 0.0; // Minimal margin on phones, no margin on tablets

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 4.0),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CURRENT AIRSPACE',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white70,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ..._currentAirspaces.map(
              (airspace) => GestureDetector(
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
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_distanceToNext != null) ...[
                    Text(
                      '${(_distanceToNext! / 1000).toStringAsFixed(1)}km',
                      style: const TextStyle(color: Colors.blue, fontSize: 10),
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
          // Show exit distance if no next airspace
          if (_currentAirspaces.isNotEmpty &&
              _nextAirspace == null &&
              _distanceToExit != null) ...[
            if (_currentAirspaces.isNotEmpty)
              const Divider(color: Colors.grey, height: 8),
            const Text(
              'AIRSPACE EXIT',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.exit_to_app, size: 12, color: Colors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Exiting ${_currentAirspaces.first.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(_distanceToExit! / 1000).toStringAsFixed(1)}km',
                  style: const TextStyle(color: Colors.orange, fontSize: 10),
                ),
                if (_timeToExit != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_timeToExit!),
                    style: const TextStyle(color: Colors.green, fontSize: 10),
                  ),
                ],
              ],
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
