import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/heatmap_cell.dart';
import '../services/flight_heatmap_processor.dart';

class OptimizedHeatmapLayer extends StatelessWidget {
  final double opacity;
  final List<Color> heatmapColors;
  final bool enabled;

  const OptimizedHeatmapLayer({
    super.key,
    this.opacity = 0.6,
    this.heatmapColors = const [
      Color(0x00FF4500), // Transparent orange
      Color(0x80FF4500), // Semi-transparent orange
      Color(0xFFFF4500), // Orange
      Color(0xFFFF0000), // Red
      Color(0xFFDC143C), // Dark red
    ],
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    final mapController = MapController.maybeOf(context);
    if (mapController == null) return const SizedBox.shrink();

    return StreamBuilder<MapEvent>(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        final camera = mapController.camera;
        final currentZoom = camera.zoom;
        final viewport = camera.visibleBounds;
        
        final renderZoom = FlightHeatmapProcessor.selectOptimalZoomLevel(currentZoom);
        
        return FutureBuilder<List<HeatmapCell>>(
          future: FlightHeatmapProcessor.getHeatmapCells(renderZoom, viewport),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // Show indicator when no data
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'No heatmap data yet',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              );
            }
            
            return CustomPaint(
              painter: HeatmapPainter(
                cells: snapshot.data!,
                mapCamera: camera,
                colors: heatmapColors,
                opacity: opacity,
              ),
              size: Size.infinite,
            );
          },
        );
      },
    );
  }
}

class HeatmapPainter extends CustomPainter {
  final List<HeatmapCell> cells;
  final MapCamera mapCamera;
  final List<Color> colors;
  final double opacity;

  HeatmapPainter({
    required this.cells,
    required this.mapCamera,
    required this.colors,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.multiply;

    for (final cell in cells) {
      final center = mapCamera.latLngToScreenOffset(cell.center);
      
      if (center.dx < -50 || center.dx > size.width + 50 ||
          center.dy < -50 || center.dy > size.height + 50) {
        continue;
      }

      final color = _getColorForIntensity(cell.intensity);
      paint.color = color.withValues(alpha: color.a * opacity);

      final radius = _getRadiusForZoom(mapCamera.zoom, cell.cellSize);
      
      final gradient = RadialGradient(
        colors: [
          color.withValues(alpha: color.a * opacity),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.5, 1.0],
      );

      final rect = Rect.fromCircle(
        center: center,
        radius: radius,
      );

      paint.shader = gradient.createShader(rect);
      
      canvas.drawCircle(
        center,
        radius,
        paint,
      );
    }
  }

  Color _getColorForIntensity(double intensity) {
    if (intensity <= 0.0) return colors[0];
    if (intensity >= 1.0) return colors.last;

    final scaledIntensity = intensity * (colors.length - 1);
    final index = scaledIntensity.floor();
    final fraction = scaledIntensity - index;

    if (index >= colors.length - 1) return colors.last;

    return Color.lerp(colors[index], colors[index + 1], fraction) ?? colors[index];
  }

  double _getRadiusForZoom(double zoom, double cellSize) {
    const baseRadius = 20.0;
    final zoomFactor = (zoom / 10.0).clamp(0.3, 2.0);
    final sizeFactor = (cellSize * 100).clamp(0.5, 3.0);
    
    return baseRadius * zoomFactor * sizeFactor;
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter oldDelegate) {
    return cells != oldDelegate.cells ||
           mapCamera != oldDelegate.mapCamera ||
           opacity != oldDelegate.opacity;
  }
}