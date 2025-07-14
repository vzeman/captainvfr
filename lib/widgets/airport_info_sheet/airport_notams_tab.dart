import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/airport.dart';
import '../../models/notam.dart';
import '../../services/notam_service.dart';
import '../../services/notam_service_v2.dart';
import '../../services/notam_service_v3.dart';

class AirportNotamsTab extends StatefulWidget {
  final Airport airport;

  const AirportNotamsTab({super.key, required this.airport});

  @override
  State<AirportNotamsTab> createState() => _AirportNotamsTabState();
}

class _AirportNotamsTabState extends State<AirportNotamsTab> {
  // Use late initialization to ensure fresh instances
  late final NotamService _notamService;
  late final NotamServiceV2 _notamServiceV2;
  late final NotamServiceV3 _notamServiceV3;
  List<Notam> _notams = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();
    // Initialize services
    _notamService = NotamService();
    _notamServiceV2 = NotamServiceV2();
    _notamServiceV3 = NotamServiceV3();

    // Clear any existing NOTAMs to prevent showing stale data
    _notams = [];
    _error = null;
    _lastFetch = null;

    // Add a small delay to ensure the widget is properly mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotams(forceRefresh: true); // Force refresh on initial load
    });
  }

  @override
  void didUpdateWidget(AirportNotamsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the airport changed, reload NOTAMs
    if (oldWidget.airport.icao != widget.airport.icao) {
      developer.log(
        '📋 Airport changed from ${oldWidget.airport.icao} to ${widget.airport.icao}, reloading NOTAMs',
      );
      // Clear existing NOTAMs immediately to prevent showing wrong data
      setState(() {
        _notams = [];
        _error = null;
        _lastFetch = null;
      });
      _loadNotams(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    // Clean up any pending operations
    super.dispose();
  }

  Future<void> _loadNotams({bool forceRefresh = false}) async {
    if (!mounted) return;

    developer.log(
      '📋 Loading NOTAMs for ${widget.airport.icao} (forceRefresh: $forceRefresh)',
    );

    setState(() {
      _isLoading = !forceRefresh;
      _isRefreshing = forceRefresh;
      _error = null;
      if (!forceRefresh) {
        // Clear NOTAMs when not refreshing to prevent showing stale data
        _notams = [];
      }
    });

    try {
      List<Notam> notams = [];
      
      // Check if it's a European airport first
      final icaoPrefix = widget.airport.icao.substring(0, 2);

      // If not European or no results, try V3 service
      if (notams.isEmpty) {
        notams = await _notamServiceV3.getNotamsForAirport(
          widget.airport.icao,
          forceRefresh: forceRefresh,
        );
      }

      // If V3 fails or returns empty, try other services
      if (notams.isEmpty) {
        developer.log('📋 V3 returned no NOTAMs, trying V2...');
        try {
          notams = await _notamServiceV2.getNotamsForAirport(
            widget.airport.icao,
            forceRefresh: forceRefresh,
          );
        } catch (e) {
          developer.log('📋 V2 failed, trying V1...');
          // Fall back to V1 service
          notams = await _notamService.getNotamsForAirport(
            widget.airport.icao,
            forceRefresh: forceRefresh,
          );
        }
      }

      if (mounted) {
        setState(() {
          _notams = notams;
          _isLoading = false;
          _isRefreshing = false;
          _lastFetch = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadNotams(forceRefresh: true),
      child: Stack(
        children: [
          // Main content
          _notams.isEmpty ? _buildEmptyState() : _buildNotamsList(),

          // Refresh button overlay
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_lastFetch != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'Updated ${_formatLastFetch(_lastFetch!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Material(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isRefreshing
                        ? null
                        : () => _loadNotams(forceRefresh: true),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _isRefreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.refresh,
                              size: 20,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _error != null ? 'Error loading NOTAMs' : 'No NOTAMs available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'No active NOTAMs for ${widget.airport.icao}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadNotams(forceRefresh: true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotamsList() {
    // Group NOTAMs by category
    final groupedNotams = <String, List<Notam>>{};
    for (final notam in _notams) {
      final category = notam.category ?? NotamCategory.other;
      groupedNotams.putIfAbsent(category, () => []).add(notam);
    }

    // Sort categories by importance
    final sortedCategories = groupedNotams.keys.toList()
      ..sort((a, b) {
        const categoryOrder = [
          NotamCategory.runway,
          NotamCategory.taxiway,
          NotamCategory.navaid,
          NotamCategory.airspace,
          NotamCategory.obstacle,
          NotamCategory.apron,
          NotamCategory.services,
          NotamCategory.other,
        ];
        return categoryOrder.indexOf(a).compareTo(categoryOrder.indexOf(b));
      });

    return ListView.builder(
      padding: const EdgeInsets.only(top: 48, bottom: 16),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final categoryNotams = groupedNotams[category]!;

        return _buildCategorySection(category, categoryNotams);
      },
    );
  }

  Widget _buildCategorySection(String category, List<Notam> notams) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                _getCategoryIcon(category),
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${notams.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...notams.map((notam) => _buildNotamCard(notam)),
      ],
    );
  }

  Widget _buildNotamCard(Notam notam) {
    final theme = Theme.of(context);
    final isExpired = notam.isExpired;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isExpired
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : theme.colorScheme.surface,
      child: ExpansionTile(
        leading: _buildImportanceIndicator(notam),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notam.notamId,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: isExpired ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            _buildStatusChip(notam),
          ],
        ),
        subtitle: Text(
          _getNotamPreview(notam),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isExpired
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full text
                if (notam.decodedText != null) ...[
                  _buildDetailRow('Plain Language', notam.decodedText!),
                  const SizedBox(height: 12),
                ],

                // ICAO format text
                _buildDetailRow('ICAO Format', notam.text),
                const SizedBox(height: 12),

                // Validity period
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: notam.isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : notam.isFuture
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: notam.isActive
                          ? Colors.green.withValues(alpha: 0.3)
                          : notam.isFuture
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          'Effective From',
                          _formatDateTime(notam.effectiveFrom),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDetailRow(
                          'Until',
                          notam.effectiveUntil != null
                              ? _formatDateTime(notam.effectiveUntil!)
                              : 'PERMANENT',
                        ),
                      ),
                    ],
                  ),
                ),

                // Schedule if available
                if (notam.schedule.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Schedule', notam.schedule),
                ],

                // Additional info
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (notam.traffic != null)
                      _buildInfoChip(
                        _getTrafficLabel(notam.traffic!),
                        theme.colorScheme.primaryContainer,
                      ),
                    const SizedBox(width: 8),
                    if (notam.purpose != null)
                      _buildInfoChip(
                        notam.purpose!,
                        theme.colorScheme.secondaryContainer,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportanceIndicator(Notam notam) {
    Color color;
    IconData icon;

    switch (notam.importance) {
      case NotamImportance.critical:
        color = Colors.red;
        icon = Icons.error;
        break;
      case NotamImportance.high:
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case NotamImportance.medium:
        color = Colors.yellow.shade700;
        icon = Icons.info;
        break;
      case NotamImportance.low:
        color = Colors.blue;
        icon = Icons.info_outline;
        break;
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildStatusChip(Notam notam) {
    final theme = Theme.of(context);
    Color backgroundColor;
    Color textColor;

    if (notam.isExpired) {
      backgroundColor = theme.colorScheme.errorContainer;
      textColor = theme.colorScheme.onErrorContainer;
    } else if (notam.isFuture) {
      backgroundColor = theme.colorScheme.tertiaryContainer;
      textColor = theme.colorScheme.onTertiaryContainer;
    } else {
      backgroundColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        notam.status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);

    // Special formatting for ICAO format NOTAMs
    if (label == 'ICAO Format') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: SelectableText(
              _formatNotamText(value),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }

  String _formatNotamText(String text) {
    // Format NOTAM text for better readability
    // Each field on its own line, properly indented
    final lines = text.split('\n');
    final formattedLines = <String>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      // Check if this is a field line (starts with letter followed by ))
      if (RegExp(r'^[A-Z]\)').hasMatch(line.trim())) {
        formattedLines.add(line.trim());
      } else if (line.contains('NOTAM')) {
        // NOTAM header line
        formattedLines.add(line.trim());
      } else {
        // Continuation of previous field - indent it
        formattedLines.add('   ${line.trim()}');
      }
    }

    return formattedLines.join('\n');
  }

  String _getNotamPreview(Notam notam) {
    // If we have decoded text, use that
    if (notam.decodedText != null && notam.decodedText!.isNotEmpty) {
      return notam.decodedText!;
    }

    // Otherwise, try to extract the E) field from ICAO format
    final eFieldMatch = RegExp(
      r'E\)\s*(.+?)(?:\n|$)',
      multiLine: true,
    ).firstMatch(notam.text);
    if (eFieldMatch != null) {
      return eFieldMatch.group(1)?.trim() ?? notam.text;
    }

    // Fallback to first meaningful line
    final lines = notam.text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.contains('NOTAM')) {
        return trimmed;
      }
    }

    return notam.text;
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case NotamCategory.runway:
        return Icons.flight_land;
      case NotamCategory.taxiway:
        return Icons.timeline;
      case NotamCategory.navaid:
        return Icons.radar;
      case NotamCategory.airspace:
        return Icons.cloud_queue;
      case NotamCategory.obstacle:
        return Icons.warning;
      case NotamCategory.apron:
        return Icons.local_parking;
      case NotamCategory.services:
        return Icons.miscellaneous_services;
      default:
        return Icons.description;
    }
  }

  String _getTrafficLabel(String traffic) {
    switch (traffic) {
      case 'I':
        return 'IFR';
      case 'V':
        return 'VFR';
      case 'IV':
        return 'IFR/VFR';
      default:
        return traffic;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy HH:mm');
    return '${formatter.format(dateTime.toLocal())} LCL';
  }

  String _formatLastFetch(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
