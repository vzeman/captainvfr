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

    final paint = Paint()
      ..color = runwayColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Center of the canvas
    final center = Offset(size.width / 2, size.height / 2);
    
    // Base length for runway visualization (will scale with zoom)
    final baseLength = size.width * 0.4;
    
    // Track drawn runways to avoid duplicates
    final drawnRunways = <String>{};
    
    for (final runway in runways) {
      // Skip closed runways
      if (runway.closed) continue;
      
      // Use the low end heading as the primary heading
      final heading = runway.leHeadingDegT;
      if (heading == null) continue;

      // Create a unique key for this runway orientation
      // Round to nearest 10 degrees to group similar runways
      final roundedHeading = (heading / 10).round() * 10;
      final runwayKey = '$roundedHeading';
      
      // Skip if we've already drawn a runway with similar heading
      if (drawnRunways.contains(runwayKey)) continue;
      drawnRunways.add(runwayKey);

      // Convert heading to radians
      final radians = heading * (math.pi / 180);

      // Calculate runway endpoints
      // Rotate by -90 degrees because 0 degrees is north, not east
      final adjustedRadians = radians - (math.pi / 2);
      
      final dx = math.cos(adjustedRadians) * baseLength / 2;
      final dy = math.sin(adjustedRadians) * baseLength / 2;

      final start = Offset(center.dx - dx, center.dy - dy);
      final end = Offset(center.dx + dx, center.dy + dy);

      // Draw runway line
      canvas.drawLine(start, end, paint);

      // Draw runway end markers (small perpendicular lines)
      final markerLength = baseLength * 0.1;
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
    if (runways.isEmpty || zoom < 13) {
      return const SizedBox.shrink();
    }

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