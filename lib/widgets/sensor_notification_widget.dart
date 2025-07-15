import 'package:flutter/material.dart';

/// A dismissible notification widget for displaying sensor availability warnings
class SensorNotification extends StatelessWidget {
  final String sensorName;
  final String message;
  final VoidCallback onDismiss;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;

  const SensorNotification({
    super.key,
    required this.sensorName,
    required this.message,
    required this.onDismiss,
    this.icon = Icons.sensors_off,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final iColor = iconColor ?? theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(8),
        color: bgColor,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: iColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sensorName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A container widget that manages multiple sensor notifications
class SensorNotificationContainer extends StatefulWidget {
  final List<SensorNotificationData> notifications;
  final Duration animationDuration;
  final Function(String)? onDismiss;

  const SensorNotificationContainer({
    super.key,
    required this.notifications,
    this.animationDuration = const Duration(milliseconds: 300),
    this.onDismiss,
  });

  @override
  State<SensorNotificationContainer> createState() =>
      _SensorNotificationContainerState();
}

class _SensorNotificationContainerState
    extends State<SensorNotificationContainer> {
  late List<String> _dismissedNotifications;

  @override
  void initState() {
    super.initState();
    _dismissedNotifications = [];
  }

  void _dismissNotification(String id) {
    setState(() {
      _dismissedNotifications.add(id);
    });
    widget.onDismiss?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    final activeNotifications = widget.notifications
        .where((n) => !_dismissedNotifications.contains(n.id))
        .toList();

    if (activeNotifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: activeNotifications.map((notification) {
          return AnimatedSize(
            duration: widget.animationDuration,
            child: AnimatedOpacity(
              duration: widget.animationDuration,
              opacity: _dismissedNotifications.contains(notification.id) ? 0 : 1,
              child: SensorNotification(
                sensorName: notification.sensorName,
                message: notification.message,
                icon: notification.icon,
                backgroundColor: notification.backgroundColor,
                iconColor: notification.iconColor,
                onDismiss: () => _dismissNotification(notification.id),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Data class for sensor notifications
class SensorNotificationData {
  final String id;
  final String sensorName;
  final String message;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;

  const SensorNotificationData({
    required this.id,
    required this.sensorName,
    required this.message,
    this.icon = Icons.sensors_off,
    this.backgroundColor,
    this.iconColor,
  });
}