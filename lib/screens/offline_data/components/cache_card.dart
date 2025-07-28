import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_theme.dart';

/// Reusable cache card widget for displaying cache statistics
class CacheCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final String lastFetch;
  final VoidCallback onClear;
  final String? subtitle;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  const CacheCard({
    super.key,
    required this.title,
    required this.icon,
    required this.count,
    required this.lastFetch,
    required this.onClear,
    this.subtitle,
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
                Icon(icon, size: 24, color: AppColors.primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
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
                    tooltip: 'Refresh $title',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onClear,
                  tooltip: 'Clear cache',
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 14, color: AppColors.secondaryTextColor),
              ),
            ],
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entries: $count',
                  style: TextStyle(fontSize: 16, color: AppColors.primaryTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated: $lastFetch',
                  style: TextStyle(fontSize: 14, color: AppColors.secondaryTextColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}