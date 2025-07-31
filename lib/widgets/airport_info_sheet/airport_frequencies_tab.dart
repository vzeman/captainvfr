import 'package:flutter/material.dart';
import '../../models/airport.dart';
import '../../constants/app_colors.dart';
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
      return custom.ErrorWidget(error: error!, onRetry: onRetry);
    }

    if (frequencies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.radio, size: 48, color: AppColors.secondaryTextColor),
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
                'Frequencies (${frequencies.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...frequencies.map(
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
  
  // Convert frequency type codes to readable names
  String _convertFrequencyType(String type) {
    // Handle empty or null types
    if (type.isEmpty) return 'UNKNOWN';
    
    // If it's a numeric code, convert it
    switch (type) {
      case '0': return 'APPROACH';           // Approach Control
      case '1': return 'AWOS';               // Automated Weather Observing System
      case '2': return 'AWIB';               // Automated Weather Information Broadcast
      case '3': return 'AWIS';               // Automated Weather Information Service
      case '4': return 'CTAF';               // Common Traffic Advisory Frequency
      case '5': return 'MULTICOM';           // Multicom
      case '6': return 'UNICOM';             // Unicom
      case '7': return 'DELIVERY';           // Clearance Delivery
      case '8': return 'GROUND';             // Ground Control
      case '9': return 'TOWER';              // Control Tower
      case '10': return 'APPROACH';          // Approach Control
      case '11': return 'DEPARTURE';         // Departure Control
      case '12': return 'CENTER';            // Air Route Traffic Control Center
      case '13': return 'FSS';               // Flight Service Station
      case '14': return 'CLEARANCE';         // Clearance Delivery
      case '15': return 'ATIS';              // Automated Terminal Information Service
      case '16': return 'RADIO';             // Radio/Communication
      case '17': return 'EMERGENCY';         // Emergency Frequency
      case '18': return 'OPERATIONS';        // Airport Operations
      case '19': return 'WEATHER';           // Weather Information
      case '20': return 'RAMP';              // Ramp Control
      case '21': return 'COMPANY';           // Company Frequency
      case '22': return 'FIRE';              // Fire/Crash/Rescue
      case '23': return 'MAINTENANCE';       // Maintenance
      case '24': return 'SECURITY';          // Security
      case '25': return 'MEDICAL';           // Medical Emergency
      case '26': return 'CUSTOMS';           // Customs
      case '27': return 'IMMIGRATION';       // Immigration
      case '28': return 'FUEL';              // Fuel Services
      case '29': return 'CATERING';          // Catering Services
      case '30': return 'AIR CARGO';         // Air Cargo
      default: return type.toUpperCase();    // Return original if not in our mapping
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.sectionBackgroundColor,
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
                    _convertFrequencyType(frequency.type),
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
                  color: AppColors.secondaryTextColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
