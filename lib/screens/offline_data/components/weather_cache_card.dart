import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_theme.dart';

/// Weather cache card with METAR/TAF specific display
class WeatherCacheCard extends StatelessWidget {
  final int metarCount;
  final int tafCount;
  final String lastFetch;
  final VoidCallback onClear;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  const WeatherCacheCard({
    super.key,
    required this.metarCount,
    required this.tafCount,
    required this.lastFetch,
    required this.onClear,
    this.onRefresh,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: AppTheme.extraLargeRadius,
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, size: 24, color: AppColors.primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Weather Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: Icon(Icons.refresh, color: AppColors.primaryAccent),
                    onPressed: isRefreshing ? null : onRefresh,
                    tooltip: 'Refresh weather data',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onClear,
                  tooltip: 'Clear cache',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'METARs, TAFs, and weather information',
              style: TextStyle(fontSize: 14, color: AppColors.secondaryTextColor),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'METARs: $metarCount',
                      style: TextStyle(fontSize: 16, color: AppColors.primaryTextColor),
                    ),
                    Text(
                      'TAFs: $tafCount',
                      style: TextStyle(fontSize: 16, color: AppColors.primaryTextColor),
                    ),
                  ],
                ),
                Text(
                  'Updated: $lastFetch',
                  style: TextStyle(fontSize: 14, color: AppColors.secondaryTextColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}