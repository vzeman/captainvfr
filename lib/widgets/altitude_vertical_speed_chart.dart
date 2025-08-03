import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/settings_service.dart';

class AltitudeVerticalSpeedChart extends StatelessWidget {
  final List<double> altitudeData;
  final List<double> verticalSpeedData;
  final double? currentAltitude;
  final double? minAltitude;
  final double? maxAltitude;
  final DateTime? startTimeZulu;
  final Function(int)? onPointSelected;

  const AltitudeVerticalSpeedChart({
    super.key,
    required this.altitudeData,
    required this.verticalSpeedData,
    this.currentAltitude,
    this.minAltitude,
    this.maxAltitude,
    this.startTimeZulu,
    this.onPointSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (altitudeData.isEmpty) {
      return Center(
        child: Text(
          'No altitude data available\nStart tracking to see altitude changes',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.tertiaryTextColor),
        ),
      );
    }

    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';
        
        // Convert altitude data to appropriate units
        final displayAltitudes = isMetric
            ? altitudeData // meters
            : altitudeData.map((a) => a * 3.28084).toList(); // feet
        
        final altitudeUnit = isMetric ? 'm' : 'ft';
        final vsUnit = isMetric ? 'm/s' : 'ft/min';
        
        // Convert vertical speeds to appropriate units
        final vsData = verticalSpeedData.isNotEmpty
            ? verticalSpeedData
            : List.filled(altitudeData.length, 0.0);
        
        final displayVS = isMetric
            ? vsData // m/s
            : vsData.map((vs) => vs * 196.85).toList(); // ft/min
        
        // Calculate min and max for altitude Y axis
        final altConversionFactor = isMetric ? 1.0 : 3.28084;
        final padding = isMetric ? 50.0 : 150.0;
        
        final minAltY = minAltitude != null
            ? minAltitude! * altConversionFactor - padding
            : (displayAltitudes.isNotEmpty
                ? displayAltitudes.reduce((a, b) => a < b ? a : b) - padding
                : 0.0);
        
        final maxAltY = maxAltitude != null
            ? maxAltitude! * altConversionFactor + padding
            : (displayAltitudes.isNotEmpty
                ? displayAltitudes.reduce((a, b) => a > b ? a : b) + padding
                : 1000.0);
        
        // Calculate min and max for vertical speed Y axis
        final vsPadding = isMetric ? 0.5 : 50.0;
        final minVS = displayVS.reduce((a, b) => a < b ? a : b) - vsPadding;
        final maxVS = displayVS.reduce((a, b) => a > b ? a : b) + vsPadding;

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
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                'Altitude ($altitudeUnit)',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryTextColor,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: Text(
                'V/S ($vsUnit)',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.successColor,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  // Map the right axis to vertical speed range
                  final vsValue =
                      minVS +
                      (value - minAltY) * (maxVS - minVS) / (maxAltY - minAltY);
                  return Text(
                    isMetric ? vsValue.toStringAsFixed(1) : vsValue.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.successColor,
                    ),
                  );
                },
              ),
            ),
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
                interval: altitudeData.length > 10
                    ? altitudeData.length / 5
                    : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  // Assuming each data point is 1 second
                  final totalSeconds = index;
                  final minutes = totalSeconds ~/ 60;
                  final seconds = totalSeconds % 60;
                  
                  // Show time in M:SS format for first few minutes, then just minutes
                  String timeLabel;
                  if (minutes < 5 && altitudeData.length < 600) {
                    timeLabel = '$minutes:${seconds.toString().padLeft(2, '0')}';
                  } else {
                    timeLabel = '${minutes}m';
                  }
                  
                  return Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryTextColor,
                    ),
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
              spots: displayAltitudes.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.primaryAccent,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primaryAccent.withAlpha(38),
              ),
            ),
            // Vertical speed line (mapped to altitude scale)
            LineChartBarData(
              spots: displayVS.asMap().entries.map((entry) {
                // Map vertical speed to altitude scale for display
                final mappedValue =
                    minAltY +
                    (entry.value - minVS) *
                        (maxAltY - minAltY) /
                        (maxVS - minVS);
                return FlSpot(entry.key.toDouble(), mappedValue);
              }).toList(),
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.successColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: [5, 5], // Dashed line to distinguish from altitude
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
              maxContentWidth: 120,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              showOnTopOfTheChartBoxArea: false,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                if (touchedBarSpots.isEmpty) return [];
                
                // Calculate actual time once for all touched spots
                final firstSpot = touchedBarSpots.first;
                String timeString;
                if (startTimeZulu != null) {
                  // Add seconds to start time to get actual timestamp
                  final actualTime = startTimeZulu!.add(Duration(seconds: firstSpot.x.toInt()));
                  timeString = '${actualTime.hour.toString().padLeft(2, '0')}:${actualTime.minute.toString().padLeft(2, '0')}:${actualTime.second.toString().padLeft(2, '0')}';
                } else {
                  // Fallback to elapsed time if start time not provided
                  final totalSeconds = firstSpot.x.toInt();
                  timeString = '${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:${(totalSeconds % 60).toString().padLeft(2, '0')}';
                }
                
                // Return one tooltip item per touched spot, but only show time on the first one
                return touchedBarSpots.asMap().entries.map((entry) {
                  final index = entry.key;
                  final barSpot = entry.value;
                  
                  if (index == 0) {
                    // First item shows time and value
                    if (barSpot.barIndex == 0) {
                      // Altitude
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
                            text: '\n${barSpot.y.toStringAsFixed(0)} $altitudeUnit',
                            style: TextStyle(
                              color: AppColors.primaryAccent,
                              fontSize: 9,
                              height: 1.2,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Vertical speed
                      final vsValue = displayVS[barSpot.x.toInt()];
                      final vsFormatted = isMetric 
                          ? '${vsValue.toStringAsFixed(1)} m/s'
                          : '${vsValue.toStringAsFixed(0)} ft/min';
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
                            text: '\nV/S: $vsFormatted',
                            style: TextStyle(
                              color: AppColors.successColor,
                              fontSize: 9,
                              height: 1.2,
                            ),
                          ),
                        ],
                      );
                    }
                  } else {
                    // Subsequent items only show value
                    if (barSpot.barIndex == 0) {
                      // Altitude
                      return LineTooltipItem(
                        '${barSpot.y.toStringAsFixed(0)} $altitudeUnit',
                        TextStyle(
                          color: AppColors.primaryAccent,
                          fontSize: 9,
                          height: 1.2,
                        ),
                      );
                    } else {
                      // Vertical speed
                      final vsValue = displayVS[barSpot.x.toInt()];
                      final vsFormatted = isMetric 
                          ? '${vsValue.toStringAsFixed(1)} m/s'
                          : '${vsValue.toStringAsFixed(0)} ft/min';
                      return LineTooltipItem(
                        'V/S: $vsFormatted',
                        TextStyle(
                          color: AppColors.successColor,
                          fontSize: 9,
                          height: 1.2,
                        ),
                      );
                    }
                  }
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((index) {
                final color = barData.color ?? AppColors.primaryAccent;
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: color.withAlpha(51),
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3,
                        color: color,
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
      },
    );
  }
}
