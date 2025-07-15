import 'dart:developer' as developer;
import 'package:flutter/scheduler.dart';

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
    
    // Log if operation took more than 10ms
    if (duration.inMilliseconds > 10) {
      developer.log(
        '⏱️ Operation "${operation ?? _currentOperation}" took ${duration.inMilliseconds}ms',
      );
    }
    
    _currentOperation = null;
    _operationStartTime = null;
  }
  
  /// Handle frame timings
  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
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
}