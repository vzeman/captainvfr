import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/navaid.dart';

class NavaidMarker extends StatelessWidget {
  final Navaid navaid;
  final VoidCallback? onTap;
  final double size;
  final bool isSelected;

  const NavaidMarker({
    super.key,
    required this.navaid,
    this.onTap,
    this.size = 20.0,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _getNavaidIcon(navaid.type);
    final color = _getNavaidColor(navaid.type);
    final borderColor = isSelected ? Colors.amber : color;
    final borderWidth = isSelected ? 2.5 : 1.5;

    // Visual size of the marker
    const visualSize = 24.0;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: visualSize,
          height: visualSize,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(230),
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x33000000),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: visualSize * 0.6,
            color: color,
          ),
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
        return Icons.radio;
      case 'NDB':
      case 'LOCATOR':
        return Icons.radio_button_checked;
      case 'TACAN':
        return Icons.gps_fixed;
      case 'DME':
        return Icons.my_location;
      case 'ILS':
      case 'LOC':
        return Icons.flight_land;
      case 'GS':
        return Icons.trending_down;
      case 'OM':
      case 'MM':
      case 'IM':
        return Icons.place;
      default:
        return Icons.navigation;
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

  const NavaidMarkersLayer({
    super.key,
    required this.navaids,
    this.onNavaidTap,
    this.markerSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: navaids.map((navaid) {
        return Marker(
          point: navaid.position,
          width: markerSize + 4, // Slightly larger for touch area
          height: markerSize + 4,
          child: NavaidMarker(
            navaid: navaid,
            size: markerSize,
            onTap: () => onNavaidTap?.call(navaid),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(51),
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
                Icon(
                  Icons.navigation,
                  color: theme.primaryColor,
                  size: 24,
                ),
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
                  _buildInfoRow('DME Frequency', '${(navaid.dmeFrequencyKhz / 1000).toStringAsFixed(3)} MHz'),
                if (navaid.dmeChannel.isNotEmpty)
                  _buildInfoRow('DME Channel', navaid.dmeChannel),
                _buildInfoRow('Elevation', '${navaid.elevationFt} ft MSL'),
                _buildInfoRow('Country', navaid.isoCountry),
                if (navaid.usageType.isNotEmpty)
                  _buildInfoRow('Usage', navaid.usageType),
                if (navaid.power > 0)
                  _buildInfoRow('Power', '${navaid.power.toStringAsFixed(1)} watts'),
                if (navaid.associatedAirport.isNotEmpty)
                  _buildInfoRow('Associated Airport', navaid.associatedAirport),
                _buildInfoRow(
                  'Coordinates',
                  '${navaid.position.latitude.toStringAsFixed(4)}°N, ${navaid.position.longitude.toStringAsFixed(4)}°E'
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
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
