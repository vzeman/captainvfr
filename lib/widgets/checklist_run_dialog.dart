import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checklist.dart';
import '../services/aircraft_settings_service.dart';

/// Dialog to run through a checklist.
class ChecklistRunDialog extends StatefulWidget {
  final Checklist checklist;
  /// Optional display name of the aircraft running this checklist.
  final String? aircraftName;
  const ChecklistRunDialog({Key? key, required this.checklist, this.aircraftName}) : super(key: key);

  @override
  State<ChecklistRunDialog> createState() => _ChecklistRunDialogState();
}

class _ChecklistRunDialogState extends State<ChecklistRunDialog> {
  final Set<String> _completed = {};
  final ScrollController _scrollController = ScrollController();
  late final List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.checklist.items.length, (_) => GlobalKey());
    // Scroll to first incomplete item on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final next = widget.checklist.items.indexWhere((it) => !_completed.contains(it.id));
      if (next != -1) {
        final ctx = _itemKeys[next].currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.checklist.items.length;
    final done = _completed.length;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.checklist.name),
                if (widget.aircraftName != null) ...[
                    const SizedBox(height: 4),
                    Text(widget.aircraftName!, style: Theme.of(context).textTheme.bodySmall),
                  ] else ...[
                    const SizedBox(height: 4),
                    Consumer<AircraftSettingsService>(
                      builder: (context, svc, _) {
                        final mfrList = svc.manufacturers.where((m) => m.id == widget.checklist.manufacturerId).toList();
                        final mdlList = svc.models.where((md) => md.id == widget.checklist.modelId).toList();
                        final mfrName = mfrList.isNotEmpty ? mfrList.first.name : '';
                        final mdlName = mdlList.isNotEmpty ? mdlList.first.name : '';
                        return Text(
                          '$mfrName $mdlName',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                    ),
                  ],
                ],
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.checklist.description != null)
                    Text(widget.checklist.description!),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: total > 0 ? done / total : 0),
                  Text('$done of $total items done'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: total,
                itemBuilder: (context, index) {
                  final item = widget.checklist.items[index];
                  final completed = _completed.contains(item.id);
                  return KeyedSubtree(
                    key: _itemKeys[index],
                    child: ListTile(
                      leading: Icon(
                        completed ? Icons.check_box : Icons.check_box_outline_blank,
                        color: completed ? Colors.green : null,
                      ),
                      title: Text(item.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.description != null) Text(item.description!),
                          if (item.targetValue != null) Text('Target: ${item.targetValue!}'),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          if (completed) {
                            _completed.remove(item.id);
                          } else {
                            _completed.add(item.id);
                          }
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final next = widget.checklist.items.indexWhere((it) => !_completed.contains(it.id));
                          if (next != -1) {
                            final ctx = _itemKeys[next].currentContext;
                            if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
