import 'package:flutter/material.dart';
import '../models/hotspot.dart';

class HotspotMarker extends StatelessWidget {
  final Hotspot hotspot;
  final VoidCallback? onTap;
  final double size;
  final double mapZoom;

  const HotspotMarker({
    super.key,
    required this.hotspot,
    this.onTap,
    this.size = 30.0,
    this.mapZoom = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    // Determine icon and color based on hotspot type
    IconData icon;
    Color color;
    
    // Check type or default to thermal hotspot
    final type = hotspot.type?.toLowerCase() ?? '';
    
    if (type.contains('thermal') || type.isEmpty) {
      // Thermal hotspots for gliders/paragliders
      icon = Icons.air;
      color = Colors.blue.shade700;
    } else if (type.contains('view') || type.contains('photo')) {
      // Viewpoints or photo spots
      icon = Icons.photo_camera;
      color = Colors.purple;
    } else if (type.contains('land')) {
      // Landing spots
      icon = Icons.flight_land;
      color = Colors.green;
    } else if (type.contains('takeoff') || type.contains('launch')) {
      // Takeoff/launch spots
      icon = Icons.flight_takeoff;
      color = Colors.orange;
    } else {
      // Default hotspot
      icon = Icons.location_on;
      color = Colors.teal;
    }

    // Determine reliability indicator color
    Color? reliabilityColor;
    if (hotspot.reliability != null) {
      switch (hotspot.reliability?.toLowerCase()) {
        case 'high':
        case '2': // Based on test data
          reliabilityColor = Colors.green;
          break;
        case 'medium':
        case '1':
          reliabilityColor = Colors.orange;
          break;
        case 'low':
        case '0':
          reliabilityColor = Colors.red;
          break;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Main marker
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                size: size * 0.6,
                color: Colors.white,
              ),
            ),
          ),
          
          // Reliability indicator
          if (reliabilityColor != null)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: reliabilityColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
              ),
            ),
          
          // Name label (shown at higher zoom levels)
          if (mapZoom >= 11)
            Positioned(
              bottom: -20,
              child: Container(
                constraints: BoxConstraints(maxWidth: size * 3),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  hotspot.name,
                  style: TextStyle(
                    fontSize: mapZoom >= 12 ? 11.0 : 9.0, // Same font sizing as navaid/obstacle/reporting points
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}