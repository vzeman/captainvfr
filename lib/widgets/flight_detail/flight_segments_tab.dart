import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flight.dart';
import '../../models/moving_segment.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../services/settings_service.dart';

class FlightSegmentsTab extends StatelessWidget {
  final Flight flight;
  final dynamic selectedSegment;
  final Function(dynamic) onSegmentSelected;

  const FlightSegmentsTab({
    super.key,
    required this.flight,
    this.selectedSegment,
    required this.onSegmentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segments title
          Text(
            'Flight Segments',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryAccent,
            ),
          ),
          const SizedBox(height: 16),

          // No segments message
          if (flight.movingSegments.isEmpty)
            Center(
              child: Text(
                'No segments data available',
                style: TextStyle(color: Theme.of(context).disabledColor),
              ),
            )
          else ...[
            // Segments list with new design
            ...flight.movingSegments.asMap().entries.map((entry) {
              final index = entry.key;
              final segment = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: GestureDetector(
                  onTap: () => onSegmentSelected(
                    selectedSegment == segment ? null : segment,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: selectedSegment == segment
                          ? AppColors.sectionBackgroundColor
                          : AppColors.backgroundColor,
                      borderRadius: AppTheme.defaultRadius,
                      border: Border.all(
                        color: selectedSegment == segment
                            ? AppColors.primaryAccent
                            : AppColors.sectionBorderColor,
                        width: selectedSegment == segment ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Segment header with title and time info below
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Segment ${index + 1}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryTextColor,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: AppColors.secondaryTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getCompactTimeRange(segment),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.secondaryTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.timer,
                                  size: 12,
                                  color: AppColors.secondaryTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  segment.formattedDuration,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.primaryAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Expanded segment data
                        if (selectedSegment == segment) ...[
                          const SizedBox(height: 8),
                          Container(
                            height: 1,
                            color: AppColors.sectionBorderColor.withAlpha(76),
                          ),
                          _buildSegmentDetails(context, segment),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _getCompactTimeRange(MovingSegment segment) {
    String startTime = segment.startZuluFormatted;
    String endTime = segment.endZuluFormatted;
    
    // Extract just the time portion if it contains a space (date time format)
    if (startTime.contains(' ')) {
      startTime = startTime.split(' ').last;
    }
    if (endTime.contains(' ')) {
      endTime = endTime.split(' ').last;
    }
    
    // Truncate to HH:MM format if longer
    if (startTime.length > 5) {
      startTime = startTime.substring(0, 5);
    }
    if (endTime.length > 5) {
      endTime = endTime.substring(0, 5);
    }
    
    return '$startTime - $endTime';
  }

  Widget _buildSegmentDetails(BuildContext context, MovingSegment segment) {
    // Use Consumer to get unit settings
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';
        
        // Format distance based on unit settings
        final distanceValue = isMetric
            ? '${(segment.distance / 1000).toStringAsFixed(2)} km'
            : '${(segment.distance * 0.000621371).toStringAsFixed(2)} mi';
        
        return Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Column(
            children: [
              // Speed
              _buildSegmentDataRow(
                context,
                icon: Icons.speed,
                title: 'Avg Speed',
                value: segment.formattedAverageSpeed,
              ),
              // Distance
              _buildSegmentDataRow(
                context,
                icon: Icons.straighten,
                title: 'Distance',
                value: distanceValue,
              ),
              // Heading
              _buildSegmentDataRow(
                context,
                icon: Icons.navigation,
                title: 'Heading',
                value: segment.formattedHeading,
              ),
              // Start Altitude
              _buildSegmentDataRow(
                context,
                icon: Icons.flight_takeoff,
                title: 'Start Alt',
                value: segment.formattedStartAltitude,
              ),
              // End Altitude
              _buildSegmentDataRow(
                context,
                icon: Icons.flight_land,
                title: 'End Alt',
                value: segment.formattedEndAltitude,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegmentDataRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: iconColor ?? AppColors.primaryAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryTextColor,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
