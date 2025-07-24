import 'dart:math' show pi;
import 'package:flutter/material.dart';

/// Custom icons for the flight dashboard
class FlightIcons {
  // Compass icon that can be rotated
  static Widget compass(double? heading, {double size = 24}) {
    return Transform.rotate(
      angle: (heading ?? 0) * (pi / 180) * -1,
      child: Icon(Icons.explore, size: size, color: Colors.blueAccent),
    );
  }

  // Altitude icon
  static const IconData altitude = Icons.terrain;

  // Speed icon
  static const IconData speed = Icons.speed;

  // Time icon
  static const IconData time = Icons.timer;

  // Distance icon
  static const IconData distance = Icons.terrain;

  // Vertical speed icon
  static const IconData verticalSpeed = Icons.linear_scale;

  // Baro icon
  static const IconData baro = Icons.speed;
}