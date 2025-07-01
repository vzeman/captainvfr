import 'package:flutter/material.dart';
import '../../models/airport.dart';
import '../../models/frequency.dart';
import '../common/loading_widget.dart';
import '../common/error_widget.dart' as custom;

class AirportFrequenciesTab extends StatelessWidget {
  final Airport airport;
  final bool isLoading;
  final String? error;
  final List<Frequency> frequencies;
  final VoidCallback onRetry;

  const AirportFrequenciesTab({
    super.key,
    required this.airport,
    required this.isLoading,
    this.error,
    required this.frequencies,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingWidget(message: 'Loading frequency data...');
    }

    if (error != null) {
      return custom.ErrorWidget(
        error: error!,
        onRetry: onRetry,
      );
    }

    if (frequencies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radio, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No frequency data available for this airport',
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
          // Frequency List
          Text(
            'Frequencies (${frequencies.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          ...frequencies.map((frequency) => FrequencyCard(frequency: frequency)),
        ],
      ),
    );
  }
}

class FrequencyCard extends StatelessWidget {
  final Frequency frequency;

  const FrequencyCard({
    super.key,
    required this.frequency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Frequency header with type and frequency
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(51), // 20% opacity
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    frequency.type,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  frequency.frequencyFormatted,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            // Description if available
            if (frequency.description != null && frequency.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                frequency.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
