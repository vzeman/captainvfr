import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/app_colors.dart';

class VibrationChart extends StatelessWidget {
  final List<double> vibrationData; // Vibration intensity values
  final double? currentVibration;
  final double? maxVibration;
  final DateTime? startTimeZulu;
  final Function(int)? onPointSelected;

  const VibrationChart({
    super.key,
    required this.vibrationData,
    this.currentVibration,
    this.maxVibration,
    this.startTimeZulu,
    this.onPointSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (vibrationData.isEmpty) {
      return Center(
        child: Text(
          'No turbulence data available\nStart tracking to see turbulence data',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.tertiaryTextColor),
        ),
      );
    }

    // Always use dark theme colors since app has black background

    // Calculate min and max for the Y axis
    final minY = 0.0;
    final maxY = maxVibration != null
        ? maxVibration! * 1.2
        : (vibrationData.isNotEmpty
              ? vibrationData.reduce((a, b) => a > b ? a : b) * 1.2
              : 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      height: 320,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.sectionBorderColor.withAlpha(76),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              axisNameWidget: Text(
                'Time (minutes)',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryTextColor,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: (vibrationData.length / 4).ceilToDouble().clamp(
                  1,
                  double.infinity,
                ),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < vibrationData.length) {
                    // Assuming each data point is 1 second
                    final totalSeconds = index;
                    final minutes = totalSeconds ~/ 60;
                    final seconds = totalSeconds % 60;
                    
                    // Show time in M:SS format for first few minutes, then just minutes
                    String timeLabel;
                    if (minutes < 5 && vibrationData.length < 600) {
                      timeLabel = '$minutes:${seconds.toString().padLeft(2, '0')}';
                    } else {
                      timeLabel = '${minutes}m';
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        timeLabel,
                        style: TextStyle(
                          color: AppColors.secondaryTextColor,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                'Turbulence (g)',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryTextColor,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                interval: (maxY / 4).clamp(0.1, double.infinity),
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      color: AppColors.secondaryTextColor,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: AppColors.sectionBorderColor,
              width: 1,
            ),
          ),
          minX: 0,
          maxX: vibrationData.isNotEmpty
              ? (vibrationData.length - 1).toDouble()
              : 1,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: vibrationData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              color: AppColors.warningColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.warningColor.withAlpha(51),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
              // Handle all touch events that have a response with line bar spots
              if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                final spotIndex = response.lineBarSpots!.first.x.toInt();
                // Call for any touch event with valid response
                onPointSelected?.call(spotIndex);
              }
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpots) => AppColors.sectionBackgroundColor.withAlpha(230),
              tooltipBorderRadius: BorderRadius.circular(4),
              tooltipBorder: BorderSide(color: AppColors.primaryTextColor.withAlpha(153), width: 0.5),
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              tooltipMargin: 8,
              maxContentWidth: 100,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              showOnTopOfTheChartBoxArea: false,
              getTooltipItems: (List<LineBarSpot> spots) {
                return spots.map((spot) {
                  // Calculate actual time for this data point
                  String timeString;
                  if (startTimeZulu != null) {
                    // Add seconds to start time to get actual timestamp
                    final actualTime = startTimeZulu!.add(Duration(seconds: spot.x.toInt()));
                    timeString = '${actualTime.hour.toString().padLeft(2, '0')}:${actualTime.minute.toString().padLeft(2, '0')}:${actualTime.second.toString().padLeft(2, '0')}';
                  } else {
                    // Fallback to elapsed time if start time not provided
                    final totalSeconds = spot.x.toInt();
                    timeString = '${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:${(totalSeconds % 60).toString().padLeft(2, '0')}';
                  }
                  
                  return LineTooltipItem(
                    '',
                    const TextStyle(),
                    children: [
                      TextSpan(
                        text: '$timeString Z',
                        style: TextStyle(
                          color: AppColors.warningColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      TextSpan(
                        text: '\n${spot.y.toStringAsFixed(2)} g',
                        style: TextStyle(
                          color: AppColors.primaryTextColor,
                          fontSize: 9,
                          height: 1.2,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: AppColors.warningColor.withAlpha(51),
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.warningColor,
                        strokeWidth: 1.5,
                        strokeColor: AppColors.primaryTextColor,
                      );
                    },
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
