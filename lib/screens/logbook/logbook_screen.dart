import 'package:flutter/material.dart';
import 'logbook_summary_tab.dart';
import 'logbook_entries_tab.dart';
import 'pilots_tab.dart';
import '../../constants/app_colors.dart';

class LogBookScreen extends StatefulWidget {
  final int initialTab;
  
  const LogBookScreen({super.key, this.initialTab = 0});

  @override
  State<LogBookScreen> createState() => _LogBookScreenState();
}

class _LogBookScreenState extends State<LogBookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, 
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'LogBook',
          style: TextStyle(color: AppColors.primaryTextColor),
        ),
        backgroundColor: AppColors.dialogBackgroundColor,
        foregroundColor: AppColors.primaryTextColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryAccent,
          labelColor: AppColors.primaryTextColor,
          unselectedLabelColor: AppColors.secondaryTextColor,
          tabs: const [
            Tab(text: 'Summary', icon: Icon(Icons.dashboard)),
            Tab(text: 'Logs', icon: Icon(Icons.list_alt)),
            Tab(text: 'Pilots', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          LogBookSummaryTab(),
          LogBookEntriesTab(),
          PilotsTab(),
        ],
      ),
    );
  }
}