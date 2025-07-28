import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/logbook_service.dart';
import '../../models/logbook_entry.dart';
import 'logbook_entry_dialog.dart';
import '../../constants/app_colors.dart';
import '../../widgets/themed_dialog.dart';
import '../../constants/app_theme.dart';

class LogBookEntriesTab extends StatelessWidget {
  const LogBookEntriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final logBookService = context.watch<LogBookService>();
    final entries = logBookService.entries;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book,
                    size: 64,
                    color: AppColors.secondaryTextColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No logbook entries yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first flight entry',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.secondaryTextColor,
                    ),
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
        backgroundColor: AppColors.primaryAccent,
        foregroundColor: Colors.white,
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
      color: AppColors.sectionBackgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.defaultRadius,
        side: BorderSide(color: AppColors.sectionBorderColor),
      ),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTextColor,
                ),
              ),
            ),
            Text(
              entry.formatDuration(entry.totalDuration),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryAccent,
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
                  color: AppColors.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(entry.dateTimeStarted),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${timeFormat.format(entry.dateTimeStarted)} - ${timeFormat.format(entry.dateTimeFinished)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryTextColor,
                  ),
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
                    color: AppColors.secondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.aircraftType!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  if (entry.aircraftIdentification != null) ...[
                    Text(
                      ' (${entry.aircraftIdentification})',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                  ],
                  const SizedBox(width: 16),
                ],
                if (entry.flightCondition != null) ...[
                  Icon(
                    entry.flightCondition == FlightCondition.day
                        ? Icons.wb_sunny
                        : Icons.nightlight_round,
                    size: 16,
                    color: AppColors.secondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.flightCondition == FlightCondition.day 
                        ? 'Day' 
                        : 'Night',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (entry.flightRules != null) ...[
                  Text(
                    entry.flightRules!.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          color: AppColors.dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.defaultRadius,
            side: BorderSide(color: AppColors.sectionBorderColor),
          ),
          onSelected: (value) async {
            if (value == 'delete') {
              final confirmed = await ThemedDialog.showConfirmation(
                context: context,
                title: 'Delete Entry',
                message: 'Are you sure you want to delete this logbook entry?',
                confirmText: 'Delete',
                cancelText: 'Cancel',
                destructive: true,
              );

              if (confirmed == true && context.mounted) {
                await context.read<LogBookService>().deleteEntry(entry.id);
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}