import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

class MapZoomControls extends StatelessWidget {
  final MapController mapController;
  final double minZoom;
  final double maxZoom;
  final double zoomStep;
  
  const MapZoomControls({
    super.key,
    required this.mapController,
    required this.minZoom,
    required this.maxZoom,
    this.zoomStep = 0.5,
  });

  void _zoomIn() {
    final currentZoom = mapController.camera.zoom;
    if (currentZoom < maxZoom) {
      HapticFeedback.lightImpact();
      mapController.move(
        mapController.camera.center,
        currentZoom + zoomStep,
      );
    }
  }

  void _zoomOut() {
    final currentZoom = mapController.camera.zoom;
    if (currentZoom > minZoom) {
      HapticFeedback.lightImpact();
      mapController.move(
        mapController.camera.center,
        currentZoom - zoomStep,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        final currentZoom = mapController.camera.zoom;
        final canZoomIn = currentZoom < maxZoom;
        final canZoomOut = currentZoom > minZoom;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildZoomButton(
                icon: Icons.add,
                tooltip: canZoomIn ? 'Zoom in' : 'Maximum zoom reached',
                semanticLabel: 'Zoom in',
                enabled: canZoomIn,
                onTap: _zoomIn,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
              _buildZoomButton(
                icon: Icons.remove,
                tooltip: canZoomOut ? 'Zoom out' : 'Minimum zoom reached',
                semanticLabel: 'Zoom out',
                enabled: canZoomOut,
                onTap: _zoomOut,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required String semanticLabel,
    required bool enabled,
    required VoidCallback onTap,
    required BorderRadius borderRadius,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          label: semanticLabel,
          button: true,
          enabled: enabled,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: borderRadius,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                icon,
                size: 20,
                color: enabled ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }
}