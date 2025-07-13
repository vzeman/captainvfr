import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checklist.dart';
import '../services/aircraft_settings_service.dart';
import '../utils/form_theme_helper.dart';

/// Dialog to run through a checklist.
class ChecklistRunDialog extends StatefulWidget {
  final Checklist checklist;

  /// Optional display name of the aircraft running this checklist.
  final String? aircraftName;
  const ChecklistRunDialog({
    super.key,
    required this.checklist,
    this.aircraftName,
  });

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
    _itemKeys = List.generate(
      widget.checklist.items.length,
      (_) => GlobalKey(),
    );
    // Scroll to first incomplete item on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final next = widget.checklist.items.indexWhere(
        (it) => !_completed.contains(it.id),
      );
      if (next != -1) {
        final ctx = _itemKeys[next].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.checklist.items.length;
    final done = _completed.length;
    final String subtitle = widget.aircraftName ?? (() {
      final aircraftService = context.watch<AircraftSettingsService>();
      final mfrList = aircraftService.manufacturers
          .where((m) => m.id == widget.checklist.manufacturerId)
          .toList();
      final mdlList = aircraftService.models
          .where((md) => md.id == widget.checklist.modelId)
          .toList();
      final mfrName = mfrList.isNotEmpty ? mfrList.first.name : '';
      final mdlName = mdlList.isNotEmpty ? mdlList.first.name : '';
      return '$mfrName $mdlName';
    })();

    return FormThemeHelper.buildDialog(
      context: context,
      title: widget.checklist.name,
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.7,
      content: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: TextStyle(
                    color: FormThemeHelper.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                if (widget.checklist.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.checklist.description!,
                    style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                  ),
                ],
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: total > 0 ? done / total : 0,
                  backgroundColor: FormThemeHelper.borderColor.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(FormThemeHelper.primaryAccent),
                ),
                const SizedBox(height: 8),
                Text(
                  '$done of $total items done',
                  style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                ),
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
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: completed 
                            ? FormThemeHelper.primaryAccent.withValues(alpha: 0.1)
                            : FormThemeHelper.sectionBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: completed 
                              ? FormThemeHelper.primaryAccent 
                              : FormThemeHelper.sectionBorderColor,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          completed
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: completed ? FormThemeHelper.primaryAccent : FormThemeHelper.secondaryTextColor,
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            color: FormThemeHelper.primaryTextColor,
                            decoration: completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.description != null) 
                              Text(
                                item.description!,
                                style: TextStyle(color: FormThemeHelper.secondaryTextColor),
                              ),
                            if (item.targetValue != null)
                              Text(
                                'Target: ${item.targetValue!}',
                                style: TextStyle(
                                  color: FormThemeHelper.primaryAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                          final next = widget.checklist.items.indexWhere(
                            (it) => !_completed.contains(it.id),
                          );
                          if (next != -1) {
                            final ctx = _itemKeys[next].currentContext;
                            if (ctx != null) {
                              Scrollable.ensureVisible(
                                ctx,
                                duration: const Duration(milliseconds: 300),
                              );
                            }
                          }
                        });
                        },
                      ),
                    ),
                  );
                },
            ),
          ),
        ],
      ),
    );
  }
}
