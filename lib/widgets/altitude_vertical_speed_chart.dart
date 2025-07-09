import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AltitudeVerticalSpeedChart extends StatelessWidget {
  final List<double> altitudeData;
  final List<double> verticalSpeedData;
  final double? currentAltitude;
  final double? minAltitude;
  final double? maxAltitude;

  const AltitudeVerticalSpeedChart({
    super.key,
    required this.altitudeData,
    required this.verticalSpeedData,
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
    
    // Calculate min and max for altitude Y axis
    final minAltY = minAltitude ?? (altitudeData.isNotEmpty ? altitudeData.reduce((a, b) => a < b ? a : b) - 50 : 0);
    final maxAltY = maxAltitude ?? (altitudeData.isNotEmpty ? altitudeData.reduce((a, b) => a > b ? a : b) + 50 : 1000);
    
    // Calculate min and max for vertical speed Y axis (in m/s)
    final vsData = verticalSpeedData.isNotEmpty ? verticalSpeedData : List.filled(altitudeData.length, 0.0);
    final minVS = vsData.reduce((a, b) => a < b ? a : b) - 0.5;
    final maxVS = vsData.reduce((a, b) => a > b ? a : b) + 0.5;

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
            leftTitles: AxisTitles(
              axisNameWidget: const Text('Altitude (m)', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: const Text('V/S (m/s)', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  // Map the right axis to vertical speed range
                  final vsValue = minVS + (value - minAltY) * (maxVS - minVS) / (maxAltY - minAltY);
                  return Text(
                    vsValue.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10, color: Colors.green),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Time (minutes)', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                interval: altitudeData.length > 10 ? altitudeData.length / 5 : 1,
                getTitlesWidget: (value, meta) {
                  final minutes = value.toInt();
                  return Text(
                    minutes.toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: altitudeData.length.toDouble() - 1,
          minY: minAltY,
          maxY: maxAltY,
          lineBarsData: [
            // Altitude line
            LineChartBarData(
              spots: altitudeData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              preventCurveOverShooting: true,
              color: isDark ? Colors.blue[300] : Colors.blue[600],
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: (isDark ? Colors.blue[300] : Colors.blue[600])!.withValues(alpha: 0.15),
              ),
            ),
            // Vertical speed line (mapped to altitude scale)
            LineChartBarData(
              spots: vsData.asMap().entries.map((entry) {
                // Map vertical speed to altitude scale for display
                final mappedValue = minAltY + (entry.value - minVS) * (maxAltY - minAltY) / (maxVS - minVS);
                return FlSpot(entry.key.toDouble(), mappedValue);
              }).toList(),
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.green,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: [5, 5], // Dashed line to distinguish from altitude
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBorder: const BorderSide(color: Colors.transparent),
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  if (barSpot.barIndex == 0) {
                    // Altitude
                    return LineTooltipItem(
                      '${flSpot.y.toStringAsFixed(0)} m',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else {
                    // Vertical speed - convert back from mapped value
                    final vsValue = vsData[flSpot.x.toInt()];
                    return LineTooltipItem(
                      'V/S: ${vsValue.toStringAsFixed(1)} m/s',
                      const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }
}