import 'dart:math' as math;
import 'package:flutter/material.dart';

class CompassWidget extends StatelessWidget {
  final double heading;
  final double? targetHeading;
  final double size;
  final Color primaryColor;
  final Color accentColor;

  const CompassWidget({
    super.key,
    required this.heading,
    this.targetHeading,
    this.size = 80,
    this.primaryColor = Colors.white,
    this.accentColor = const Color(0xFF448AFF),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: CompassPainter(
              heading: heading,
              targetHeading: targetHeading,
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${heading.toStringAsFixed(0)}°',
          style: TextStyle(
            color: primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (targetHeading != null)
          Text(
            'Target: ${targetHeading!.toStringAsFixed(0)}°',
            style: TextStyle(color: accentColor, fontSize: 11),
          ),
      ],
    );
  }
}

class CompassPainter extends CustomPainter {
  final double heading;
  final double? targetHeading;
  final Color primaryColor;
  final Color accentColor;

  CompassPainter({
    required this.heading,
    this.targetHeading,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer circle
    final outerCirclePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, outerCirclePaint);

    // Draw compass marks
    final markPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    for (int i = 0; i < 360; i += 30) {
      final angle = (i - 90) * math.pi / 180;
      final isCardinal = i % 90 == 0;
      final markLength = isCardinal ? radius * 0.15 : radius * 0.1;
      final startRadius = radius - markLength;

      final start = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 2) * math.cos(angle),
        center.dy + (radius - 2) * math.sin(angle),
      );

      if (isCardinal) {
        markPaint.strokeWidth = 2;
      } else {
        markPaint.strokeWidth = 1;
      }

      canvas.drawLine(start, end, markPaint);
    }

    // Draw cardinal direction letters
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final directions = ['N', 'E', 'S', 'W'];
    final angles = [0, 90, 180, 270];

    for (int i = 0; i < directions.length; i++) {
      final angle = (angles[i] - 90) * math.pi / 180;
      final letterRadius = radius * 0.7;

      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: primaryColor,
          fontSize: size.width * 0.12,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      final offset = Offset(
        center.dx + letterRadius * math.cos(angle) - textPainter.width / 2,
        center.dy + letterRadius * math.sin(angle) - textPainter.height / 2,
      );

      textPainter.paint(canvas, offset);
    }

    // Draw target heading indicator if provided
    if (targetHeading != null) {
      final targetAngle = (targetHeading! - 90) * math.pi / 180;
      final targetPaint = Paint()
        ..color = accentColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      // Draw target line
      final targetStart = Offset(
        center.dx + (radius * 0.4) * math.cos(targetAngle),
        center.dy + (radius * 0.4) * math.sin(targetAngle),
      );
      final targetEnd = Offset(
        center.dx + (radius - 5) * math.cos(targetAngle),
        center.dy + (radius - 5) * math.sin(targetAngle),
      );

      canvas.drawLine(targetStart, targetEnd, targetPaint);

      // Draw target marker - small triangle
      final targetMarkerPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;

      final markerPath = Path();
      final markerTip = Offset(
        center.dx + (radius - 4) * math.cos(targetAngle),
        center.dy + (radius - 4) * math.sin(targetAngle),
      );
      final markerBase1 = Offset(
        center.dx + (radius - 12) * math.cos(targetAngle + 0.15),
        center.dy + (radius - 12) * math.sin(targetAngle + 0.15),
      );
      final markerBase2 = Offset(
        center.dx + (radius - 12) * math.cos(targetAngle - 0.15),
        center.dy + (radius - 12) * math.sin(targetAngle - 0.15),
      );

      markerPath.moveTo(markerTip.dx, markerTip.dy);
      markerPath.lineTo(markerBase1.dx, markerBase1.dy);
      markerPath.lineTo(markerBase2.dx, markerBase2.dy);
      markerPath.close();

      canvas.drawPath(markerPath, targetMarkerPaint);
    }

    // Draw current heading indicator - simple green arrow
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading * math.pi / 180);

    // Draw green arrow
    final arrowPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.fill;

    final arrowPath = Path();

    // Arrow pointing up (north when not rotated)
    final arrowLength = radius * 0.6;
    final arrowWidth = 8.0;

    // Arrow tip
    arrowPath.moveTo(0, -arrowLength);
    // Right side
    arrowPath.lineTo(arrowWidth, -arrowLength + arrowWidth * 2);
    // Arrow shaft right
    arrowPath.lineTo(arrowWidth * 0.5, -arrowLength + arrowWidth * 2);
    arrowPath.lineTo(arrowWidth * 0.5, 0);
    // Bottom
    arrowPath.lineTo(-arrowWidth * 0.5, 0);
    // Arrow shaft left
    arrowPath.lineTo(-arrowWidth * 0.5, -arrowLength + arrowWidth * 2);
    // Left side
    arrowPath.lineTo(-arrowWidth, -arrowLength + arrowWidth * 2);
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);

    // Add small white circle at center
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 3, centerPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.targetHeading != targetHeading;
  }
}
