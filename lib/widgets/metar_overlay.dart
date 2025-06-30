import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/airport.dart';

class MetarOverlay extends StatelessWidget {
  final List<Airport> airports;
  final bool showMetarLayer;
  final Function(Airport)? onAirportTap;

  const MetarOverlay({
    super.key,
    required this.airports,
    required this.showMetarLayer,
    this.onAirportTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!showMetarLayer) return const SizedBox.shrink();

    final airportsWithMetar = airports.where((airport) => airport.rawMetar != null).toList();

    return MarkerLayer(
      markers: [
        ...airportsWithMetar.map((airport) => _buildMetarMarker(airport)),
      ],
    );
  }

  Marker _buildMetarMarker(Airport airport) {
    final windData = _parseWindFromMetar(airport.rawMetar!);
    final flightCategory = airport.flightCategory ?? 'VFR';

    return Marker(
      point: airport.position,
      width: 120,
      height: 120,
      child: GestureDetector(
        onTap: () => onAirportTap?.call(airport),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Weather condition indicator (background circle)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getFlightCategoryColor(flightCategory),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                _getWeatherIcon(airport.rawMetar!),
                size: 12,
                color: Colors.white,
              ),
            ),
            // Wind arrow
            if (windData != null)
              Transform.rotate(
                angle: (windData.direction - 90) * math.pi / 180, // Rotate to point in wind direction
                child: CustomPaint(
                  size: const Size(60, 60),
                  painter: WindArrowPainter(
                    windSpeed: windData.speed,
                    gustSpeed: windData.gust,
                  ),
                ),
              ),
            // Wind speed text
            if (windData != null)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${windData.speed}${windData.gust != null ? 'G${windData.gust}' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getFlightCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'VFR':
        return Colors.green;
      case 'MVFR':
        return Colors.blue;
      case 'IFR':
        return Colors.red;
      case 'LIFR':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getWeatherIcon(String metar) {
    // Check for various weather conditions in METAR
    if (metar.contains('TS')) return Icons.flash_on; // Thunderstorm
    if (metar.contains('SN')) return Icons.ac_unit; // Snow
    if (metar.contains('RA')) return Icons.grain; // Rain
    if (metar.contains('FG') || metar.contains('BR')) return Icons.cloud; // Fog/Mist
    if (metar.contains('OVC') || metar.contains('BKN')) return Icons.cloud; // Overcast/Broken
    if (metar.contains('SCT') || metar.contains('FEW')) return Icons.wb_cloudy; // Scattered/Few
    return Icons.wb_sunny; // Clear
  }

  WindData? _parseWindFromMetar(String metar) {
    // Parse wind from METAR string (e.g., "36010KT" or "36010G20KT")
    final windMatch = RegExp(r'\b(\d{3}|VRB)(\d{2,3})(G(\d{2,3}))?KT\b').firstMatch(metar);
    if (windMatch == null) return null;

    final directionStr = windMatch.group(1);
    if (directionStr == 'VRB') return null; // Skip variable wind for arrow display

    final direction = int.tryParse(directionStr!);
    final speed = int.tryParse(windMatch.group(2)!);
    final gust = windMatch.group(4) != null ? int.tryParse(windMatch.group(4)!) : null;

    if (direction == null || speed == null) return null;

    return WindData(direction: direction, speed: speed, gust: gust);
  }
}

class WindData {
  final int direction;
  final int speed;
  final int? gust;

  WindData({required this.direction, required this.speed, this.gust});
}

class WindArrowPainter extends CustomPainter {
  final int windSpeed;
  final int? gustSpeed;

  WindArrowPainter({required this.windSpeed, this.gustSpeed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    // Calculate arrow length based on wind speed (min 15, max 40)
    final baseLength = math.min(40, math.max(15, windSpeed * 1.5));
    final arrowLength = baseLength;

    // Draw main arrow shaft
    final arrowEnd = Offset(center.dx, center.dy - arrowLength);
    canvas.drawLine(center, arrowEnd, paint);

    // Draw arrowhead
    final arrowHeadLength = 8.0;
    final arrowHeadAngle = math.pi / 6; // 30 degrees

    final leftArrowHead = Offset(
      arrowEnd.dx - arrowHeadLength * math.sin(arrowHeadAngle),
      arrowEnd.dy + arrowHeadLength * math.cos(arrowHeadAngle),
    );

    final rightArrowHead = Offset(
      arrowEnd.dx + arrowHeadLength * math.sin(arrowHeadAngle),
      arrowEnd.dy + arrowHeadLength * math.cos(arrowHeadAngle),
    );

    canvas.drawLine(arrowEnd, leftArrowHead, paint);
    canvas.drawLine(arrowEnd, rightArrowHead, paint);

    // Draw wind barbs for speed indication
    _drawWindBarbs(canvas, center, arrowEnd, windSpeed, paint);

    // If there are gusts, draw them with a different color
    if (gustSpeed != null && gustSpeed! > windSpeed) {
      final gustPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Draw additional barbs for gust speed
      _drawWindBarbs(canvas, center, arrowEnd, gustSpeed!, gustPaint, isGust: true);
    }
  }

  void _drawWindBarbs(Canvas canvas, Offset center, Offset arrowEnd, int speed, Paint paint, {bool isGust = false}) {
    // Wind barbs: full barb = 10 knots, half barb = 5 knots, pennant = 50 knots
    final barbLength = isGust ? 6.0 : 8.0;
    final barbAngle = math.pi / 3; // 60 degrees

    int remainingSpeed = speed;
    double barbPosition = 0.7; // Start barbs at 70% of arrow length

    // Draw pennants (50 knots each)
    while (remainingSpeed >= 50 && barbPosition > 0.2) {
      final barbCenter = Offset(
        center.dx,
        center.dy - (arrowEnd.dy - center.dy) * barbPosition,
      );

      // Draw pennant (triangle)
      final pennantTip = Offset(
        barbCenter.dx + barbLength * 1.5 * math.sin(barbAngle),
        barbCenter.dy - barbLength * 1.5 * math.cos(barbAngle),
      );

      final pennantBase = Offset(
        barbCenter.dx,
        barbCenter.dy - barbLength * 0.7,
      );

      final path = ui.Path()
        ..moveTo(barbCenter.dx, barbCenter.dy)
        ..lineTo(pennantTip.dx, pennantTip.dy)
        ..lineTo(pennantBase.dx, pennantBase.dy)
        ..close();

      canvas.drawPath(path, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;

      remainingSpeed -= 50;
      barbPosition -= 0.15;
    }

    // Draw full barbs (10 knots each)
    while (remainingSpeed >= 10 && barbPosition > 0.2) {
      final barbCenter = Offset(
        center.dx,
        center.dy - (arrowEnd.dy - center.dy) * barbPosition,
      );

      final barbEnd = Offset(
        barbCenter.dx + barbLength * math.sin(barbAngle),
        barbCenter.dy - barbLength * math.cos(barbAngle),
      );

      canvas.drawLine(barbCenter, barbEnd, paint);

      remainingSpeed -= 10;
      barbPosition -= 0.1;
    }

    // Draw half barb (5 knots)
    if (remainingSpeed >= 5 && barbPosition > 0.2) {
      final barbCenter = Offset(
        center.dx,
        center.dy - (arrowEnd.dy - center.dy) * barbPosition,
      );

      final barbEnd = Offset(
        barbCenter.dx + (barbLength * 0.6) * math.sin(barbAngle),
        barbCenter.dy - (barbLength * 0.6) * math.cos(barbAngle),
      );

      canvas.drawLine(barbCenter, barbEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
