import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/aircraft.dart';
import '../services/checklist_service.dart';
import '../widgets/checklist_run_dialog.dart';

/// Detail screen for a specific aircraft, providing tabs for checklists and flight history.
class AircraftDetailScreen extends StatelessWidget {
  /// The aircraft to display details for.
  final Aircraft aircraft;

  const AircraftDetailScreen({super.key, required this.aircraft});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(aircraft.name),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'Checklists'),
              Tab(icon: Icon(Icons.flight), text: 'Flights'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Consumer<ChecklistService>(
              builder: (context, service, _) {
                final items = service.checklists.where((c) {
                  return c.manufacturerId == aircraft.manufacturerId &&
                         c.modelId == aircraft.modelId;
                }).toList();
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No checklists available for this aircraft'),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final checklist = items[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(checklist.name),
                        subtitle: checklist.description != null ? Text(checklist.description!) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ChecklistRunDialog(
                                checklist: checklist,
                                aircraftName: aircraft.name,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const Center(child: Text('Flight history coming soon')),
          ],
        ),
      ),
    );
  }
}
