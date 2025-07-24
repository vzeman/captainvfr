import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LayerToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  const LayerToggleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon == FontAwesomeIcons.helicopter 
          ? FaIcon(icon, color: isActive ? Colors.blue : Colors.black, size: 20)
          : Icon(icon, color: isActive ? Colors.blue : Colors.black),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}