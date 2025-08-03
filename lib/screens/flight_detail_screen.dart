import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flight.dart';
import '../services/logbook_service.dart';
import '../screens/logbook/logbook_screen.dart';
import '../widgets/altitude_vertical_speed_chart.dart';
import '../widgets/speed_chart.dart';
import '../widgets/vibration_chart.dart';
import '../widgets/flight_detail/flight_detail_map.dart';
import '../widgets/flight_detail/flight_info_tab.dart';
import '../widgets/flight_detail/flight_segments_tab.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../constants/flight_detail_constants.dart';

class FlightDetailScreen extends StatefulWidget {
  final Flight flight;

  const FlightDetailScreen({super.key, required this.flight});

  @override
  State<FlightDetailScreen> createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  dynamic _selectedSegment; // Can be MovingSegment or FlightSegment
  double _mapHeightFraction = FlightDetailConstants.defaultMapHeightFraction;
  bool _isDragging = false;
  final GlobalKey<FlightDetailMapState> _mapKey = GlobalKey<FlightDetailMapState>();
  int? _selectedChartPointIndex;
  Timer? _touchDebounce;

  void _onSegmentSelected(dynamic segment) {
    setState(() {
      _selectedSegment = segment;
    });
  }

  /// Handles chart point selection with optional debouncing.
  /// When debounce is 0, updates are immediate for smooth interaction.
  void _onChartPointSelected(int index) {
    // Cancel any existing timer
    _touchDebounce?.cancel();
    
    if (FlightDetailConstants.touchDebounceMilliseconds == 0) {
      // Immediate update for smooth interaction
      if (mounted) {
        setState(() {
          _selectedChartPointIndex = index;
        });
        _mapKey.currentState?.showMarkerAtIndex(index);
      }
    } else {
      // Debounced update for performance optimization
      _touchDebounce = Timer(
        const Duration(milliseconds: FlightDetailConstants.touchDebounceMilliseconds),
        () {
          if (mounted) {
            setState(() {
              _selectedChartPointIndex = index;
            });
            _mapKey.currentState?.showMarkerAtIndex(index);
          }
        },
      );
    }
  }

  /// Updates the map/chart split ratio based on vertical drag gesture.
  /// The drag sensitivity is amplified by FlightDetailConstants.dragSensitivity
  /// to make the interaction feel more responsive to user input.
  void _onVerticalDragUpdate(DragUpdateDetails details, double totalHeight) {
    setState(() {
      // Calculate new height fraction based on drag with amplified sensitivity
      final delta = (details.delta.dy / totalHeight) * FlightDetailConstants.dragSensitivity;
      _mapHeightFraction = (_mapHeightFraction + delta).clamp(
        FlightDetailConstants.minMapHeightFraction,
        FlightDetailConstants.maxMapHeightFraction,
      );
    });
  }

