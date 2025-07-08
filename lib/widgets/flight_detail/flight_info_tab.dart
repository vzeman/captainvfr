import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/flight.dart';
import '../../models/moving_segment.dart';
import '../../services/settings_service.dart';

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

  // Format Zulu time
  String _formatZuluTime(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return '${utc.hour.toString().padLeft(2, '0')}:'
           '${utc.minute.toString().padLeft(2, '0')}:'
           '${utc.second.toString().padLeft(2, '0')}Z';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y • HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Flight Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                _formatDuration(flight.duration),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recording Times Section
          _buildTimeTrackingSection(context),
          const SizedBox(height: 20),

          // Moving Segments Section
          if (flight.movingSegments.isNotEmpty) ...[
            _buildMovingSegmentsSection(context),
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
                    style: Theme.of(context).textTheme.titleMedium,
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
                          icon: Icons.calendar_today,
                          title: 'Date',
                          value: dateFormat.format(flight.startTime),
                        ),
                      ),
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
                  icon: Icons.timer,
                  title: 'Moving Time',
                  value: _formatDuration(flight.movingTime),
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: _buildInfoTile(
                  context,
                  icon: Icons.assessment,
                  title: 'Points',
                  value: '${flight.path.length}',
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
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Time Tracking (Zulu Times)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

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
          if (flight.movingStoppedZulu != null)
            _buildTimeRow(
              context,
              'Last Movement',
              _formatZuluTime(flight.movingStoppedZulu!),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _formatDuration(flight.totalRecordingTime),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _formatDuration(flight.movingTime),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
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

  Widget _buildMovingSegmentsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Moving Segments (${flight.movingSegments.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Moving segments list
          ...flight.movingSegments.asMap().entries.map((entry) {
            final index = entry.key;
            final segment = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: GestureDetector(
                onTap: () => onSegmentSelected(segment),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: selectedSegment == segment
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: selectedSegment == segment
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Segment ${index + 1}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            segment.formattedDuration,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Started',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                segment.startZuluFormatted,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Stopped',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                segment.endZuluFormatted,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Enhanced flight data section
                      const SizedBox(height: 12),
                      _buildSegmentDetails(context, segment),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Pause points summary
          if (flight.pausePoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pause_circle,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${flight.pausePoints.length} pause point${flight.pausePoints.length != 1 ? 's' : ''} recorded',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentDetails(BuildContext context, MovingSegment segment) {
    return Column(
      children: [
        // Speed and Heading Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSegmentDataTile(
                context,
                'Avg Speed',
                segment.formattedAverageSpeed,
                Icons.speed,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSegmentDataTile(
                context,
                'Heading',
                segment.formattedHeading,
                Icons.navigation,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Distance and Altitude Change Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSegmentDataTile(
                context,
                'Distance',
                '${(segment.distance / 1000).toStringAsFixed(2)} km',
                Icons.straighten,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSegmentDataTile(
                context,
                'Alt Change',
                segment.formattedAltitudeChange,
                segment.altitudeChange >= 0 ? Icons.trending_up : Icons.trending_down,
                iconColor: segment.altitudeChange >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Altitude Details Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSegmentDataTile(
                context,
                'Start Alt',
                segment.formattedStartAltitude,
                Icons.flight_takeoff,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSegmentDataTile(
                context,
                'End Alt',
                segment.formattedEndAltitude,
                Icons.flight_land,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Min/Max Altitude Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSegmentDataTile(
                context,
                'Min Alt',
                segment.formattedMinAltitude,
                Icons.arrow_downward,
                iconColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSegmentDataTile(
                context,
                'Max Alt',
                segment.formattedMaxAltitude,
                Icons.arrow_upward,
                iconColor: Colors.blue,
              ),
            ),
          ],
        ),
      ],
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            time,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentDataTile(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
}
