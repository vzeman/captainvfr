import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/logbook_service.dart';
import '../../models/logbook_entry.dart';
import 'logbook_entry_dialog.dart';

class LogBookEntriesTab extends StatelessWidget {
  const LogBookEntriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final logBookService = context.watch<LogBookService>();
    final entries = logBookService.entries;

    return Scaffold(
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No logbook entries yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first flight entry',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _LogBookEntryTile(entry: entry);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          LogBookEntryDialog.show(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LogBookEntryTile extends StatelessWidget {
  final LogBookEntry entry;

  const _LogBookEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: () {
          LogBookEntryDialog.show(context, entry: entry);
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.route,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              entry.formatDuration(entry.totalDuration),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(dateFormat.format(entry.dateTimeStarted)),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${timeFormat.format(entry.dateTimeStarted)} - ${timeFormat.format(entry.dateTimeFinished)}',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (entry.aircraftType != null) ...[
                  Icon(
                    Icons.airplanemode_active,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(entry.aircraftType!),
                  if (entry.aircraftIdentification != null) ...[
                    Text(' (${entry.aircraftIdentification})'),
                  ],
                  const SizedBox(width: 16),
                ],
                if (entry.flightCondition != null) ...[
                  Icon(
                    entry.flightCondition == FlightCondition.day
                        ? Icons.wb_sunny
                        : Icons.nightlight_round,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(entry.flightCondition == FlightCondition.day 
                      ? 'Day' 
                      : 'Night'),
                  const SizedBox(width: 16),
                ],
                if (entry.flightRules != null) ...[
                  Text(
                    entry.flightRules!.name.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Entry'),
                  content: const Text(
                    'Are you sure you want to delete this logbook entry?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await context.read<LogBookService>().deleteEntry(entry.id);
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}