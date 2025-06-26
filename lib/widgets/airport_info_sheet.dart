import 'dart:developer' show log;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/airport.dart';

class AirportInfoSheet extends StatelessWidget {
  final Airport airport;
  final VoidCallback onClose;
  final VoidCallback? onNavigate;

  const AirportInfoSheet({
    super.key,
    required this.airport,
    required this.onClose,
    this.onNavigate,
  });

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

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: BorderSide(
            color: theme.colorScheme.outline.withAlpha(102), // 40% opacity
          ),
        ),
      ),
    );
  }

  /// Launches a URL in the default browser or phone app
  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = _parseUrl(url);
      
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      }
    } on FormatException {
      log('Invalid URL format: $url');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL format')),
        );
      }
    } catch (e) {
      log('Could not launch $url', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  /// Parses a URL string into a Uri object, handling various URL formats
  Uri _parseUrl(String url) {
    if (url.startsWith('http://') || 
        url.startsWith('https://') || 
        url.startsWith('tel:')) {
      return Uri.parse(url);
    } else if (url.startsWith('www.')) {
      return Uri.https(url.substring(4));
    } else if (url.contains('@')) {
      return Uri(scheme: 'mailto', path: url);
    } else {
      // Default to https if no scheme is provided
      return Uri.https(url);
    }
  }

  // Build a weather information row with icon and text
  Widget _buildWeatherInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, size: 16, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black, // Default text color
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // Build the weather section of the info sheet
  Widget _buildWeatherSection() {
    if (airport.metarText == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16, top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with flight category
            if (airport.flightCategory != null) ...[
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(airport.flightCategory!),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${airport.flightCategory} Conditions',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (airport.observationTime != null)
                    Text(
                      'Updated: ${DateFormat('HH:mm').format(airport.observationTime!)}Z',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              const Divider(),
            ],
            
            // Weather details
            if (airport.windInfo != null)
              _buildWeatherInfoRow(Icons.air, 'Wind', airport.windInfo!),
              
            if (airport.visibilityInfo != null)
              _buildWeatherInfoRow(Icons.visibility, 'Visibility', airport.visibilityInfo!),
              
            if (airport.cloudCover != null)
              _buildWeatherInfoRow(Icons.cloud, 'Clouds', airport.cloudCover!),
              
            if (airport.temperature != null)
              _buildWeatherInfoRow(Icons.thermostat, 'Temp', airport.temperature!),
              
            if (airport.dewPoint != null)
              _buildWeatherInfoRow(Icons.water_drop, 'Dewpoint', airport.dewPoint!),
              
            if (airport.altimeter != null)
              _buildWeatherInfoRow(Icons.speed, 'Altimeter', airport.altimeter!),
              
            // Raw METAR
            if (airport.metarText != null) ...[
              const Divider(),
              const Text(
                'Raw METAR:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              SelectableText(
                airport.metarText!,
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                ),
              ),
            ],
            
            // Raw TAF if available
            if (airport.tafText != null) ...[
              const Divider(),
              const Text(
                'TAF:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              SelectableText(
                airport.tafText!,
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Helper to get color for flight category
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'VFR':
        return Colors.green;
      case 'MVFR':
        return Colors.blue;
      case 'IFR':
        return Colors.red;
      case 'LIFR':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(51), // 20% opacity of black
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            children: [
              Icon(
                Icons.flight_takeoff,
                color: theme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${airport.icao} - ${airport.name}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                tooltip: 'Close',
              ),
            ],
          ),
          
          const Divider(),
          
          // Weather section
          _buildWeatherSection(),
          
          // Airport details
          _buildInfoRow(context, 'Location', '${airport.city}, ${airport.country}'),
          _buildInfoRow(context, 'Type', airport.typeDisplay),
          _buildInfoRow(context, 'Elevation', '${airport.elevation} ft MSL'),
          
          if (airport.website != null || airport.phone != null) ...[
            const SizedBox(height: 8),
            const Divider(),
            if (airport.phone != null) ...[
              _buildActionButton(
                context: context,
                icon: Icons.phone,
                label: 'Call ${airport.phone}',
                onPressed: () => _launchUrl(context, 'tel:${airport.phone}'),
              ),
            ],
            if (airport.website != null) ...[
              _buildActionButton(
                context: context,
                icon: Icons.language,
                label: 'Visit Website',
                onPressed: () => _launchUrl(context, airport.website!),
              ),
            ],
          ],
          
          // Navigation button
          if (onNavigate != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.navigation, size: 20),
                label: const Text('Navigate to Airport'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
