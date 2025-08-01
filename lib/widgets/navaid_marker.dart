import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;
import '../models/navaid.dart';
import '../constants/app_theme.dart';
import '../constants/map_marker_constants.dart';

class NavaidMarker extends StatelessWidget {
  final Navaid navaid;
  final VoidCallback? onTap;
  final double size;
  final bool isSelected;
  final double mapZoom;

  const NavaidMarker({
    super.key,
    required this.navaid,
    this.onTap,
    this.size = 20.0,
    this.isSelected = false,
    this.mapZoom = 10,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _getNavaidIcon(navaid.type);
    final color = _getNavaidColor(navaid.type);
    final borderColor = isSelected ? Colors.amber : color;
    final borderWidth = isSelected ? 2.5 : 1.5;

    // Visual size of the marker based on zoom
    // Use the size parameter which is already adjusted for zoom
    final visualSize = size;

    // Determine if label should be shown based on zoom
    final shouldShowLabel = mapZoom >= MapMarkerConstants.navaidLabelShowZoom;
    
    // Calculate font size with responsive scaling and minimum constraint
    double fontSize;
    if (mapZoom >= 16) {
      // Scale up for very high zoom levels
      fontSize = MapMarkerConstants.navaidLabelBaseHighZoom * 
                 MapMarkerConstants.navaidLabelScaleFactor * 
                 (1 + (mapZoom - 16) * 0.1);
      fontSize = math.min(fontSize, MapMarkerConstants.navaidLabelMaxFontSize);
    } else if (mapZoom >= MapMarkerConstants.navaidHighDetailZoom) {
      fontSize = MapMarkerConstants.navaidLabelBaseHighZoom * 
                 MapMarkerConstants.navaidLabelScaleFactor;
    } else {
      fontSize = MapMarkerConstants.navaidLabelBaseLowZoom * 
                 MapMarkerConstants.navaidLabelScaleFactor;
    }
    
    // Ensure minimum readable font size
    fontSize = math.max(fontSize, MapMarkerConstants.minReadableFontSize);

    return GestureDetector(
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: visualSize,
              height: visualSize,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x33000000),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(icon, size: visualSize * 0.6, color: color),
            ),
            // Show label when zoomed in enough
            if (shouldShowLabel)
              Container(
                margin: const EdgeInsets.only(top: 2),
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
                child: Semantics(
                  label: 'Navigation aid ${navaid.ident} ${navaid.name}',
                  child: Text(
                    navaid.ident,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: TextScaler.linear(
                      fontSize < MapMarkerConstants.minReadableFontSize ? 1.5 : 1.0
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Get appropriate icon based on navaid type
  IconData _getNavaidIcon(String type) {
    switch (type.toUpperCase()) {
      case 'VOR':
      case 'VORDME':
      case 'VORTAC':
        return Icons.explore; // Compass icon for VOR navigation
      case 'NDB':
      case 'LOCATOR':
        return Icons.cell_tower; // Cell tower icon for beacon navigation
      case 'TACAN':
        return Icons.navigation; // Navigation icon for TACAN
      case 'DME':
        return Icons.radar; // Radar icon for distance measuring equipment
      case 'ILS':
      case 'LOC':
        return Icons.flight_land; // Keep landing icon for ILS
      case 'GS':
        return Icons.trending_down; // Keep glide slope icon
      case 'OM':
      case 'MM':
      case 'IM':
        return Icons.flag; // Flag icon for marker beacons
      default:
        return Icons.explore; // Default to compass for unknown navigation aids
    }
  }

  /// Get color based on navaid type
  Color _getNavaidColor(String type) {
    switch (type.toUpperCase()) {
      case 'VOR':
      case 'VORDME':
      case 'VORTAC':
        return Colors.blue;
      case 'NDB':
      case 'LOCATOR':
        return Colors.orange;
      case 'TACAN':
        return Colors.purple;
      case 'DME':
        return Colors.green;
      case 'ILS':
      case 'LOC':
        return Colors.red;
      case 'GS':
        return Colors.red.shade300;
      case 'OM':
      case 'MM':
      case 'IM':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}

/// Navaid markers layer for the map
class NavaidMarkersLayer extends StatelessWidget {
  final List<Navaid> navaids;
  final ValueChanged<Navaid>? onNavaidTap;
  final double markerSize;
  final double mapZoom;

  const NavaidMarkersLayer({
    super.key,
    required this.navaids,
    this.onNavaidTap,
    this.markerSize = 20.0,
    this.mapZoom = 10,
  });

  @override
  Widget build(BuildContext context) {
    // Only show navaids when zoomed in enough (same threshold as reporting points)
    if (mapZoom < 9) {
      return const SizedBox.shrink();
    }

    // Dynamic size based on zoom - same as reporting points
    final dynamicMarkerSize = mapZoom >= 12 ? 20.0 : 14.0;

    return MarkerLayer(
      markers: navaids.map((navaid) {
        return Marker(
          point: navaid.position,
          width: dynamicMarkerSize + 4, // Slightly larger for touch area
          height: dynamicMarkerSize + 4,
          child: NavaidMarker(
            navaid: navaid,
            size: dynamicMarkerSize,
            onTap: () => onNavaidTap?.call(navaid),
            mapZoom: mapZoom,
          ),
        );
      }).toList(),
    );
  }
}

/// Navaid info sheet widget
class NavaidInfoSheet extends StatelessWidget {
  final Navaid navaid;
  final VoidCallback onClose;

  const NavaidInfoSheet({
    super.key,
    required this.navaid,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusDefault)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.navigation, color: theme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${navaid.ident} - ${navaid.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        navaid.typeDisplay,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Navaid information
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Type', navaid.typeDisplay),
                _buildInfoRow('Frequency', '${navaid.frequencyMhz} MHz'),
                if (navaid.dmeFrequencyKhz > 0)
                  _buildInfoRow(
                    'DME Frequency',
                    '${(navaid.dmeFrequencyKhz / 1000).toStringAsFixed(3)} MHz',
                  ),
                if (navaid.dmeChannel.isNotEmpty)
                  _buildInfoRow('DME Channel', navaid.dmeChannel),
                _buildInfoRow('Elevation', '${navaid.elevationFt} ft MSL'),
                _buildInfoRow('Country', navaid.isoCountry),
                if (navaid.usageType.isNotEmpty)
                  _buildInfoRow('Usage', navaid.usageType),
                if (navaid.power > 0)
                  _buildInfoRow(
                    'Power',
                    '${navaid.power.toStringAsFixed(1)} watts',
                  ),
                if (navaid.associatedAirport.isNotEmpty)
                  _buildInfoRow('Associated Airport', navaid.associatedAirport),
                _buildInfoRow(
                  'Coordinates',
                  '${navaid.position.latitude.toStringAsFixed(4)}°N, ${navaid.position.longitude.toStringAsFixed(4)}°E',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
