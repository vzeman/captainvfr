import 'dart:developer' as developer;
import 'dart:collection';
import 'package:flutter/scheduler.dart';

/// Statistics for a single operation
class OperationStats {
  final int count;
  final double totalTime;
  final double averageTime;
  final double maxTime;
  
  OperationStats({
    required this.count,
    required this.totalTime,
    required this.averageTime,
    required this.maxTime,
  });
}

/// Performance monitoring utility to track slow frames and identify causes
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  // Track operations that might cause slow frames
  String? _currentOperation;
  DateTime? _operationStartTime;
  
  // Frame timing callback
  bool _isMonitoring = false;
  
  // Performance statistics
  final Queue<FrameTiming> _recentFrames = Queue<FrameTiming>();
  final Map<String, List<int>> _operationTimings = <String, List<int>>{};
  final Map<String, int> _operationCounts = <String, int>{};
  static const int _maxRecentFrames = 60; // Keep last 60 frames (~1 second at 60fps)
  
  // Threshold for slow frames (in microseconds)
  static const int _slowFrameThresholdMicros = 16667; // ~16.67ms for 60fps
  static const int _warnFrameThresholdMicros = 33334; // ~33.33ms for 30fps
  
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    // Register frame timing callback
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    
    developer.log('🔍 Performance monitoring started');
  }
  
  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    
    developer.log('🔍 Performance monitoring stopped');
  }
  
  /// Track the start of an operation that might affect performance
  void startOperation(String operation) {
    _currentOperation = operation;
    _operationStartTime = DateTime.now();
  }
  
  /// Track the end of an operation
  void endOperation([String? operation]) {
    if (_currentOperation == null || _operationStartTime == null) return;
    
    final duration = DateTime.now().difference(_operationStartTime!);
    final operationName = operation ?? _currentOperation!;
    
    // Store timing data
    _operationTimings.putIfAbsent(operationName, () => <int>[]);
    _operationTimings[operationName]!.add(duration.inMilliseconds);
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
    
    // Keep only last 50 timings per operation to avoid memory growth
    if (_operationTimings[operationName]!.length > 50) {
      _operationTimings[operationName]!.removeAt(0);
    }
    
    // Log if operation took more than 10ms
    if (duration.inMilliseconds > 10) {
      developer.log(
        '⏱️ Operation "$operationName" took ${duration.inMilliseconds}ms',
      );
    }
    
    _currentOperation = null;
    _operationStartTime = null;
  }
  
  /// Handle frame timings
  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // Store recent frames for analysis
      _recentFrames.add(timing);
      if (_recentFrames.length > _maxRecentFrames) {
        _recentFrames.removeFirst();
      }
      
      final buildDuration = timing.buildDuration.inMicroseconds;
      final rasterDuration = timing.rasterDuration.inMicroseconds;
      final totalDuration = timing.totalSpan.inMicroseconds;
      
      // Check if frame is slow
      if (totalDuration > _slowFrameThresholdMicros) {
        final frameDurationMs = (totalDuration / 1000).toStringAsFixed(1);
        final buildMs = (buildDuration / 1000).toStringAsFixed(1);
        final rasterMs = (rasterDuration / 1000).toStringAsFixed(1);
        
        String message = '⚠️ Slow frame: ${frameDurationMs}ms';
        
        // Add details about what's slow
        if (buildDuration > _slowFrameThresholdMicros) {
          message += ' (Build: ${buildMs}ms)';
        }
        if (rasterDuration > _slowFrameThresholdMicros) {
          message += ' (Raster: ${rasterMs}ms)';
        }
        
        // Add current operation if any
        if (_currentOperation != null) {
          message += ' during "$_currentOperation"';
        }
        
        // Check for very slow frames
        if (totalDuration > _warnFrameThresholdMicros) {
          message = '🚨 Very slow frame: ${frameDurationMs}ms';
          
          // Add more details for very slow frames
          message += ' [Build: ${buildMs}ms, Raster: ${rasterMs}ms]';
          
          if (_currentOperation != null) {
            message += ' during "$_currentOperation"';
          }
        }
        
        developer.log(message);
      }
    }
  }
  
  /// Measure async operation performance
  Future<T> measureAsync<T>(String operation, Future<T> Function() task) async {
    startOperation(operation);
    try {
      final stopwatch = Stopwatch()..start();
      final result = await task();
      stopwatch.stop();
      
      if (stopwatch.elapsedMilliseconds > 100) {
        developer.log(
          '⏱️ Async operation "$operation" took ${stopwatch.elapsedMilliseconds}ms',
        );
      }
      
      return result;
    } finally {
      endOperation(operation);
    }
  }
  
  /// Measure sync operation performance
  T measureSync<T>(String operation, T Function() task) {
    startOperation(operation);
    try {
      final stopwatch = Stopwatch()..start();
      final result = task();
      stopwatch.stop();
      
      if (stopwatch.elapsedMilliseconds > 10) {
        developer.log(
          '⏱️ Sync operation "$operation" took ${stopwatch.elapsedMilliseconds}ms',
        );
      }
      
      return result;
    } finally {
      endOperation(operation);
    }
  }
  
  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    if (_recentFrames.isEmpty) {
      return {'error': 'No frame data available'};
    }
    
    final totalFrames = _recentFrames.length;
    final slowFrames = _recentFrames.where((f) => f.totalSpan.inMicroseconds > _slowFrameThresholdMicros).length;
    final verySlowFrames = _recentFrames.where((f) => f.totalSpan.inMicroseconds > _warnFrameThresholdMicros).length;
    
    final avgBuildTime = _recentFrames.map((f) => f.buildDuration.inMicroseconds).reduce((a, b) => a + b) / totalFrames / 1000;
    final avgRasterTime = _recentFrames.map((f) => f.rasterDuration.inMicroseconds).reduce((a, b) => a + b) / totalFrames / 1000;
    final avgTotalTime = _recentFrames.map((f) => f.totalSpan.inMicroseconds).reduce((a, b) => a + b) / totalFrames / 1000;
    
    final maxBuildTime = _recentFrames.map((f) => f.buildDuration.inMicroseconds).reduce((a, b) => a > b ? a : b) / 1000;
    final maxRasterTime = _recentFrames.map((f) => f.rasterDuration.inMicroseconds).reduce((a, b) => a > b ? a : b) / 1000;
    final maxTotalTime = _recentFrames.map((f) => f.totalSpan.inMicroseconds).reduce((a, b) => a > b ? a : b) / 1000;
    
    return {
      'frameCount': totalFrames,
      'slowFrames': slowFrames,
      'verySlowFrames': verySlowFrames,
      'slowFramePercentage': (slowFrames / totalFrames * 100).toStringAsFixed(1),
      'avgBuildTime': avgBuildTime.toStringAsFixed(1),
      'avgRasterTime': avgRasterTime.toStringAsFixed(1),
      'avgTotalTime': avgTotalTime.toStringAsFixed(1),
      'maxBuildTime': maxBuildTime.toStringAsFixed(1),
      'maxRasterTime': maxRasterTime.toStringAsFixed(1),
      'maxTotalTime': maxTotalTime.toStringAsFixed(1),
      'operationTimings': _operationTimings,
      'operationCounts': _operationCounts,
    };
  }
  
  /// Get operation statistics for display
  Map<String, OperationStats> getOperationStats() {
    final stats = <String, OperationStats>{};
    
    _operationTimings.forEach((operation, timings) {
      if (timings.isNotEmpty) {
        final totalTime = timings.reduce((a, b) => a + b);
        final avgTime = totalTime / timings.length;
        final maxTime = timings.reduce((a, b) => a > b ? a : b);
        
        stats[operation] = OperationStats(
          count: _operationCounts[operation] ?? 0,
          totalTime: totalTime.toDouble(),
          averageTime: avgTime.toDouble(),
          maxTime: maxTime.toDouble(),
        );
      }
    });
    
    return stats;
  }

  /// Print detailed performance report
  void printPerformanceReport() {
    final stats = getPerformanceStats();
    if (stats.containsKey('error')) {
      developer.log('📊 ${stats['error']}');
      return;
    }
    
    developer.log('📊 Performance Report (last ${stats['frameCount']} frames):');
    developer.log('   Slow frames: ${stats['slowFrames']} (${stats['slowFramePercentage']}%)');
    developer.log('   Very slow frames: ${stats['verySlowFrames']}');
    developer.log('   Avg build time: ${stats['avgBuildTime']}ms');
    developer.log('   Avg raster time: ${stats['avgRasterTime']}ms');
    developer.log('   Avg total time: ${stats['avgTotalTime']}ms');
    developer.log('   Max build time: ${stats['maxBuildTime']}ms');
    developer.log('   Max raster time: ${stats['maxRasterTime']}ms');
    developer.log('   Max total time: ${stats['maxTotalTime']}ms');
    
    // Print operation timings
    if (_operationTimings.isNotEmpty) {
      developer.log('   Operation timings:');
      for (final entry in _operationTimings.entries) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        final max = entry.value.reduce((a, b) => a > b ? a : b);
        developer.log('     ${entry.key}: avg ${avg.toStringAsFixed(1)}ms, max ${max}ms (${_operationCounts[entry.key]} calls)');
      }
    }
  }
}

/// Map-specific performance profiler for tracking map operations
class MapProfiler {
  static final _instance = PerformanceMonitor();
  
  /// Profile a map operation with automatic timing
  static Future<T> profileMapOperation<T>(String operation, Future<T> Function() task) async {
    return _instance.measureAsync(operation, task);
  }
  
  /// Profile a sync map operation
  static T profileMapOperationSync<T>(String operation, T Function() task) {
    return _instance.measureSync(operation, task);
  }
}