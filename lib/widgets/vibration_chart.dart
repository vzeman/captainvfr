import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class VibrationChart extends StatelessWidget {
  final List<double> vibrationData; // Vibration intensity values
  final double? currentVibration;
  final double? maxVibration;

  const VibrationChart({
    super.key,
    required this.vibrationData,
    this.currentVibration,
    this.maxVibration,
  });

  @override
  Widget build(BuildContext context) {
    if (vibrationData.isEmpty) {
      return const Center(
        child: Text(
          'No vibration data available\nStart tracking to see vibration data',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Calculate min and max for the Y axis
    final minY = 0.0;
    final maxY = maxVibration != null 
        ? maxVibration! * 1.2 
        : (vibrationData.isNotEmpty ? vibrationData.reduce((a, b) => a > b ? a : b) * 1.2 : 1.0);

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
                interval: (vibrationData.length / 4).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < vibrationData.length) {
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
                interval: (maxY / 4).clamp(0.1, double.infinity),
                getTitlesWidget: (value, meta) {
                  return Text(value.toStringAsFixed(1));
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
          maxX: vibrationData.isNotEmpty ? (vibrationData.length - 1).toDouble() : 1,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: vibrationData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              color: Colors.orange,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withValues(alpha: 0.2),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> spots) {
                return spots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(2)} g\n${(spot.x / 60).toStringAsFixed(1)} min',
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
