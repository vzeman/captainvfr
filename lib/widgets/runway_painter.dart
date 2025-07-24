import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/runway.dart';
import '../utils/magnetic_declination_simple.dart';

class RunwayPainter extends CustomPainter {
  final List<Runway> runways;
  final double zoom;
  final Color runwayColor;
  final double strokeWidth;
  final double? latitude; // Airport latitude for accurate scale calculation
  final double? longitude; // Airport longitude for offset calculations

  RunwayPainter({
    required this.runways,
    required this.zoom,
    this.runwayColor = Colors.black87,
    this.strokeWidth = 2.0,
    this.latitude,
    this.longitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (runways.isEmpty) return;

    // Get airport coordinates for offset calculations
    final airportLat = latitude ?? runways.first.leLatitude ?? 45.0;
    final airportLon = longitude ?? runways.first.leLongitude ?? 0.0;


    final paint = Paint()
      ..color = runwayColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Center of the canvas (represents airport reference point)
    final center = Offset(size.width / 2, size.height / 2);
    
    // Calculate accurate scale using Web Mercator projection formula
    // Use average latitude of runways if not provided
    final lat = latitude ?? runways.first.leLatitude ?? 45.0; // Default to 45° if no data
    
    // Standard Web Mercator formula: meters per pixel at given latitude and zoom
    const double earthCircumference = 40075016.686; // meters at equator
    final double metersPerPixel = earthCircumference * math.cos(lat * math.pi / 180) / math.pow(2, zoom + 8);
    
    // Convert to feet per pixel
    const double feetPerMeter = 3.28084;
    final double feetPerPixel = metersPerPixel * feetPerMeter;
    
    // Track drawn runways to avoid duplicates - use runway ID for uniqueness
    final drawnRunways = <int>{};
    // int drawnCount = 0; // Not currently used
    
    for (final runway in runways) {
      // Skip closed runways
      if (runway.closed) continue;
      
      // Skip if we've already drawn this runway (by ID)
      if (drawnRunways.contains(runway.id)) continue;
      drawnRunways.add(runway.id);
      
      // Use the low end heading as the primary heading
      final magneticHeading = runway.leHeadingDegT;
      if (magneticHeading == null) continue;
      
      // Convert magnetic heading to true heading using magnetic declination
      final declination = MagneticDeclinationSimple.calculate(
        airportLat,
        airportLon,
      );
      // Apply declination: True = Magnetic + Declination
      final heading = MagneticDeclinationSimple.magneticToTrue(magneticHeading, declination);

      // drawnCount++;

      // Calculate actual runway length in pixels
      final runwayLengthPx = runway.lengthFt / feetPerPixel;
      
      // Calculate runway endpoints
      Offset start, end;
      
      if (runway.leLatitude != null && runway.leLongitude != null) {
        // Calculate LE (low end) position offset from airport center
        final leLatDiff = runway.leLatitude! - airportLat;
        final leLonDiff = runway.leLongitude! - airportLon;
        
        // Convert lat/lon differences to meters
        const metersPerDegreeLat = 111319.0;
        final metersPerDegreeLon = 111319.0 * math.cos(airportLat * math.pi / 180);
        
        final leOffsetMetersNorth = leLatDiff * metersPerDegreeLat;
        final leOffsetMetersEast = leLonDiff * metersPerDegreeLon;
        
        // Convert to pixels
        final leOffsetPxX = leOffsetMetersEast / metersPerPixel;
        final leOffsetPxY = -leOffsetMetersNorth / metersPerPixel;
        
        // LE position is the start of the runway
        start = Offset(center.dx + leOffsetPxX, center.dy + leOffsetPxY);
        
        // Calculate HE (high end) position
        if (runway.heLatitude != null && runway.heLongitude != null) {
          // If we have HE coordinates, use them directly
          final heLatDiff = runway.heLatitude! - airportLat;
          final heLonDiff = runway.heLongitude! - airportLon;
          
          final heOffsetMetersNorth = heLatDiff * metersPerDegreeLat;
          final heOffsetMetersEast = heLonDiff * metersPerDegreeLon;
          
          final heOffsetPxX = heOffsetMetersEast / metersPerPixel;
          final heOffsetPxY = -heOffsetMetersNorth / metersPerPixel;
          
          end = Offset(center.dx + heOffsetPxX, center.dy + heOffsetPxY);
        } else {
          // Calculate HE position from LE position + heading + length
          final headingRad = heading * (math.pi / 180);
          final lengthM = runway.lengthFt * 0.3048;
          
          // Calculate offset from LE to HE
          final offsetN = math.cos(headingRad) * lengthM;
          final offsetE = math.sin(headingRad) * lengthM;
          
          final offsetPxX = offsetE / metersPerPixel;
          final offsetPxY = -offsetN / metersPerPixel;
          
          end = Offset(start.dx + offsetPxX, start.dy + offsetPxY);
        }
      } else {
        // Fallback: center the runway on airport
        final radians = heading * (math.pi / 180);
        final adjustedRadians = radians - (math.pi / 2);
        
        final dx = math.cos(adjustedRadians) * runwayLengthPx / 2;
        final dy = math.sin(adjustedRadians) * runwayLengthPx / 2;
        
        start = Offset(center.dx - dx, center.dy - dy);
        end = Offset(center.dx + dx, center.dy + dy);
      }

      // Calculate runway width in pixels
      double runwayStrokeWidth = strokeWidth;
      if (runway.widthFt != null && runway.widthFt! > 0) {
        // Convert runway width to pixels using same scale
        final widthPx = runway.widthFt! / feetPerPixel;
        // Ensure minimum visibility
        runwayStrokeWidth = math.max(1.0, widthPx);
      }
      
      final runwayPaint = Paint()
        ..color = runwayColor
        ..strokeWidth = runwayStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt; // Use butt cap for exact length

      // Draw runway line
      canvas.drawLine(start, end, runwayPaint);

      // Draw runway end markers (small perpendicular lines)
      final markerLength = runwayLengthPx * 0.1;
      // Calculate perpendicular angle from the runway direction
      final runwayAngle = math.atan2(end.dy - start.dy, end.dx - start.dx);
      final perpRadians = runwayAngle + (math.pi / 2);
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
        var textAngle = runwayAngle;
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
  final double? latitude;
  final double? longitude;

  const RunwayVisualization({
    super.key,
    required this.runways,
    required this.zoom,
    this.size = 80.0,
    this.runwayColor,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    if (runways.isEmpty || zoom < 5) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: Size(size, size),
      painter: RunwayPainter(
        runways: runways,
        zoom: zoom,
        runwayColor: runwayColor ?? Colors.black87,
        strokeWidth: 1.0, // Base width, will be scaled based on actual runway width
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }
}