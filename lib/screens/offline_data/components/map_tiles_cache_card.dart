import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_theme.dart';

/// Map tiles cache card with zoom level breakdown
class MapTilesCacheCard extends StatelessWidget {
  final Map<String, dynamic>? cacheStats;
  final VoidCallback onClear;

  const MapTilesCacheCard({
    super.key,
    required this.cacheStats,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final tileCount = cacheStats?['tileCount'] ?? 0;
    final totalSizeBytes = cacheStats?['totalSizeBytes'] ?? 0;
    final totalSizeMB = totalSizeBytes / 1024 / 1024;
    final tilesByZoom = cacheStats?['tilesByZoom'] as Map<int, Map<String, int>>?;

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
                Icon(Icons.map, size: 24, color: AppColors.primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Map Tiles Cache',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onClear,
                  tooltip: 'Clear map cache',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (tileCount > 0) ...[
              Text(
                'Total tiles: $tileCount',
                style: TextStyle(fontSize: 16, color: AppColors.primaryTextColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Total size: ${totalSizeMB.toStringAsFixed(2)} MB',
                style: TextStyle(fontSize: 16, color: AppColors.primaryTextColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Tiles by zoom level:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              if (tilesByZoom != null)
                ...tilesByZoom.entries.map((entry) {
                  final zoom = entry.key;
                  final count = entry.value['count'] ?? 0;
                  final sizeBytes = entry.value['sizeBytes'] ?? 0;
                  final sizeMB = sizeBytes / 1024 / 1024;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Zoom $zoom:',
                          style: TextStyle(color: AppColors.secondaryTextColor),
                        ),
                        Text(
                          '$count tiles (${sizeMB.toStringAsFixed(2)} MB)',
                          style: TextStyle(color: AppColors.secondaryTextColor),
                        ),
                      ],
                    ),
                  );
                }),
            ] else
              Text(
                'No cached tiles',
                style: TextStyle(fontSize: 16, color: AppColors.secondaryTextColor),
              ),
          ],
        ),
      ),
    );
  }
}