  void _onDragStart() {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragEnd() {
    setState(() {
      _isDragging = false;
    });
    // Fit the map to show the entire flight track after resizing
    _mapKey.currentState?.fitMapToTrack();
  }

  @override
  void dispose() {
    // Clean up the timer to prevent memory leaks
    _touchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAltitudeData =
        widget.flight.altitudes.isNotEmpty &&
        widget.flight.altitudes.any((alt) => alt > 0);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.dialogBackgroundColor,
          title: const Text(
            'Flight Details',
            style: TextStyle(color: AppColors.primaryTextColor),
          ),
          iconTheme: const IconThemeData(color: AppColors.primaryTextColor),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primaryAccent,
            labelColor: AppColors.primaryAccent,
            unselectedLabelColor: AppColors.secondaryTextColor,
            tabs: const [
              Tab(icon: Icon(Icons.info_outline), text: 'Info'),
              Tab(icon: Icon(Icons.timeline), text: 'Segments'),
              Tab(icon: Icon(Icons.speed), text: 'Speed'),
              Tab(icon: Icon(Icons.vibration), text: 'Turbulence'),
              Tab(icon: Icon(Icons.terrain), text: 'Altitude'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.menu_book, color: AppColors.primaryTextColor),
                label: const Text(
                  '+ Logbook',
                  style: TextStyle(color: AppColors.primaryTextColor),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.buttonRadius,
                  ),
                ),
                onPressed: () async {
                  final logBookService = context.read<LogBookService>();
                  
                  try {
                    await logBookService.createEntryFromFlight(widget.flight);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logbook entry created successfully'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      // Navigate to logbook screen (Logs tab)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LogBookScreen(initialTab: 1),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating logbook entry: $e'),
                          backgroundColor: AppColors.errorColor,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;
            final dividerHeight = FlightDetailConstants.dividerHeight;
            final minPanelHeight = FlightDetailConstants.minPanelHeight;
            
            // Calculate map height with proper constraints
            double mapHeight = (totalHeight - dividerHeight) * _mapHeightFraction;
            
            // Ensure both panels have minimum height
            if (mapHeight < minPanelHeight) {
              mapHeight = minPanelHeight;
            } else if (mapHeight > totalHeight - dividerHeight - minPanelHeight) {
              mapHeight = totalHeight - dividerHeight - minPanelHeight;
            }
            
            // Calculate exact remaining height for info panel
            final infoHeight = totalHeight - mapHeight - dividerHeight;

            return Column(
              children: [
                // Map View
                SizedBox(
                  height: mapHeight,
                  child: FlightDetailMap(
                    key: _mapKey,
                    flight: widget.flight,
                    selectedSegment: _selectedSegment,
                    onSegmentSelected: _onSegmentSelected,
                    selectedChartPointIndex: _selectedChartPointIndex,
                  ),
                ),
                
                // Draggable Divider
                GestureDetector(
                    onVerticalDragStart: (_) => _onDragStart(),
                    onVerticalDragUpdate: (details) => 
                        _onVerticalDragUpdate(details, totalHeight),
                    onVerticalDragEnd: (_) => _onDragEnd(),
                    child: Container(
                      height: FlightDetailConstants.dividerHeight,
                      decoration: BoxDecoration(
                        color: _isDragging 
                            ? AppColors.primaryAccent.withAlpha(25)
                            : AppColors.backgroundColor,
                        border: Border(
                          top: BorderSide(
                            color: AppColors.sectionBorderColor.withAlpha(102),
                            width: FlightDetailConstants.dividerBorderWidth,
                          ),
                          bottom: BorderSide(
                            color: AppColors.sectionBorderColor.withAlpha(102),
                            width: FlightDetailConstants.dividerBorderWidth,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FlightDetailConstants.dividerHandlePadding,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color: _isDragging
                                ? AppColors.primaryAccent
                                : AppColors.sectionBackgroundColor.withAlpha(204),
                            borderRadius: BorderRadius.circular(
                              FlightDetailConstants.dividerHandleRadius,
                            ),
                            border: Border.all(
                              color: _isDragging
                                  ? AppColors.primaryAccent
                                  : AppColors.sectionBorderColor.withAlpha(153),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_up,
                                size: FlightDetailConstants.dividerHandleIconSize,
                                color: _isDragging
                                    ? AppColors.primaryTextColor
                                    : AppColors.primaryAccent,
                              ),
                              Container(
                                height: FlightDetailConstants.dividerHandleBarHeight,
                                width: FlightDetailConstants.dividerHandleBarWidth,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: _isDragging
                                      ? AppColors.primaryTextColor.withAlpha(204)
                                      : AppColors.primaryAccent.withAlpha(102),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: FlightDetailConstants.dividerHandleIconSize,
                                color: _isDragging
                                    ? AppColors.primaryTextColor
                                    : AppColors.primaryAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Tab Bar View
                SizedBox(
                  height: infoHeight,
                  child: TabBarView(
                children: [
                  // Info Tab
                  FlightInfoTab(
                    flight: widget.flight,
                    selectedSegment: _selectedSegment,
                    onSegmentSelected: _onSegmentSelected,
                  ),

                  // Segments Tab
                  FlightSegmentsTab(
                    flight: widget.flight,
                    selectedSegment: _selectedSegment,
                    onSegmentSelected: _onSegmentSelected,
                  ),

                  // Speed Tab
                  _buildChartTab(
                    widget.flight.speeds.isNotEmpty
                        ? SpeedChart(
                            speedData: widget.flight.speeds,
                            currentSpeed: widget.flight.speeds.isNotEmpty
                                ? widget.flight.speeds.last
                                : null,
                            minSpeed: 0,
                            maxSpeed: widget.flight.speeds.isNotEmpty
                                ? widget.flight.speeds.reduce(
                                    (a, b) => a > b ? a : b,
                                  )
                                : null,
                            startTimeZulu: widget.flight.recordingStartedZulu,
                            onPointSelected: _onChartPointSelected,
                          )
                        : null,
                    Icons.speed,
                    'No speed data available',
                  ),

                  // Turbulence Tab
                  _buildChartTab(
                    widget.flight.vibrationData.isNotEmpty
                        ? VibrationChart(
                            vibrationData: widget.flight.vibrationData,
                            currentVibration:
                                widget.flight.vibrationData.isNotEmpty
                                ? widget.flight.vibrationData.last
                                : null,
                            maxVibration: widget.flight.vibrationData.isNotEmpty
                                ? widget.flight.vibrationData.reduce(
                                    (a, b) => a > b ? a : b,
                                  )
                                : null,
                            startTimeZulu: widget.flight.recordingStartedZulu,
                            onPointSelected: _onChartPointSelected,
                          )
                        : null,
                    Icons.vibration,
                    'No turbulence data available',
                  ),

                  // Altitude Tab
                  _buildChartTab(
                    hasAltitudeData
                        ? AltitudeVerticalSpeedChart(
                            altitudeData: widget.flight.altitudes,
                            verticalSpeedData: widget.flight.verticalSpeeds,
                            currentAltitude: widget.flight.altitudes.isNotEmpty
                                ? widget.flight.altitudes.last
                                : null,
                            minAltitude: widget.flight.altitudes.isNotEmpty
                                ? widget.flight.altitudes.reduce(
                                        (a, b) => a < b ? a : b,
                                      ) -
                                      50
                                : null,
                            maxAltitude: widget.flight.altitudes.isNotEmpty
                                ? widget.flight.altitudes.reduce(
                                        (a, b) => a > b ? a : b,
                                      ) +
                                      50
                                : null,
                            startTimeZulu: widget.flight.recordingStartedZulu,
                            onPointSelected: _onChartPointSelected,
                          )
                        : null,
                    Icons.terrain,
                    'No altitude data available',
                  ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChartTab(Widget? chart, IconData icon, String noDataMessage) {
    return chart ??
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: AppColors.tertiaryTextColor),
              const SizedBox(height: 16),
              Text(
                noDataMessage,
                style: TextStyle(color: AppColors.tertiaryTextColor),
              ),
            ],
          ),
        );
  }
}
