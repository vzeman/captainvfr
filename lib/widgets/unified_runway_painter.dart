import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/runway.dart';
import '../models/openaip_runway.dart';
import '../models/unified_runway.dart';
import '../utils/magnetic_declination_simple.dart';
import '../utils/magnetic_declination_cache.dart';
import '../utils/geo_constants.dart';

/// Unified runway painter that can handle multiple data sources
class UnifiedRunwayPainter extends CustomPainter {
  final List<UnifiedRunway> runways;
  final double zoom;
  final Color runwayColor;
  final double strokeWidth;
  final double? latitude;
  final double? longitude;

  UnifiedRunwayPainter({
    required this.runways,
    required this.zoom,
    this.runwayColor = Colors.black87,
    this.strokeWidth = 2.0,
    this.latitude,
    this.longitude,
  });

  /// Create from OurAirports runway data
  factory UnifiedRunwayPainter.fromRunways({
    required List<Runway> runways,
    required double zoom,
    Color? runwayColor,
    double? strokeWidth,
    double? latitude,
    double? longitude,
  }) {
    final unifiedRunways = runways.map((r) => UnifiedRunway.fromOurAirports(r)).toList();
    return UnifiedRunwayPainter(
      runways: unifiedRunways,
      zoom: zoom,
      runwayColor: runwayColor ?? Colors.black87,
      strokeWidth: strokeWidth ?? 2.0,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Create from OpenAIP runway data
  factory UnifiedRunwayPainter.fromOpenAIPRunways({
    required List<OpenAIPRunway> runways,
    required String airportIdent,
    required double zoom,
    Color? runwayColor,
    double? strokeWidth,
    double? latitude,
    double? longitude,
  }) {
    final unifiedRunways = runways.map((r) => UnifiedRunway.fromOpenAIPRunway(
      r,
      airportIdent,
      airportLat: latitude,
      airportLon: longitude,
    )).toList();
    return UnifiedRunwayPainter(
      runways: unifiedRunways,
      zoom: zoom,
      runwayColor: runwayColor ?? Colors.black87,
      strokeWidth: strokeWidth ?? 2.0,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (runways.isEmpty) return;

    final airportLat = latitude ?? runways.first.leLatitude ?? 45.0;
    final airportLon = longitude ?? runways.first.leLongitude ?? 0.0;

    final paint = Paint()
      ..color = runwayColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Calculate scale
    final metersPerPixel = _calculateMetersPerPixel(airportLat, zoom);
    final feetPerPixel = metersPerPixel * GeoConstants.feetPerMeter;
    
    // Track drawn runways to avoid duplicates
    final drawnRunways = <String>{};
    
    for (final runway in runways) {
      // Skip closed runways
      if (runway.closed) continue;
      
      // Create unique key
      final runwayKey = '${runway.designation}-${runway.lengthFt}';
      if (drawnRunways.contains(runwayKey)) continue;
      drawnRunways.add(runwayKey);
      
      // Get heading
      final magneticHeading = runway.leHeadingDegT;
      if (magneticHeading == null) continue;
      
      // Convert magnetic to true heading (using cache for performance)
      final declination = MagneticDeclinationCache.getCached(airportLat, airportLon);
      final heading = MagneticDeclinationSimple.magneticToTrue(magneticHeading, declination);

      // Calculate runway endpoints
      final endpoints = _calculateRunwayEndpoints(
        runway: runway,
        center: center,
        heading: heading,
        airportLat: airportLat,
        airportLon: airportLon,
        metersPerPixel: metersPerPixel,
        feetPerPixel: feetPerPixel,
      );

      // Calculate runway width
      final runwayStrokeWidth = _calculateRunwayWidth(
        runway.widthFt,
        feetPerPixel,
        strokeWidth,
      );
      
      final runwayPaint = Paint()
        ..color = runwayColor
        ..strokeWidth = runwayStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      // Draw runway
      canvas.drawLine(endpoints.start, endpoints.end, runwayPaint);

      // Draw end markers
      _drawEndMarkers(
        canvas: canvas,
        start: endpoints.start,
        end: endpoints.end,
        markerLength: endpoints.lengthPx * 0.1,
        paint: paint,
      );
      
      // Draw runway designation labels
      if (zoom >= 8) {
        _drawRunwayDesignationLabels(
          canvas: canvas,
          runway: runway,
          start: endpoints.start,
          end: endpoints.end,
          angle: endpoints.angle,
          color: runwayColor,
        );
      }
      
      // Draw length label
      if (zoom >= 14 && runway.lengthFt >= 3000) {
        _drawLengthLabel(
          canvas: canvas,
          start: endpoints.start,
          end: endpoints.end,
          lengthText: _formatLength(runway.lengthFt),
          angle: endpoints.angle,
          color: runwayColor,
        );
      }
    }
  }

  double _calculateMetersPerPixel(double latitude, double zoom) {
    return GeoConstants.earthCircumferenceMeters * 
           math.cos(latitude * math.pi / 180) / 
           math.pow(2, zoom + 8);
  }

  ({Offset start, Offset end, double lengthPx, double angle}) _calculateRunwayEndpoints({
    required UnifiedRunway runway,
    required Offset center,
    required double heading,
    required double airportLat,
    required double airportLon,
    required double metersPerPixel,
    required double feetPerPixel,
  }) {
    final runwayLengthPx = runway.lengthFt / feetPerPixel;
    
    if (runway.leLatitude != null && runway.leLongitude != null) {
      // Calculate from actual coordinates
      final leLatDiff = runway.leLatitude! - airportLat;
      final leLonDiff = runway.leLongitude! - airportLon;
      
      final metersPerDegreeLon = GeoConstants.metersPerDegreeLat * 
                                 math.cos(airportLat * math.pi / 180);
      
      final leOffsetMetersNorth = leLatDiff * GeoConstants.metersPerDegreeLat;
      final leOffsetMetersEast = leLonDiff * metersPerDegreeLon;
      
      final leOffsetPxX = leOffsetMetersEast / metersPerPixel;
      final leOffsetPxY = -leOffsetMetersNorth / metersPerPixel;
      
      final start = Offset(center.dx + leOffsetPxX, center.dy + leOffsetPxY);
      
      Offset end;
      if (runway.heLatitude != null && runway.heLongitude != null) {
        // Use actual HE coordinates
        final heLatDiff = runway.heLatitude! - airportLat;
        final heLonDiff = runway.heLongitude! - airportLon;
        
        final heOffsetMetersNorth = heLatDiff * GeoConstants.metersPerDegreeLat;
        final heOffsetMetersEast = heLonDiff * metersPerDegreeLon;
        
        final heOffsetPxX = heOffsetMetersEast / metersPerPixel;
        final heOffsetPxY = -heOffsetMetersNorth / metersPerPixel;
        
        end = Offset(center.dx + heOffsetPxX, center.dy + heOffsetPxY);
      } else {
        // Calculate HE from LE + heading + length
        final headingRad = heading * (math.pi / 180);
        final lengthM = runway.lengthFt * GeoConstants.metersPerFoot;
        
        final offsetN = math.cos(headingRad) * lengthM;
        final offsetE = math.sin(headingRad) * lengthM;
        
        final offsetPxX = offsetE / metersPerPixel;
        final offsetPxY = -offsetN / metersPerPixel;
        
        end = Offset(start.dx + offsetPxX, start.dy + offsetPxY);
      }
      
      final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
      return (start: start, end: end, lengthPx: runwayLengthPx, angle: angle);
    } else {
      // Fallback: center the runway
      final radians = heading * (math.pi / 180);
      final adjustedRadians = radians - (math.pi / 2);
      
      final dx = math.cos(adjustedRadians) * runwayLengthPx / 2;
      final dy = math.sin(adjustedRadians) * runwayLengthPx / 2;
      
      final start = Offset(center.dx - dx, center.dy - dy);
      final end = Offset(center.dx + dx, center.dy + dy);
      
      return (start: start, end: end, lengthPx: runwayLengthPx, angle: adjustedRadians);
    }
  }

  double _calculateRunwayWidth(int? widthFt, double feetPerPixel, double defaultWidth) {
    if (widthFt != null && widthFt > 0) {
      final widthPx = widthFt / feetPerPixel;
      return math.max(1.0, widthPx);
    }
    return defaultWidth;
  }

  void _drawEndMarkers({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double markerLength,
    required Paint paint,
  }) {
    final runwayAngle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final perpRadians = runwayAngle + (math.pi / 2);
    final mdx = math.cos(perpRadians) * markerLength / 2;
    final mdy = math.sin(perpRadians) * markerLength / 2;

    // Start marker
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

  void _drawLengthLabel({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required String lengthText,
    required double angle,
    required Color color,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: lengthText,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final midpoint = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );
    
    canvas.save();
    canvas.translate(midpoint.dx, midpoint.dy);
    
    // Ensure text is readable
    var textAngle = angle;
    if (textAngle > math.pi / 2 || textAngle < -math.pi / 2) {
      textAngle += math.pi;
    }
    
    canvas.rotate(textAngle);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height - 2));
    canvas.restore();
  }

  void _drawRunwayDesignationLabels({
    required Canvas canvas,
    required UnifiedRunway runway,
    required Offset start,
    required Offset end,
    required double angle,
    required Color color,
  }) {
    // Skip if runway identifiers are empty
    if (runway.leIdent.isEmpty && runway.heIdent.isEmpty) return;
    
    // Calculate offset for labels (slightly outside runway ends)
    final labelOffset = 15.0; // Distance from runway end
    
    // Calculate positions slightly outside runway ends
    final leOffset = Offset(
      math.cos(angle + math.pi) * labelOffset,
      math.sin(angle + math.pi) * labelOffset,
    );
    final heOffset = Offset(
      math.cos(angle) * labelOffset,
      math.sin(angle) * labelOffset,
    );
    
    final leLabelPos = start + leOffset;
    final heLabelPos = end + heOffset;
    
    // Draw LE (Low End) label if available
    if (runway.leIdent.isNotEmpty) {
      _drawDesignationLabel(
        canvas: canvas,
        position: leLabelPos,
        text: runway.leIdent,
        angle: angle,
        color: color,
      );
    }
    
    // Draw HE (High End) label if available
    if (runway.heIdent.isNotEmpty) {
      _drawDesignationLabel(
        canvas: canvas,
        position: heLabelPos,
        text: runway.heIdent,
        angle: angle,
        color: color,
      );
    }
  }

  void _drawDesignationLabel({
    required Canvas canvas,
    required Offset position,
    required String text,
    required double angle,
    required Color color,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.9),
              offset: const Offset(0.5, 0.5),
              blurRadius: 1.5,
            ),
            Shadow(
              color: Colors.white.withValues(alpha: 0.6),
              offset: const Offset(-0.5, -0.5),
              blurRadius: 1.0,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    canvas.save();
    canvas.translate(position.dx, position.dy);
    
    // Ensure text is readable (flip if upside down)
    var textAngle = angle;
    if (textAngle > math.pi / 2 || textAngle < -math.pi / 2) {
      textAngle += math.pi;
    }
    
    canvas.rotate(textAngle);
    
    // Add a subtle background for better contrast
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    final padding = 2.0;
    final backgroundRect = Rect.fromCenter(
      center: Offset(0, 0),
      width: textPainter.width + padding * 2,
      height: textPainter.height + padding * 2,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(2.0)),
      backgroundPaint,
    );
    
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    canvas.restore();
  }

  String _formatLength(int lengthFt) {
    if (lengthFt >= 3280) {
      return '${(lengthFt / 3280.84).toStringAsFixed(1)}km';
    } else {
      return '${lengthFt}ft';
    }
  }

  @override
  bool shouldRepaint(UnifiedRunwayPainter oldDelegate) {
    return oldDelegate.runways != runways ||
        oldDelegate.zoom != zoom ||
        oldDelegate.runwayColor != runwayColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Widget wrapper for the unified runway painter
class UnifiedRunwayVisualization extends StatelessWidget {
  final List<Runway>? runways;
  final List<OpenAIPRunway>? openAIPRunways;
  final String airportIdent;
  final double zoom;
  final double size;
  final Color? runwayColor;
  final double? latitude;
  final double? longitude;

  const UnifiedRunwayVisualization({
    super.key,
    this.runways,
    this.openAIPRunways,
    required this.airportIdent,
    required this.zoom,
    this.size = 80.0,
    this.runwayColor,
    this.latitude,
    this.longitude,
  }) : assert(runways != null || openAIPRunways != null, 
              'Either runways or openAIPRunways must be provided');

  @override
  Widget build(BuildContext context) {
    if ((runways?.isEmpty ?? true) && (openAIPRunways?.isEmpty ?? true) || zoom < GeoConstants.minZoomForRunways) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: Size(size, size),
      painter: runways != null 
        ? UnifiedRunwayPainter.fromRunways(
            runways: runways!,
            zoom: zoom,
            runwayColor: runwayColor ?? Colors.black87,
            strokeWidth: 1.0,
            latitude: latitude,
            longitude: longitude,
          )
        : UnifiedRunwayPainter.fromOpenAIPRunways(
            runways: openAIPRunways!,
            airportIdent: airportIdent,
            zoom: zoom,
            runwayColor: runwayColor ?? Colors.black87,
            strokeWidth: 1.0,
            latitude: latitude,
            longitude: longitude,
          ),
    );
  }
}