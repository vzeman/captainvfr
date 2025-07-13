import 'package:flutter/material.dart';
import '../../models/flight.dart';
import '../../models/moving_segment.dart';

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
            style: Theme.of(context).textTheme.titleLarge,
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
            // Segments list
            ...flight.movingSegments.asMap().entries.map((entry) {
              final index = entry.key;
              final segment = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: InkWell(
                  onTap: () {
                    // Handle segment tap
                    onSegmentSelected(
                      selectedSegment == segment ? null : segment,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Segment ${index + 1}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              segment.formattedDuration,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Started',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  Text(
                                    segment.startZuluFormatted,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Stopped',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  Text(
                                    segment.endZuluFormatted,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Expanded segment data
                        if (selectedSegment == segment) ...[
                          const SizedBox(height: 12),
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
                segment.altitudeChange >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                iconColor: segment.altitudeChange >= 0
                    ? Colors.green
                    : Colors.red,
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
