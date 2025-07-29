import 'package:flutter/material.dart';
import '../../models/airport.dart';
import '../../models/frequency.dart';
import '../../models/unified_frequency.dart';
import '../../services/frequency_service.dart';
import '../common/loading_widget.dart';
import '../common/error_widget.dart' as custom;

class AirportFrequenciesTab extends StatefulWidget {
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
  State<AirportFrequenciesTab> createState() => _AirportFrequenciesTabState();
}

class _AirportFrequenciesTabState extends State<AirportFrequenciesTab> {
  List<UnifiedFrequency>? _unifiedFrequencies;
  
  @override
  void initState() {
    super.initState();
    _fetchUnifiedFrequencies();
  }
  
  Future<void> _fetchUnifiedFrequencies() async {
    try {
      final frequencyService = FrequencyService();
      _unifiedFrequencies = frequencyService.getUnifiedFrequenciesForAirport(widget.airport.icao);
    } catch (e) {
      // Silently fail - unified frequencies are optional
    }
  }
  
  bool _hasOpenAIPData() {
    if (_unifiedFrequencies == null || _unifiedFrequencies!.isEmpty) return false;
    return _unifiedFrequencies!.any((freq) => freq.dataSources.contains('openaip'));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const LoadingWidget(message: 'Loading frequency data...');
    }

    if (widget.error != null) {
      return custom.ErrorWidget(error: widget.error!, onRetry: widget.onRetry);
    }

    if (widget.frequencies.isEmpty) {
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
          Row(
            children: [
              Text(
                'Frequencies (${widget.frequencies.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_hasOpenAIPData()) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Enhanced with OpenAIP',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          ...widget.frequencies.map(
            (frequency) => FrequencyCard(frequency: frequency),
          ),
        ],
      ),
    );
  }
}

class FrequencyCard extends StatelessWidget {
  final Frequency frequency;

  const FrequencyCard({super.key, required this.frequency});

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: 0.2,
                    ), // 20% opacity
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
            if (frequency.description != null &&
                frequency.description!.isNotEmpty) ...[
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
