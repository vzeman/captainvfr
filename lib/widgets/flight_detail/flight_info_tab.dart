import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/flight.dart';
import '../../services/settings_service.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_colors.dart';

class FlightInfoTab extends StatelessWidget {
  final Flight flight;
  final dynamic selectedSegment;
  final Function(dynamic) onSegmentSelected;

  const FlightInfoTab({
    super.key,
    required this.flight,
    this.selectedSegment,
    required this.onSegmentSelected,
  });

  // Format duration with seconds if less than 1 minute
  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds}s';
    } else {
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
  }

  // Calculate average speed
  String _calculateAverageSpeed(Flight flight, bool isMetric) {
    if (flight.movingTime.inSeconds == 0) {
      return isMetric ? '0 km/h' : '0 mph';
    }
    
    // Distance in meters, time in seconds
    final avgSpeedMps = flight.distanceTraveled / flight.movingTime.inSeconds;
    
    if (isMetric) {
      final avgSpeedKmh = avgSpeedMps * 3.6;
      return '${avgSpeedKmh.toStringAsFixed(1)} km/h';
    } else {
      final avgSpeedMph = avgSpeedMps * 2.23694;
      return '${avgSpeedMph.toStringAsFixed(1)} mph';
    }
  }

  // Format Zulu time
  String _formatZuluTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return '${utc.hour.toString().padLeft(2, '0')}:'
        '${utc.minute.toString().padLeft(2, '0')}:'
        '${utc.second.toString().padLeft(2, '0')}Z';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight summary
          Text(
            'Flight Summary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),

          // Recording Times Section
          _buildTimeTrackingSection(context),
          const SizedBox(height: 20),

          // Airport information section if available
          if (flight.departureAirportCode != null || 
              flight.arrivalAirportCode != null) ...[
            _buildAirportSection(context),
            const SizedBox(height: 20),
          ],

          // Flight details grid
          Consumer<SettingsService>(
            builder: (context, settings, child) {
              final isMetric = settings.units == 'metric';

              // Format values based on unit settings
              final speedValue = isMetric
                  ? '${(flight.maxSpeed * 3.6).toStringAsFixed(1)} km/h'
                  : '${(flight.maxSpeed * 2.23694).toStringAsFixed(1)} mph';

              final altitudeValue = isMetric
                  ? '${flight.maxAltitude.toStringAsFixed(0)} m'
                  : '${(flight.maxAltitude * 3.28084).toStringAsFixed(0)} ft';

              final distanceValue = isMetric
                  ? '${(flight.distanceTraveled / 1000).toStringAsFixed(1)} km'
                  : '${(flight.distanceTraveled * 0.000621371).toStringAsFixed(1)} mi';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flight Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 48) / 2,
                        child: _buildInfoTile(
                          context,
                          icon: Icons.speed,
                          title: 'Max Speed',
                          value: speedValue,
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 48) / 2,
                        child: _buildInfoTile(
                          context,
                          icon: Icons.height,
                          title: 'Max Altitude',
                          value: altitudeValue,
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 48) / 2,
                        child: _buildInfoTile(
                          context,
                          icon: Icons.airplanemode_active,
                          title: 'Distance',
                          value: distanceValue,
                        ),
                      ),
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 48) / 2,
                        child: _buildInfoTile(
                          context,
                          icon: Icons.speed,
                          title: 'Avg Speed',
                          value: _calculateAverageSpeed(flight, isMetric),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTrackingSection(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: AppTheme.extraLargeRadius,
        border: Border.all(
          color: AppColors.sectionBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: AppColors.primaryAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Time Tracking',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryAccent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date
          _buildTimeRow(
            context,
            'Date',
            dateFormat.format(flight.startTime),
            Icons.calendar_today,
          ),

          const SizedBox(height: 8),

          // Recording Times
          _buildTimeRow(
            context,
            'Recording Started',
            _formatZuluTime(flight.recordingStartedZulu),
            Icons.play_arrow,
          ),
          if (flight.recordingStoppedZulu != null)
            _buildTimeRow(
              context,
              'Recording Stopped',
              _formatZuluTime(flight.recordingStoppedZulu!),
              Icons.stop,
            ),

          const SizedBox(height: 8),

          // Moving Times
          if (flight.movingStartedZulu != null)
            _buildTimeRow(
              context,
              'First Movement',
              _formatZuluTime(flight.movingStartedZulu!),
              Icons.directions_run,
            ),
          // Always show Last Movement - use recording stopped time if moving stopped is null
          _buildTimeRow(
            context,
            'Last Movement',
            _formatZuluTime(
              flight.movingStoppedZulu ?? 
              flight.recordingStoppedZulu ?? 
              flight.endTime?.toUtc() ?? 
              DateTime.now().toUtc()
            ),
            Icons.pause,
          ),

          const SizedBox(height: 8),

          // Duration Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Recording',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                  Text(
                    _formatDuration(flight.totalRecordingTime),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Moving',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    _formatDuration(flight.movingTime),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildTimeRow(
    BuildContext context,
    String label,
    String time,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.secondaryTextColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryTextColor,
              ),
            ),
          ),
          Text(
            time,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: AppTheme.defaultRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.primaryAccent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAirportSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: AppTheme.extraLargeRadius,
        border: Border.all(
          color: AppColors.sectionBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flight,
                color: AppColors.primaryAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Airports',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Departure Airport
          if (flight.departureAirportCode != null) ...[
            Row(
              children: [
                Icon(
                  Icons.flight_takeoff,
                  size: 16,
                  color: AppColors.secondaryTextColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Departure',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                      Text(
                        flight.departureAirportCode!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // Arrival Airport
          if (flight.arrivalAirportCode != null) ...[
            Row(
              children: [
                Icon(
                  Icons.flight_land,
                  size: 16,
                  color: AppColors.secondaryTextColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arrival',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                      Text(
                        flight.arrivalAirportCode!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
