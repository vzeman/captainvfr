import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/flight_plan.dart';

class DraggableWaypointMarker extends StatefulWidget {
  final int waypointIndex;
  final Waypoint waypoint;
  final Function(int) onWaypointTapped;
  final Function(int, LatLng, {bool isDragging}) onWaypointMoved;
  final bool isSelected;
  final Function(bool)? onDraggingChanged;
  final GlobalKey mapKey;
  final bool isEditMode;

  const DraggableWaypointMarker({
    super.key,
    required this.waypointIndex,
    required this.waypoint,
    required this.onWaypointTapped,
    required this.onWaypointMoved,
    required this.isSelected,
    this.onDraggingChanged,
    required this.mapKey,
    required this.isEditMode,
  });

  @override
  State<DraggableWaypointMarker> createState() =>
      _DraggableWaypointMarkerState();
}

class _DraggableWaypointMarkerState extends State<DraggableWaypointMarker> {
  bool _isDragging = false;
  Offset? _lastPosition;
  Timer? _throttleTimer;
  LatLng? _pendingPosition;

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // This prevents tap from going through
      onTap: () {
        // Handle tap only when not dragging
        if (!_isDragging) {
          widget.onWaypointTapped(widget.waypointIndex);
        }
      },
      child: Listener(
        behavior: HitTestBehavior.opaque, // Also prevent pointer events from going through
        onPointerDown: (event) {
          if (widget.isSelected && widget.isEditMode) {
            setState(() {
              _isDragging = true;
              _lastPosition = event.position;
            });
            widget.onDraggingChanged?.call(true);
          }
        },
        onPointerMove: (event) {
          if (_isDragging && _lastPosition != null) {
            // Update position during drag for real-time feedback
            setState(() {
              _lastPosition = event.position;
            });
            
            // Calculate the new position
            final newLatLng = _calculateNewPosition(event.position);
            if (newLatLng != null) {
              // Update immediately for smooth visual feedback
              widget.onWaypointMoved(widget.waypointIndex, newLatLng, isDragging: true);
              
              // Store pending position for final update
              _pendingPosition = newLatLng;
              
              // Throttle the expensive operations
              _throttleTimer?.cancel();
              _throttleTimer = Timer(const Duration(milliseconds: 16), () {
                // 60fps throttling
                if (_pendingPosition != null && _isDragging) {
                  // Position is already updated, just ensure state is consistent
                }
              });
            }
          }
        },
        onPointerUp: (event) {
          if (_isDragging) {
            // Final position update
            final finalPosition = _calculateNewPosition(event.position);
            if (finalPosition != null) {
              widget.onWaypointMoved(widget.waypointIndex, finalPosition, isDragging: false);
            }
            
            setState(() {
              _isDragging = false;
              _lastPosition = null;
              _pendingPosition = null;
            });
            _throttleTimer?.cancel();
            widget.onDraggingChanged?.call(false);
          }
        },
        onPointerCancel: (event) {
          if (_isDragging) {
            setState(() {
              _isDragging = false;
              _lastPosition = null;
              _pendingPosition = null;
            });
            _throttleTimer?.cancel();
            widget.onDraggingChanged?.call(false);
          }
        },
        child: MouseRegion(
        cursor: widget.isSelected && widget.isEditMode
            ? (_isDragging
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab)
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
      ),
    );
  }

  LatLng? _calculateNewPosition(Offset globalPosition) {
    try {
      // Get the map's render box
      final RenderBox? mapBox =
          widget.mapKey.currentContext?.findRenderObject() as RenderBox?;
      if (mapBox == null) return null;

      // Convert global position to local position relative to the map
      final localPosition = mapBox.globalToLocal(globalPosition);

      // Get the map camera to convert coordinates
      final mapCamera = MapCamera.maybeOf(context);
      if (mapCamera == null) return null;

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

      return LatLng(lat, lng);
    } catch (e) {
      // debugPrint('Error calculating new position: $e');
      return null;
    }
  }
  
  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }
}
