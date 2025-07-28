import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/logbook_service.dart';
import '../../services/pilot_service.dart';
import '../../widgets/common/info_row.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';

class LogBookSummaryTab extends StatelessWidget {
  const LogBookSummaryTab({super.key});

  Widget _buildCard({required Widget child}) {
    return Card(
      color: AppColors.sectionBackgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.defaultRadius,
        side: BorderSide(color: AppColors.sectionBorderColor),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final logBookService = context.watch<LogBookService>();
    final pilotService = context.watch<PilotService>();
    final currentPilot = pilotService.currentPilot;
    
    final statistics = logBookService.calculateStatistics(
      pilotId: currentPilot?.id,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentPilot != null) ...[
            _buildCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Pilot',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentPilot.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Flight Hours Summary
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flight Hours',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoRow(
                    label: 'Total Hours',
                    value: logBookService.formatDuration(statistics.totalDuration),
                  ),
                  Divider(color: AppColors.sectionBorderColor),
                  InfoRow(
                    label: 'Single Engine',
                    value: logBookService.formatDuration(statistics.singleEngineDuration),
                  ),
                  InfoRow(
                    label: 'Multi Engine',
                    value: logBookService.formatDuration(statistics.multiEngineDuration),
                  ),
                  Divider(color: AppColors.sectionBorderColor),
                  InfoRow(
                    label: 'As PIC',
                    value: logBookService.formatDuration(statistics.picDuration),
                  ),
                  InfoRow(
                    label: 'As SIC',
                    value: logBookService.formatDuration(statistics.sicDuration),
                  ),
                  InfoRow(
                    label: 'Solo',
                    value: logBookService.formatDuration(statistics.soloDuration),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Flight Conditions
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flight Conditions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InfoRow(
                    label: 'VFR',
                    value: logBookService.formatDuration(statistics.vfrDuration),
                  ),
                  InfoRow(
                    label: 'IFR',
                    value: logBookService.formatDuration(statistics.ifrDuration),
                  ),
                  Divider(color: AppColors.sectionBorderColor),
                  InfoRow(
                    label: 'Day',
                    value: logBookService.formatDuration(statistics.dayDuration),
                  ),
                  InfoRow(
                    label: 'Night',
                    value: logBookService.formatDuration(statistics.nightDuration),
                  ),
                  Divider(color: AppColors.sectionBorderColor),
                  InfoRow(
                    label: 'Simulator VFR',
                    value: logBookService.formatDuration(statistics.simulatorVfrDuration),
                  ),
                  InfoRow(
                    label: 'Simulator IFR',
                    value: logBookService.formatDuration(statistics.simulatorIfrDuration),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Takeoffs and Landings
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Takeoffs & Landings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Takeoffs',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InfoRow(
                              label: 'Total',
                              value: statistics.totalTakeoffs.toString(),
                            ),
                            InfoRow(
                              label: 'Day',
                              value: statistics.dayTakeoffs.toString(),
                            ),
                            InfoRow(
                              label: 'Night',
                              value: statistics.nightTakeoffs.toString(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Landings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InfoRow(
                              label: 'Total',
                              value: statistics.totalLandings.toString(),
                            ),
                            InfoRow(
                              label: 'Day',
                              value: statistics.dayLandings.toString(),
                            ),
                            InfoRow(
                              label: 'Night',
                              value: statistics.nightLandings.toString(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // By Aircraft
          if (statistics.durationByAircraft.isNotEmpty) ...[
            _buildCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'By Aircraft Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...statistics.durationByAircraft.entries.map((entry) {
                      final takeoffs = statistics.takeoffsByAircraft[entry.key] ?? 0;
                      final landings = statistics.landingsByAircraft[entry.key] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InfoRow(
                              label: 'Hours',
                              value: logBookService.formatDuration(entry.value),
                            ),
                            InfoRow(
                              label: 'Takeoffs/Landings',
                              value: '$takeoffs / $landings',
                            ),
                            Divider(color: AppColors.sectionBorderColor),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}