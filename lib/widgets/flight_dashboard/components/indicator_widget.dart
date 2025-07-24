import 'package:flutter/material.dart';

/// Widget for displaying a flight indicator with icon, value, unit and label
class IndicatorWidget extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const IndicatorWidget({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic sizing based on available width
        final availableWidth = constraints.maxWidth;
        final iconSize = availableWidth < 80
            ? 12.0
            : (availableWidth < 120 ? 14.0 : 16.0);
        final valueFontSize = availableWidth < 80
            ? 16.0
            : (availableWidth < 120 ? 18.0 : 20.0);
        final unitFontSize = availableWidth < 80
            ? 10.0
            : (availableWidth < 120 ? 11.0 : 12.0);
        final labelFontSize = availableWidth < 80
            ? 8.0
            : (availableWidth < 120 ? 9.0 : 10.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(icon, color: Colors.blueAccent, size: iconSize),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 1),
                    Text(
                      unit,
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: unitFontSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: labelFontSize,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}