import 'package:flutter/material.dart';
import '../models/navaid.dart';

class NavaidInfoSheet extends StatelessWidget {
  final Navaid navaid;
  final VoidCallback onClose;

  const NavaidInfoSheet({
    super.key,
    required this.navaid,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.explore, color: Colors.blue[700], size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        navaid.ident,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        navaid.name,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Type', navaid.type.toUpperCase()),
                _buildInfoRow(
                  'Frequency',
                  '${navaid.frequencyKhz.toStringAsFixed(1)} kHz',
                ),
                _buildInfoRow(
                  'Position',
                  '${navaid.position.latitude.toStringAsFixed(6)}, ${navaid.position.longitude.toStringAsFixed(6)}',
                ),
                _buildInfoRow('Elevation', '${navaid.elevationFt} ft'),
                _buildInfoRow('Country', navaid.isoCountry),
                if (navaid.usageType.isNotEmpty)
                  _buildInfoRow('Usage', navaid.usageType),
                if (navaid.associatedAirport.isNotEmpty)
                  _buildInfoRow('Airport', navaid.associatedAirport),
                if (navaid.dmeFrequencyKhz > 0)
                  _buildInfoRow(
                    'DME Frequency',
                    '${navaid.dmeFrequencyKhz.toStringAsFixed(1)} kHz',
                  ),
                if (navaid.dmeChannel.isNotEmpty)
                  _buildInfoRow('DME Channel', navaid.dmeChannel),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Add to flight plan functionality could be added here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Add to flight plan feature coming soon!',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_location),
                    label: const Text('Add to Flight Plan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}
