import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/performance_monitor.dart';

/// A debug overlay that shows real-time performance metrics
class PerformanceOverlayWidget extends StatefulWidget {
  final bool showFPS;
  final bool showOperations;
  final bool alignRight;
  
  const PerformanceOverlayWidget({
    super.key,
    this.showFPS = true,
    this.showOperations = true,
    this.alignRight = false,
  });

  @override
  State<PerformanceOverlayWidget> createState() => _PerformanceOverlayWidgetState();
}

class _PerformanceOverlayWidgetState extends State<PerformanceOverlayWidget> {
  Timer? _updateTimer;
  double _currentFPS = 60.0;
  int _slowFrames = 0;
  int _totalFrames = 0;
  Map<String, OperationStats> _recentOperations = {};
  
  // Frame timing tracking
  final List<double> _recentFrameTimes = [];
  static const int _maxFrameSamples = 60;

  @override
  void initState() {
    super.initState();
    
    // Listen to frame timings
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    
    // Update UI periodically
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        _updateStats();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final totalTime = timing.totalSpan.inMicroseconds / 1000.0; // Convert to ms
      
      _recentFrameTimes.add(totalTime);
      if (_recentFrameTimes.length > _maxFrameSamples) {
        _recentFrameTimes.removeAt(0);
      }
      
      _totalFrames++;
      if (totalTime > 16.67) { // 60fps threshold
        _slowFrames++;
      }
    }
  }

  void _updateStats() {
    setState(() {
      // Calculate average FPS from recent frame times
      if (_recentFrameTimes.isNotEmpty) {
        final avgFrameTime = _recentFrameTimes.reduce((a, b) => a + b) / _recentFrameTimes.length;
        _currentFPS = avgFrameTime > 0 ? 1000.0 / avgFrameTime : 60.0;
      }
      
      // Get recent operations from PerformanceMonitor
      final monitor = PerformanceMonitor();
      _recentOperations = monitor.getOperationStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: widget.alignRight ? null : 10,
      right: widget.alignRight ? 10 : null,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: widget.alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showFPS) ...[
                _buildFPSInfo(),
                const SizedBox(height: 4),
              ],
              if (widget.showOperations) ...[
                _buildOperationsInfo(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFPSInfo() {
    final fpsColor = _currentFPS >= 55 ? Colors.green
        : _currentFPS >= 30 ? Colors.orange
        : Colors.red;
    
    final slowFramePercent = _totalFrames > 0 
        ? (_slowFrames / _totalFrames * 100).toStringAsFixed(1)
        : '0.0';
    
    return Column(
      crossAxisAlignment: widget.alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, color: fpsColor, size: 16),
            const SizedBox(width: 4),
            Text(
              '${_currentFPS.toStringAsFixed(1)} FPS',
              style: TextStyle(
                color: fpsColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          'Slow frames: $slowFramePercent%',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsInfo() {
    if (_recentOperations.isEmpty) {
      return const Text(
        'No operations',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      );
    }

    // Sort operations by average time
    final sortedOps = _recentOperations.entries.toList()
      ..sort((a, b) => b.value.averageTime.compareTo(a.value.averageTime));

    // Show top 5 slowest operations
    final topOps = sortedOps.take(5);

    return Column(
      crossAxisAlignment: widget.alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Operations:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        ...topOps.map((entry) {
          final color = entry.value.averageTime > 100 ? Colors.red
              : entry.value.averageTime > 50 ? Colors.orange
              : Colors.green;
          
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${entry.key}: ${entry.value.averageTime.toStringAsFixed(0)}ms',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Extension to easily add performance overlay to any widget
extension PerformanceOverlayExtension on Widget {
  Widget withPerformanceOverlay({
    bool showFPS = true,
    bool showOperations = true,
    bool alignRight = false,
  }) {
    return Stack(
      children: [
        this,
        PerformanceOverlayWidget(
          showFPS: showFPS,
          showOperations: showOperations,
          alignRight: alignRight,
        ),
      ],
    );
  }
}