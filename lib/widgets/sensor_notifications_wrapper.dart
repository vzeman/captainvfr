import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sensor_availability_service.dart';
import 'sensor_notification_widget.dart';

/// Wrapper widget that displays sensor availability notifications
class SensorNotificationsWrapper extends StatelessWidget {
  final Widget child;

  const SensorNotificationsWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Consumer<SensorAvailabilityService>(
            builder: (context, sensorService, _) {
              if (sensorService.notifications.isEmpty) {
                return const SizedBox.shrink();
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SensorNotificationContainer(
                    notifications: sensorService.notifications,
                    onDismiss: (id) => sensorService.dismissNotification(id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}