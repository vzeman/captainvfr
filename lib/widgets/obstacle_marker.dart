import 'package:flutter/material.dart';
import '../models/obstacle.dart';

class ObstacleMarker extends StatelessWidget {
  final Obstacle obstacle;
  final VoidCallback? onTap;
  final double size;
  final double mapZoom;

  const ObstacleMarker({
    super.key,
    required this.obstacle,
    this.onTap,
    this.size = 10.0,
    this.mapZoom = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    // Determine icon and color based on obstacle properties
    IconData icon;
    Color color;
    
    if (obstacle.type?.toLowerCase().contains('tower') ?? false) {
      // Tower type obstacles
      icon = Icons.cell_tower;
      color = Colors.deepOrange;
    } else if (obstacle.type?.toLowerCase().contains('building') ?? false) {
      // Building type obstacles
      icon = Icons.domain;
      color = Colors.brown;
    } else if (obstacle.type?.toLowerCase().contains('crane') ?? false) {
      // Crane type obstacles
      icon = Icons.construction;
      color = Colors.yellow.shade800;
    } else if (obstacle.type?.toLowerCase().contains('wind') ?? false) {
      // Wind turbines
      icon = Icons.wind_power;
      color = Colors.green.shade700;
    } else {
      // Default obstacle
      icon = Icons.warning;
      color = Colors.amber;
    }

    // Add lighting indicator
    final hasLighting = obstacle.lighted;

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
          
          // Lighting indicator
          if (hasLighting)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.light_mode,
                  size: size * 0.15,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          
          // Height label (shown at higher zoom levels)
          if (mapZoom >= 12)
            Positioned(
              bottom: -20,
              child: Container(
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
                  '${obstacle.totalHeightFt} ft',
                  style: TextStyle(
                    fontSize: mapZoom >= 12 ? 11.0 : 9.0, // Same font sizing as navaid/reporting points
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}