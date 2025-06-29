import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import '../models/flight.dart';
import '../widgets/altitude_chart.dart';
import '../widgets/speed_chart.dart';
import '../widgets/vibration_chart.dart';

class FlightDetailScreen extends StatefulWidget {
  final Flight flight;

  const FlightDetailScreen({super.key, required this.flight});

  @override
  State<FlightDetailScreen> createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Wait for the map to be ready before fitting bounds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitBounds();
    });
  }

  void _fitBounds() {
    if (widget.flight.path.isEmpty) return;
    
    final positions = widget.flight.positions;
    if (positions.isEmpty) return;

    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final point in positions) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1 + 0.01; // Add minimum padding
    final lngPadding = (maxLng - minLng) * 0.1 + 0.01; // Add minimum padding
    
    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    // Fit bounds with animation
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40.0),
      ),
    );
  }
  @override
  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

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
    final duration = widget.flight.duration;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final hasAltitudeData = widget.flight.altitudes.isNotEmpty && 
                          widget.flight.altitudes.any((alt) => alt > 0);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flight Details'),
          bottom: TabBar(
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.info_outline), text: 'Info'),
              Tab(icon: Icon(Icons.speed), text: 'Speed'),
              Tab(icon: Icon(Icons.vibration), text: 'Vibration'),
              Tab(icon: Icon(Icons.terrain), text: 'Altitude'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                // TODO: Implement share functionality
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Map View
            Expanded(
              flex: 3,
              child: _buildMap(),
            ),
            // Tab Bar View
            Expanded(
              flex: 3,
              child: TabBarView(
                children: [
                  // Info Tab
                  _buildFlightInfo(context, dateFormat, hours, minutes, seconds),
                  
                  // Speed Tab
                  widget.flight.speeds.isNotEmpty
                      ? SpeedChart(
                          speedData: widget.flight.speeds,
                          currentSpeed: widget.flight.speeds.isNotEmpty 
                              ? widget.flight.speeds.last 
                              : null,
                          minSpeed: 0,
                          maxSpeed: widget.flight.speeds.isNotEmpty 
                              ? widget.flight.speeds.reduce((a, b) => a > b ? a : b)
                              : null,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.speed,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No speed data available',
                                style: TextStyle(
                                  color: Theme.of(context).disabledColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                  
                  // Vibration Tab
                  widget.flight.vibrationData.isNotEmpty
                      ? VibrationChart(
                          vibrationData: widget.flight.vibrationData,
                          currentVibration: widget.flight.vibrationData.isNotEmpty 
                              ? widget.flight.vibrationData.last 
                              : null,
                          maxVibration: widget.flight.vibrationData.isNotEmpty 
                              ? widget.flight.vibrationData.reduce((a, b) => a > b ? a : b)
                              : null,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.vibration,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No vibration data available',
                                style: TextStyle(
                                  color: Theme.of(context).disabledColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                  
                  // Altitude Tab
                  hasAltitudeData 
                      ? AltitudeChart(
                          altitudeData: widget.flight.altitudes,
                          currentAltitude: widget.flight.altitudes.isNotEmpty 
                              ? widget.flight.altitudes.last 
                              : null,
                          minAltitude: widget.flight.altitudes.isNotEmpty 
                              ? widget.flight.altitudes.reduce((a, b) => a < b ? a : b) - 50 
                              : null,
                          maxAltitude: widget.flight.altitudes.isNotEmpty 
                              ? widget.flight.altitudes.reduce((a, b) => a > b ? a : b) + 50 
                              : null,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.terrain,
                                size: 48,
                                color: Theme.of(context).disabledColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No altitude data available',
                                style: TextStyle(
                                  color: Theme.of(context).disabledColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (widget.flight.path.isEmpty) {
      return const Center(child: Text('No flight path data available'));
    }
    
    final positions = widget.flight.positions;
    final startPoint = positions.isNotEmpty ? positions.first : const LatLng(0, 0);
    final endPoint = positions.length > 1 ? positions.last : positions.first;
    
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: startPoint,
        initialZoom: 10.0,
        maxZoom: 18.0,
        minZoom: 3.0,
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.pinchZoom | 
                 InteractiveFlag.drag | 
                 InteractiveFlag.doubleTapZoom,
        ),
        onTap: (point, latLng) {
          // Handle map tap
        },
        onMapReady: () {
          // Fit the map to the flight path once the map is ready
          _fitBounds();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.captainvfr',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: positions,
              color: Colors.blue.withOpacity(0.8),
              strokeWidth: 4.0,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Start marker
            Marker(
              point: startPoint,
              width: 30,
              height: 30,
              child: const Icon(Icons.location_history, color: Colors.green, size: 30),
            ),
            // End marker
            if (positions.length > 1)
              Marker(
                point: endPoint,
                width: 30,
                height: 30,
                child: const Icon(Icons.location_on, color: Colors.red, size: 30),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlightInfo(
    BuildContext context, 
    DateFormat dateFormat, 
    String hours, 
    String minutes, 
    String seconds,
  ) {
    final flight = widget.flight;
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
                  value: '${(flight.maxSpeed * 3.6).toStringAsFixed(1)} km/h',
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: _buildInfoTile(
                  context,
                  icon: Icons.height,
                  title: 'Max Altitude',
                  value: '${flight.maxAltitude.toStringAsFixed(0)} m',
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                child: _buildInfoTile(
                  context,
                  icon: Icons.airplanemode_active,
                  title: 'Distance',
                  value: '${(flight.distanceTraveled / 1000).toStringAsFixed(1)} km',
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
      ),
    );
  }

  Widget _buildTimeTrackingSection(BuildContext context) {
    final flight = widget.flight;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
    final flight = widget.flight;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
                ),
              ),
            );
          }).toList(),

          // Pause points summary
          if (flight.pausePoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
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
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
        color: Theme.of(context).colorScheme.surfaceVariant,
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
