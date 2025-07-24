import 'package:flutter/material.dart';
import '../../../utils/form_theme_helper.dart';

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
        color: FormThemeHelper.sectionBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FormThemeHelper.sectionBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: FormThemeHelper.primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FormThemeHelper.primaryTextColor,
                    ),
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: Icon(Icons.refresh, color: FormThemeHelper.primaryAccent),
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
                style: TextStyle(fontSize: 14, color: FormThemeHelper.secondaryTextColor),
              ),
            ],
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entries: $count',
                  style: TextStyle(fontSize: 16, color: FormThemeHelper.primaryTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated: $lastFetch',
                  style: TextStyle(fontSize: 14, color: FormThemeHelper.secondaryTextColor),
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