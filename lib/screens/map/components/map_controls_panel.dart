import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'layer_toggle_button.dart';

class MapControlsPanel extends StatelessWidget {
  final bool showNavaids;
  final bool showMetar;
  final bool showStats;
  final bool showHeliports;
  final bool showAirspaces;
  final bool showObstacles;
  final bool showHotspots;
  final VoidCallback onToggleNavaids;
  final VoidCallback onToggleMetar;
  final VoidCallback onToggleStats;
  final VoidCallback onToggleHeliports;
  final VoidCallback onToggleAirspaces;
  final VoidCallback onToggleObstacles;
  final VoidCallback onToggleHotspots;
  final VoidCallback onMenuPressed;
  final VoidCallback onSearchPressed;

  const MapControlsPanel({
    super.key,
    required this.showNavaids,
    required this.showMetar,
    required this.showStats,
    required this.showHeliports,
    required this.showAirspaces,
    required this.showObstacles,
    required this.showHotspots,
    required this.onToggleNavaids,
    required this.onToggleMetar,
    required this.onToggleStats,
    required this.onToggleHeliports,
    required this.onToggleAirspaces,
    required this.onToggleObstacles,
    required this.onToggleHotspots,
    required this.onMenuPressed,
    required this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: onMenuPressed,
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: onSearchPressed,
                ),
              ],
            ),
            const Divider(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayerToggleButton(
                  icon: Icons.radar,
                  tooltip: 'Toggle Navaids',
                  isActive: showNavaids,
                  onPressed: onToggleNavaids,
                ),
                LayerToggleButton(
                  icon: Icons.cloud,
                  tooltip: 'Toggle METAR',
                  isActive: showMetar,
                  onPressed: onToggleMetar,
                ),
                LayerToggleButton(
                  icon: Icons.bar_chart,
                  tooltip: 'Toggle Flight Dashboard',
                  isActive: showStats,
                  onPressed: onToggleStats,
                ),
                LayerToggleButton(
                  icon: FontAwesomeIcons.helicopter,
                  tooltip: 'Toggle Heliports',
                  isActive: showHeliports,
                  onPressed: onToggleHeliports,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LayerToggleButton(
                  icon: Icons.layers,
                  tooltip: 'Toggle Airspaces',
                  isActive: showAirspaces,
                  onPressed: onToggleAirspaces,
                ),
                LayerToggleButton(
                  icon: Icons.warning,
                  tooltip: 'Toggle Obstacles',
                  isActive: showObstacles,
                  onPressed: onToggleObstacles,
                ),
                LayerToggleButton(
                  icon: Icons.location_on,
                  tooltip: 'Toggle Hotspots',
                  isActive: showHotspots,
                  onPressed: onToggleHotspots,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}