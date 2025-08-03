import 'package:flutter/material.dart';
import '../../../constants/app_theme.dart';

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
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
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
        ),
        if (showCountdown)
          Positioned(
            right: -5,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: AppTheme.extraLargeRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _formatCountdown(autoCenteringCountdown),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
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