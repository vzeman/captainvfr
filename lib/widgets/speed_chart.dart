import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SpeedChart extends StatelessWidget {
  final List<double> speedData; // In m/s
  final double? currentSpeed;
  final double? minSpeed;
  final double? maxSpeed;

  const SpeedChart({
    super.key,
    required this.speedData,
    this.currentSpeed,
    this.minSpeed,
    this.maxSpeed,
  });

  @override
  Widget build(BuildContext context) {
    if (speedData.isEmpty) {
      return const Center(
        child: Text(
          'No speed data available\nStart tracking to see speed changes',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Convert m/s to km/h for display
    final speedsKmh = speedData.map((s) => s * 3.6).toList();
    // Calculate min and max for the Y axis
    final minY = 0.0; // Always start from 0 for speed
    final maxY = maxSpeed != null 
        ? maxSpeed! * 3.6 * 1.1 
        : (speedsKmh.isNotEmpty ? speedsKmh.reduce((a, b) => a > b ? a : b) * 1.1 : 100.0);

    return Container(
      padding: const EdgeInsets.all(16),
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (speedData.length / 4).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < speedData.length) {
                    final minutes = (index / 60).floor();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('${minutes}m'),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: (maxY - minY) / 4,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}');
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          minX: 0,
          maxX: speedData.isNotEmpty ? (speedData.length - 1).toDouble() : 1,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: speedsKmh.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.toDouble());
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> spots) {
                return spots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} km/h\n${(spot.x / 60).toStringAsFixed(1)} min',
                    TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
