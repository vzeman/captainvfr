import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/flight_plan.dart';

class DraggableWaypointMarker extends StatefulWidget {
  final int waypointIndex;
  final Waypoint waypoint;
  final Function(int) onWaypointTapped;
  final Function(int, LatLng) onWaypointMoved;
  final bool isSelected;
  final Function(bool)? onDraggingChanged;
  final GlobalKey mapKey;

  const DraggableWaypointMarker({
    super.key,
    required this.waypointIndex,
    required this.waypoint,
    required this.onWaypointTapped,
    required this.onWaypointMoved,
    required this.isSelected,
    this.onDraggingChanged,
    required this.mapKey,
  });

  @override
  State<DraggableWaypointMarker> createState() => _DraggableWaypointMarkerState();
}

class _DraggableWaypointMarkerState extends State<DraggableWaypointMarker> {
  bool _isDragging = false;
  Offset? _lastPosition;

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

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (widget.isSelected) {
          setState(() {
            _isDragging = true;
            _lastPosition = event.position;
          });
          widget.onDraggingChanged?.call(true);
        } else {
          widget.onWaypointTapped(widget.waypointIndex);
        }
      },
      onPointerMove: (event) {
        if (_isDragging && _lastPosition != null) {
          // Update position during drag (visual feedback only)
          setState(() {
            _lastPosition = event.position;
          });
        }
      },
      onPointerUp: (event) {
        if (_isDragging) {
          // Calculate and apply the new position
          _applyNewPosition(event.position);
          setState(() {
            _isDragging = false;
            _lastPosition = null;
          });
          widget.onDraggingChanged?.call(false);
        }
      },
      onPointerCancel: (event) {
        if (_isDragging) {
          setState(() {
            _isDragging = false;
            _lastPosition = null;
          });
          widget.onDraggingChanged?.call(false);
        }
      },
      child: MouseRegion(
        cursor: widget.isSelected 
            ? (_isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab)
            : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 30,
          height: 30,
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
    );
  }

  void _applyNewPosition(Offset globalPosition) {
    try {
      // Get the map's render box
      final RenderBox? mapBox = widget.mapKey.currentContext?.findRenderObject() as RenderBox?;
      if (mapBox == null) return;

      // Convert global position to local position relative to the map
      final localPosition = mapBox.globalToLocal(globalPosition);

      // Get the map camera to convert coordinates
      final mapCamera = MapCamera.maybeOf(context);
      if (mapCamera == null) return;

      // Get map dimensions
      final mapWidth = mapCamera.nonRotatedSize.width;
      final mapHeight = mapCamera.nonRotatedSize.height;
      
      // Calculate the relative position (0-1)
      final relativeX = localPosition.dx / mapWidth;
      final relativeY = localPosition.dy / mapHeight;
      
      // Get the current map bounds
      final bounds = mapCamera.visibleBounds;
      
      // Calculate the new latitude and longitude
      final lng = bounds.west + (bounds.east - bounds.west) * relativeX;
      final lat = bounds.north - (bounds.north - bounds.south) * relativeY;
      
      final newPosition = LatLng(lat, lng);
      
      // Call the callback with the new position
      widget.onWaypointMoved(widget.waypointIndex, newPosition);
    } catch (e) {
      debugPrint('Error calculating new position: $e');
    }
  }
}