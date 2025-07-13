import 'package:flutter/material.dart';
import '../../models/airport.dart';
import '../../services/weather_interpretation_service.dart';
import '../common/loading_widget.dart';
import '../common/error_widget.dart' as custom;

class AirportWeatherTab extends StatelessWidget {
  final Airport airport;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final WeatherInterpretationService weatherInterpretationService;

  const AirportWeatherTab({
    super.key,
    required this.airport,
    required this.isLoading,
    this.error,
    required this.onRetry,
    required this.weatherInterpretationService,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingWidget(message: 'Loading weather data...');
    }

    if (error != null) {
      return custom.ErrorWidget(error: error!, onRetry: onRetry);
    }

    // Display weather data if available
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // METAR Section
          if (airport.rawMetar != null) ...[
            _buildMetarSection(context),
            const SizedBox(height: 16),
          ],

          // TAF Section
          if (airport.taf != null) ...[
            _buildTafSection(context),
            const SizedBox(height: 16),
          ],

          // Last updated info
          if (airport.lastWeatherUpdate != null) ...[
            _buildLastUpdatedSection(context),
            const SizedBox(height: 16),
          ],

          // No weather data message
          if (airport.rawMetar == null && airport.taf == null) ...[
            _buildNoDataSection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildMetarSection(BuildContext context) {
    final theme = Theme.of(context);
    final hasDangerousWeather = weatherInterpretationService
        .hasDangerousWeatherInMetar(airport.rawMetar!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'METAR',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: hasDangerousWeather ? Colors.red.shade700 : Colors.green,
          ),
        ),
        const SizedBox(height: 8),

        // Human-readable interpretation
        _buildInterpretationCard(
          context,
          interpretation: weatherInterpretationService.interpretMetar(
            airport.rawMetar!,
          ),
          isDangerous: hasDangerousWeather,
          dangerousConditions: hasDangerousWeather
              ? weatherInterpretationService.getDangerousWeatherInMetar(
                  airport.rawMetar!,
                )
              : [],
          color: hasDangerousWeather ? Colors.red.shade700 : Colors.green,
        ),
        const SizedBox(height: 12),

        // Raw METAR data
        _buildRawDataCard(context, 'Raw METAR', airport.rawMetar!),
      ],
    );
  }

  Widget _buildTafSection(BuildContext context) {
    final theme = Theme.of(context);
    final hasDangerousWeather = weatherInterpretationService
        .hasDangerousWeatherInTaf(airport.taf!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TAF',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: hasDangerousWeather ? Colors.red.shade700 : Colors.blue,
          ),
        ),
        const SizedBox(height: 8),

        // Human-readable interpretation
        _buildInterpretationCard(
          context,
          interpretation: weatherInterpretationService.interpretTaf(
            airport.taf!,
          ),
          isDangerous: hasDangerousWeather,
          dangerousConditions: hasDangerousWeather
              ? weatherInterpretationService.getDangerousWeatherInTaf(
                  airport.taf!,
                )
              : [],
          color: hasDangerousWeather ? Colors.red.shade700 : Colors.blue,
        ),
        const SizedBox(height: 12),

        // Raw TAF data
        _buildRawDataCard(context, 'Raw TAF', airport.taf!),
      ],
    );
  }

  Widget _buildInterpretationCard(
    BuildContext context, {
    required String interpretation,
    required bool isDangerous,
    required List<String> dangerousConditions,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDangerous ? Colors.red.shade50 : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDangerous
              ? Colors.red.shade300
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDangerous ? Icons.warning_amber_outlined : Icons.info_outline,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                isDangerous
                    ? 'CAUTION - Dangerous Weather Conditions'
                    : 'Interpretation',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(interpretation, style: theme.textTheme.bodyMedium),
          // Add dangerous weather explanations if present
          if (isDangerous) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Dangerous Conditions ${dangerousConditions.length > 5 ? 'Forecasted:' : 'Detected:'}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...dangerousConditions.map(
              (condition) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  '• $condition',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRawDataCard(BuildContext context, String title, String data) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last Updated',
          style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          airport.lastWeatherUpdate!.toLocal().toString().substring(0, 19),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }

  Widget _buildNoDataSection(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 48, color: theme.hintColor),
          const SizedBox(height: 16),
          Text(
            'No weather data available for ${airport.icao}',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Refresh Weather'),
          ),
        ],
      ),
    );
  }
}
