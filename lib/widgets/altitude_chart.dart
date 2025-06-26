import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AltitudeChart extends StatelessWidget {
  final List<double> altitudeData;
  final double? currentAltitude;
  final double? minAltitude;
  final double? maxAltitude;

  const AltitudeChart({
    super.key,
    required this.altitudeData,
    this.currentAltitude,
    this.minAltitude,
    this.maxAltitude,
  });

  @override
  Widget build(BuildContext context) {
    if (altitudeData.isEmpty) {
      return const Center(
        child: Text(
          'No altitude data available\nStart tracking to see altitude changes',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Calculate min and max for the Y axis
    final minY = minAltitude ?? (altitudeData.isNotEmpty ? altitudeData.reduce((a, b) => a < b ? a : b) - 50 : 0);
    final maxY = maxAltitude ?? (altitudeData.isNotEmpty ? altitudeData.reduce((a, b) => a > b ? a : b) + 50 : 1000);

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
                interval: (altitudeData.length / 4).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < altitudeData.length) {
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
                  return Text('${value.toInt()}m');
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
          maxX: altitudeData.length > 0 ? (altitudeData.length - 1).toDouble() : 1,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: altitudeData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Theme.of(context).cardColor,
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  return LineTooltipItem(
                    '${touchedSpot.y.toStringAsFixed(1)} m',
                    TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
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
