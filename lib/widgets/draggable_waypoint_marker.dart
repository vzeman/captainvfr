import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../models/flight_plan.dart';

class DraggableWaypointMarker extends StatefulWidget {
  final int waypointIndex;
  final Waypoint waypoint;
  final Function(int) onWaypointTapped;
  final Function(int, LatLng) onWaypointMoved;
  final bool isSelected;

  const DraggableWaypointMarker({
    super.key,
    required this.waypointIndex,
    required this.waypoint,
    required this.onWaypointTapped,
    required this.onWaypointMoved,
    required this.isSelected,
  });

  @override
  State<DraggableWaypointMarker> createState() => _DraggableWaypointMarkerState();
}

class _DraggableWaypointMarkerState extends State<DraggableWaypointMarker> {
  bool _isDragging = false;
  Offset _dragOffset = Offset.zero;
  LatLng? _initialPosition;

  Color _getWaypointColor(WaypointType type) {
    switch (type) {
      case WaypointType.airport:
        return Colors.green;
      case WaypointType.navaid:
        return Colors.purple;
      case WaypointType.fix:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _fallbackCoordinateCalculation(MapCamera mapCamera) {
    if (_initialPosition == null) return;
    
    try {
      // Calculate the scale factor based on zoom level
      // At zoom level 10, 1 degree ≈ 69 miles ≈ 60 nautical miles
      final metersPerPixel = 40075016.686 / (256 * math.pow(2, mapCamera.zoom));
      final degreesPerPixel = metersPerPixel / 111320.0; // meters per degree at equator
      
      // Adjust for latitude (longitude degrees get smaller as you move away from equator)
      final lngDegreesPerPixel = degreesPerPixel / math.cos(_initialPosition!.latitude * math.pi / 180);
      
      final latChange = -_dragOffset.dy * degreesPerPixel;
      final lngChange = _dragOffset.dx * lngDegreesPerPixel;
      
      final newLatLng = LatLng(
        _initialPosition!.latitude + latChange,
        _initialPosition!.longitude + lngChange,
      );
      
      widget.onWaypointMoved(widget.waypointIndex, newLatLng);
    } catch (e) {
      debugPrint('Fallback coordinate calculation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_isDragging) {
          widget.onWaypointTapped(widget.waypointIndex);
        }
      },
      onPanStart: (details) {
        // Only allow dragging if the waypoint is selected
        if (widget.isSelected) {
          setState(() {
            _isDragging = true;
            _dragOffset = Offset.zero;
            _initialPosition = widget.waypoint.latLng;
          });
        }
      },
      onPanUpdate: (details) {
        if (_isDragging) {
          setState(() {
            _dragOffset += details.delta;
          });
        }
      },
      onPanEnd: (details) {
        if (_isDragging && _initialPosition != null) {
          // Get the map camera to convert coordinates
          final mapCamera = MapCamera.maybeOf(context);
          if (mapCamera != null) {
            // Use the fallback calculation method directly for flutter_map 8.x
            _fallbackCoordinateCalculation(mapCamera);
          }
          
          setState(() {
            _isDragging = false;
            _dragOffset = Offset.zero;
            _initialPosition = null;
          });
        }
      },
      child: Transform.translate(
        offset: _dragOffset,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _getWaypointColor(widget.waypoint.type),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected ? Colors.yellow : Colors.white,
              width: widget.isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDragging ? 0.5 : 0.3),
                blurRadius: _isDragging ? 8 : 4,
                offset: Offset(0, _isDragging ? 4 : 2),
              ),
            ],
          ),
          child: MouseRegion(
            cursor: widget.isSelected 
                ? (_isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab)
                : SystemMouseCursors.click,
            child: Center(
              child: Text(
                '${widget.waypointIndex + 1}',
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
}