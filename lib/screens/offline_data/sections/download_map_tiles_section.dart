import 'package:flutter/material.dart';
import '../../../utils/form_theme_helper.dart';
import '../controllers/offline_data_state_controller.dart';

/// Download map tiles section widget
class DownloadMapTilesSection extends StatelessWidget {
  final OfflineDataStateController controller;
  final VoidCallback onDownload;
  final VoidCallback onStopDownload;

  const DownloadMapTilesSection({
    super.key,
    required this.controller,
    required this.onDownload,
    required this.onStopDownload,
  });

  @override
  Widget build(BuildContext context) {
    return FormThemeHelper.buildSection(
      title: 'Download Map Tiles',
      children: [
        Text(
          'Download map tiles for offline use',
          style: TextStyle(color: FormThemeHelper.secondaryTextColor),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Min Zoom: ${controller.minZoom}',
                    style: TextStyle(color: FormThemeHelper.primaryTextColor),
                  ),
                  Slider(
                    value: controller.minZoom.toDouble(),
                    min: 1,
                    max: 18,
                    divisions: 17,
                    label: controller.minZoom.toString(),
                    activeColor: FormThemeHelper.primaryAccent,
                    onChanged: (value) {
                      controller.setMinZoom(value.toInt());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Max Zoom: ${controller.maxZoom}',
                    style: TextStyle(color: FormThemeHelper.primaryTextColor),
                  ),
                  Slider(
                    value: controller.maxZoom.toDouble(),
                    min: 1,
                    max: 18,
                    divisions: 17,
                    label: controller.maxZoom.toString(),
                    activeColor: FormThemeHelper.primaryAccent,
                    onChanged: (value) {
                      controller.setMaxZoom(value.toInt());
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (controller.isDownloading) ...[
          LinearProgressIndicator(
            value: controller.downloadProgress,
            backgroundColor: FormThemeHelper.borderColor.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(FormThemeHelper.primaryAccent),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: ${controller.currentTiles} / ${controller.totalTiles} tiles',
                style: TextStyle(color: FormThemeHelper.secondaryTextColor),
              ),
              Text(
                '${(controller.downloadProgress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: FormThemeHelper.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Downloaded: ${controller.downloadedTiles}',
                style: TextStyle(
                  fontSize: 12,
                  color: FormThemeHelper.secondaryTextColor,
                ),
              ),
              Text(
                'Skipped: ${controller.skippedTiles}',
                style: TextStyle(
                  fontSize: 12,
                  color: FormThemeHelper.secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onStopDownload,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.stop),
            label: const Text('Stop Download'),
          ),
        ] else
          ElevatedButton.icon(
            onPressed: onDownload,
            style: FormThemeHelper.getPrimaryButtonStyle(),
            icon: const Icon(Icons.download),
            label: const Text('Download Current Area'),
          ),
      ],
    );
  }
}