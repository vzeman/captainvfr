import 'package:flutter/material.dart';

class PositionTrackingButton extends StatelessWidget {
  final bool positionTrackingEnabled;
  final bool autoCenteringEnabled;
  final int autoCenteringCountdown;
  final VoidCallback onToggle;

  const PositionTrackingButton({
    super.key,
    required this.positionTrackingEnabled,
    required this.autoCenteringEnabled,
    required this.autoCenteringCountdown,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool showCountdown = positionTrackingEnabled && 
                              !autoCenteringEnabled && 
                              autoCenteringCountdown > 0;
    
    return SizedBox(
      width: showCountdown ? null : 48,
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              positionTrackingEnabled ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: positionTrackingEnabled 
                  ? (autoCenteringEnabled ? Colors.blue : Colors.orange)
                  : Colors.grey,
            ),
            onPressed: onToggle,
            tooltip: positionTrackingEnabled
                ? (autoCenteringEnabled 
                    ? 'Position tracking active (tap to disable)'
                    : showCountdown
                        ? 'Auto-centering in $autoCenteringCountdown seconds'
                        : 'Position tracking paused by map movement (tap to disable)')
                : 'Enable position tracking',
          ),
          if (showCountdown) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatCountdown(autoCenteringCountdown),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _formatCountdown(int seconds) {
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '${minutes}m';
      }
      return '${minutes}m ${remainingSeconds}s';
    }
    return '${seconds}s';
  }
}