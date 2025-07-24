import 'package:flutter/material.dart';

/// Small version of indicator widget for compact displays
class SmallIndicatorWidget extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const SmallIndicatorWidget({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic sizing for small indicators
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // Adjust sizes based on available space
        final iconSize = availableHeight < 32
            ? 10.0
            : (availableWidth < 60
                  ? 10.0
                  : (availableWidth < 80 ? 12.0 : 14.0));
        final valueFontSize = availableHeight < 32
            ? 9.0
            : (availableWidth < 60
                  ? 10.0
                  : (availableWidth < 80 ? 11.0 : 12.0));
        final labelFontSize = availableHeight < 32
            ? 7.0
            : (availableWidth < 60 ? 8.0 : 9.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.blueAccent, size: iconSize),
                    const SizedBox(width: 1),
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: labelFontSize,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}