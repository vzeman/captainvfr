import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/runway.dart';

class RunwayPainter extends CustomPainter {
  final List<Runway> runways;
  final double zoom;
  final Color runwayColor;
  final double strokeWidth;

  RunwayPainter({
    required this.runways,
    required this.zoom,
    this.runwayColor = Colors.black87,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (runways.isEmpty) return;

    print('🎨 RunwayPainter: Painting ${runways.length} runways, canvas size: $size');

    final paint = Paint()
      ..color = runwayColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Center of the canvas
    final center = Offset(size.width / 2, size.height / 2);
    
    // Base scale for runway length visualization
    // Adjust scale based on zoom level
    final zoomScale = math.pow(2, (zoom - 13) / 2);
    final feetPerPixel = (8200 / size.width) / zoomScale; // 8200ft (2500m) reference length
    
    // Track drawn runways to avoid duplicates
    final drawnRunways = <String>{};
    
    for (final runway in runways) {
      // Skip closed runways
      if (runway.closed) {
        print('🎨 Skipping closed runway: ${runway.designation}');
        continue;
      }
      
      // Use the low end heading as the primary heading
      final heading = runway.leHeadingDegT;
      if (heading == null) {
        print('🎨 Skipping runway ${runway.designation} - no heading data');
        continue;
      }

      // Create a unique key for this runway including length
      final runwayKey = '${heading.round()}-${runway.lengthFt}';
      
      // Skip if we've already drawn this exact runway
      if (drawnRunways.contains(runwayKey)) {
        print('🎨 Skipping duplicate runway: ${runway.designation}');
        continue;
      }
      drawnRunways.add(runwayKey);
      
      print('🎨 Drawing runway ${runway.designation} heading: $heading°, length: ${runway.lengthFt}ft');

      // Calculate actual runway length in pixels
      final runwayLengthPx = runway.lengthFt / feetPerPixel;
      
      // Cap maximum visual length to prevent overflow
      final visualLength = math.min(runwayLengthPx, size.width * 0.8);

      // Convert heading to radians
      final radians = heading * (math.pi / 180);

      // Calculate runway endpoints
      // Rotate by -90 degrees because 0 degrees is north, not east
      final adjustedRadians = radians - (math.pi / 2);
      
      final dx = math.cos(adjustedRadians) * visualLength / 2;
      final dy = math.sin(adjustedRadians) * visualLength / 2;

      final start = Offset(center.dx - dx, center.dy - dy);
      final end = Offset(center.dx + dx, center.dy + dy);

      // Vary stroke width based on runway length (longer = thicker)
      final runwayPaint = Paint()
        ..color = runwayColor
        ..strokeWidth = strokeWidth + (runway.lengthFt > 6500 ? 1.0 : 0.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Draw runway line
      canvas.drawLine(start, end, runwayPaint);

      // Draw runway end markers (small perpendicular lines)
      final markerLength = visualLength * 0.1;
      final perpRadians = adjustedRadians + (math.pi / 2);
      final mdx = math.cos(perpRadians) * markerLength / 2;
      final mdy = math.sin(perpRadians) * markerLength / 2;

      // Start end marker
      canvas.drawLine(
        Offset(start.dx - mdx, start.dy - mdy),
        Offset(start.dx + mdx, start.dy + mdy),
        paint,
      );

      // End marker
      canvas.drawLine(
        Offset(end.dx - mdx, end.dy - mdy),
        Offset(end.dx + mdx, end.dy + mdy),
        paint,
      );
      
      // Add length label for longer runways at higher zoom levels
      if (zoom >= 14 && runway.lengthFt >= 3000) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: runway.lengthFormatted,
            style: TextStyle(
              color: runwayColor.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        // Position text along the runway
        final midpoint = Offset(
          (start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2,
        );
        
        // Rotate text to align with runway
        canvas.save();
        canvas.translate(midpoint.dx, midpoint.dy);
        
        // Adjust rotation so text is always readable (not upside down)
        var textAngle = adjustedRadians;
        if (textAngle > math.pi / 2 || textAngle < -math.pi / 2) {
          textAngle += math.pi;
        }
        
        canvas.rotate(textAngle);
        textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(RunwayPainter oldDelegate) {
    return oldDelegate.runways != runways ||
        oldDelegate.zoom != zoom ||
        oldDelegate.runwayColor != runwayColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class RunwayVisualization extends StatelessWidget {
  final List<Runway> runways;
  final double zoom;
  final double size;
  final Color? runwayColor;

  const RunwayVisualization({
    super.key,
    required this.runways,
    required this.zoom,
    this.size = 80.0,
    this.runwayColor,
  });

  @override
  Widget build(BuildContext context) {
    print('🎨 RunwayVisualization build: ${runways.length} runways, zoom: $zoom, size: $size');
    
    if (runways.isEmpty || zoom < 13) {
      print('🎨 RunwayVisualization: Not showing (empty: ${runways.isEmpty}, zoom < 13: ${zoom < 13})');
      return const SizedBox.shrink();
    }

    print('🎨 RunwayVisualization: Creating CustomPaint widget');
    return CustomPaint(
      size: Size(size, size),
      painter: RunwayPainter(
        runways: runways,
        zoom: zoom,
        runwayColor: runwayColor ?? Colors.black87,
        strokeWidth: zoom >= 15 ? 3.0 : 2.0,
      ),
    );
  }
}