import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/reporting_point.dart';

class ReportingPointsOverlay extends StatelessWidget {
  final List<ReportingPoint> reportingPoints;
  final bool showReportingPointsLayer;
  final Function(ReportingPoint)? onReportingPointTap;
  final double mapZoom;

  const ReportingPointsOverlay({
    super.key,
    required this.reportingPoints,
    required this.showReportingPointsLayer,
    this.onReportingPointTap,
    this.mapZoom = 10,
  });

  @override
  Widget build(BuildContext context) {

    if (!showReportingPointsLayer || reportingPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    // Only show reporting points when zoomed in enough
    // Temporarily lowered threshold from 9 to 7 for debugging
    if (mapZoom < 7) {
      return const SizedBox.shrink();
    }

    return MarkerLayer(
      markers: reportingPoints.map((point) => _buildReportingPointMarker(point)).toList(),
    );
  }

  Marker _buildReportingPointMarker(ReportingPoint point) {
    // Calculate marker size based on zoom level
    final markerSize = mapZoom >= 12 ? 20.0 : 14.0;
    final iconSize = mapZoom >= 12 ? 14.0 : 10.0;
    final fontSize = mapZoom >= 12 ? 11.0 : 9.0;
    final showLabel = mapZoom >= 11;
    // Increase height when showing label to accommodate both marker and text
    final totalHeight = showLabel ? markerSize + 20.0 : markerSize;
    
    return Marker(
      point: point.position,
      width: showLabel ? 100.0 : markerSize, // Wider when showing label
      height: totalHeight,
      child: GestureDetector(
        onTap: () => onReportingPointTap?.call(point),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: markerSize,
              height: markerSize,
              decoration: BoxDecoration(
                color: _getPointColor(point.type).withValues(alpha: 0.9),
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
                  _getPointIcon(point.type),
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
            ),
            // Show name label when zoomed in
            if (mapZoom >= 11)
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
                child: Text(
                  point.name,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getPointColor(String? type) {
    if (type == null) return Colors.purple;
    
    switch (type.toUpperCase()) {
      case 'COMPULSORY':
      case 'MANDATORY':
        return Colors.red;
      case 'OPTIONAL':
      case 'VOLUNTARY':
        return Colors.blue;
      case 'VFR':
        return Colors.green;
      case 'IFR':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  IconData _getPointIcon(String? type) {
    if (type == null) return Icons.place;
    
    switch (type.toUpperCase()) {
      case 'COMPULSORY':
      case 'MANDATORY':
        return Icons.flag;
      case 'OPTIONAL':
      case 'VOLUNTARY':
        return Icons.location_on;
      case 'VFR':
        return Icons.flight;
      case 'IFR':
        return Icons.navigation;
      default:
        return Icons.place;
    }
  }
}