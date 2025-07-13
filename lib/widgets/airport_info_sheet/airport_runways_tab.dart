import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/airport.dart';
import '../../models/runway.dart';
import '../../services/runway_service.dart';
import '../../services/settings_service.dart';
import '../common/loading_widget.dart';
import '../common/error_widget.dart' as custom;
import '../common/status_chip.dart';

class AirportRunwaysTab extends StatelessWidget {
  final Airport airport;
  final bool isLoading;
  final String? error;
  final List<Runway> runways;
  final VoidCallback onRetry;
  final RunwayService runwayService;

  const AirportRunwaysTab({
    super.key,
    required this.airport,
    required this.isLoading,
    this.error,
    required this.runways,
    required this.onRetry,
    required this.runwayService,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingWidget(message: 'Loading runway data...');
    }

    if (error != null) {
      return custom.ErrorWidget(error: error!, onRetry: onRetry);
    }

    if (runways.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.airplanemode_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No runway data available for this airport',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Runway Summary
          _buildRunwaySummary(context),
          const SizedBox(height: 16),

          // Individual Runways
          Text(
            'Runways (${runways.length})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...runways.map((runway) => RunwayCard(runway: runway)),
        ],
      ),
    );
  }

  Widget _buildRunwaySummary(BuildContext context) {
    final stats = runwayService.getAirportRunwayStats(airport.icao);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Runway Summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Count',
                    '${stats.count}',
                    Icons.straighten,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Longest',
                    stats.longestFormatted,
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Lighted',
                    stats.hasLightedRunways ? 'Yes' : 'No',
                    stats.hasLightedRunways
                        ? Icons.lightbulb
                        : Icons.lightbulb_outline,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Hard Surface',
                    stats.hasHardSurface ? 'Yes' : 'No',
                    stats.hasHardSurface
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                  ),
                ),
              ],
            ),
            if (stats.surfaces.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(context, 'Surfaces', stats.surfacesFormatted),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.hintColor),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class RunwayCard extends StatelessWidget {
  final Runway runway;

  const RunwayCard({super.key, required this.runway});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';

        // Format length based on units
        final lengthStr = isMetric
            ? '${runway.lengthM.toStringAsFixed(0)} m'
            : runway.lengthFormatted;

        // Format width based on units
        final widthStr = runway.widthFt != null
            ? isMetric
                  ? '${runway.widthM!.toStringAsFixed(0)} m'
                  : '${runway.widthFt} ft'
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Runway designation and basic info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(
                          51,
                        ), // 20% opacity
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        runway.designation,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (runway.lighted)
                      Icon(
                        Icons.lightbulb,
                        size: 16,
                        color: Colors.yellow[700],
                      ),
                    if (runway.closed)
                      Icon(Icons.block, size: 16, color: Colors.red[700]),
                  ],
                ),
                const SizedBox(height: 8),

                // Runway details
                Row(
                  children: [
                    Expanded(
                      child: _buildRunwayDetail(context, 'Length', lengthStr),
                    ),
                    if (widthStr != null)
                      Expanded(
                        child: _buildRunwayDetail(context, 'Width', widthStr),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _buildRunwayDetail(
                        context,
                        'Surface',
                        runway.surfaceFormatted,
                      ),
                    ),
                    if (runway.leHeadingDegT != null ||
                        runway.heHeadingDegT != null)
                      Expanded(
                        child: _buildRunwayDetail(
                          context,
                          'Heading',
                          '${runway.leHeadingDegT?.toStringAsFixed(0) ?? 'N/A'}°/${runway.heHeadingDegT?.toStringAsFixed(0) ?? 'N/A'}°',
                        ),
                      ),
                  ],
                ),

                // Status indicators
                if (runway.closed || runway.lighted) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (runway.lighted)
                        StatusChip(
                          label: 'Lighted',
                          color: Colors.yellow[700]!,
                        ),
                      if (runway.closed)
                        StatusChip(label: 'Closed', color: Colors.red[700]!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRunwayDetail(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
