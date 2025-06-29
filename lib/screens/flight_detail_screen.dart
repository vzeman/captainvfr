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

  // Format duration as HH:MM:SS
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
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
            labelColor: Theme.of(context).colorScheme.onPrimary,
            indicatorColor: Theme.of(context).colorScheme.secondary,
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
                '$hours:${minutes}:$seconds',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Flight details grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 48) / 2, // Half width minus padding and spacing
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
                  value: '${flight.movingTime.inMinutes} min',
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
