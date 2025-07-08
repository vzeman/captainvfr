import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/flight_service.dart';
import '../models/flight.dart';
import '../widgets/themed_dialog.dart';
import 'flight_detail_screen.dart';

class FlightLogScreen extends StatelessWidget {
  const FlightLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flight Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<FlightService>(
        builder: (context, flightService, child) {
          final flights = flightService.flights.reversed.toList(); // Reverse to show newest first

          if (flights.isEmpty) {
            return const Center(
              child: Text('No flights recorded yet.'),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: flights.length,
            itemBuilder: (context, index) {
              final flight = flights[index];
              return _buildFlightItem(context, flight);
            },
          );
        },
      ),
    );
  }
  
  Widget _buildFlightItem(BuildContext context, Flight flight) {
    final dateStr = '${flight.startTime.day}/${flight.startTime.month}/${flight.startTime.year} ' 
        '${flight.startTime.hour}:${flight.startTime.minute.toString().padLeft(2, '0')}';
    final duration = flight.duration;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FlightDetailScreen(flight: flight),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      dateStr,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$hours:${minutes}h',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                        onPressed: () => _showDeleteConfirmation(context, flight),
                        tooltip: 'Delete flight',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(
                    context,
                    icon: Icons.height,
                    label: '${flight.maxAltitude.toStringAsFixed(0)} m',
                  ),
                  _buildInfoChip(
                    context,
                    icon: Icons.speed,
                    label: '${(flight.maxSpeed * 3.6).toStringAsFixed(1)} km/h',
                  ),
                  _buildInfoChip(
                    context,
                    icon: Icons.airplanemode_active,
                    label: '${flight.path.length} pts',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoChip(BuildContext context, {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Flight flight) {
    final dateStr = '${flight.startTime.day}/${flight.startTime.month}/${flight.startTime.year} '
        '${flight.startTime.hour}:${flight.startTime.minute.toString().padLeft(2, '0')}';

    ThemedDialog.showConfirmation(
      context: context,
      title: 'Delete Flight',
      message: 'Are you sure you want to delete the flight from $dateStr?\n\nThis action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      destructive: true,
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        _deleteFlight(context, flight);
      }
    });
  }

  Future<void> _deleteFlight(BuildContext context, Flight flight) async {
    try {
      final flightService = Provider.of<FlightService>(context, listen: false);
      await flightService.deleteFlight(flight);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flight deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting flight: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
