import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A scheduler that respects frame timing to avoid jank
class FrameAwareScheduler {
  static final FrameAwareScheduler _instance = FrameAwareScheduler._internal();
  factory FrameAwareScheduler() => _instance;
  FrameAwareScheduler._internal();

  final Map<String, Timer> _pendingOperations = {};
  final Map<String, DateTime> _lastExecutionTimes = {};
  
  /// Schedule an operation with debouncing and frame awareness
  void scheduleOperation({
    required String id,
    required VoidCallback operation,
    Duration debounce = const Duration(milliseconds: 300),
    Duration minInterval = const Duration(milliseconds: 100),
    bool highPriority = false,
  }) {
    // Cancel any pending operation with the same ID
    _pendingOperations[id]?.cancel();
    
    // Check if we should throttle based on last execution time
    final lastExecution = _lastExecutionTimes[id];
    if (lastExecution != null) {
      final timeSinceLastExecution = DateTime.now().difference(lastExecution);
      if (timeSinceLastExecution < minInterval) {
        // Too soon, increase debounce time
        debounce = minInterval - timeSinceLastExecution + debounce;
      }
    }
    
    // Schedule the operation
    _pendingOperations[id] = Timer(debounce, () {
      _pendingOperations.remove(id);
      
      if (highPriority) {
        // Execute immediately for high priority
        _executeOperation(id, operation);
      } else {
        // Wait for next frame for low priority
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _executeOperation(id, operation);
        });
      }
    });
  }
  
  void _executeOperation(String id, VoidCallback operation) {
    _lastExecutionTimes[id] = DateTime.now();
    
    if (kDebugMode) {
      final stopwatch = Stopwatch()..start();
      operation();
      stopwatch.stop();
      
      if (stopwatch.elapsedMilliseconds > 16) {
        debugPrint('⚠️ Slow operation "$id": ${stopwatch.elapsedMilliseconds}ms');
      }
    } else {
      operation();
    }
  }
  
  /// Cancel a scheduled operation
  void cancelOperation(String id) {
    _pendingOperations[id]?.cancel();
    _pendingOperations.remove(id);
  }
  
  /// Cancel all scheduled operations
  void cancelAll() {
    for (final timer in _pendingOperations.values) {
      timer.cancel();
    }
    _pendingOperations.clear();
  }
  
  /// Check if an operation is pending
  bool isPending(String id) => _pendingOperations.containsKey(id);
}

/// Extension to make it easier to use with widgets
extension FrameAwareSchedulerWidgetExtension on State {
  FrameAwareScheduler get frameScheduler => FrameAwareScheduler();
  
  /// Schedule an operation that will be automatically cancelled when widget disposes
  void scheduleFrameAwareOperation({
    required String id,
    required VoidCallback operation,
    Duration debounce = const Duration(milliseconds: 300),
    bool highPriority = false,
  }) {
    if (!mounted) return;
    
    frameScheduler.scheduleOperation(
      id: '${widget.runtimeType}_$id',
      operation: () {
        if (mounted) operation();
      },
      debounce: debounce,
      highPriority: highPriority,
    );
  }
}