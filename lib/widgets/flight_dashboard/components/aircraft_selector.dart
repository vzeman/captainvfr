import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/aircraft_settings_service.dart';
import '../../../services/flight_service.dart';
import '../../themed_dialog.dart';

/// Compact aircraft selector widget for the flight dashboard
class AircraftSelector extends StatelessWidget {
  final FlightService flightService;

  const AircraftSelector({
    super.key,
    required this.flightService,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AircraftSettingsService>(
      builder: (context, aircraftService, child) {
        // Hide aircraft selector if no aircraft are defined
        if (aircraftService.aircrafts.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedAircraft = aircraftService.selectedAircraft;

        return InkWell(
          onTap: () => _showAircraftSelectionDialog(
            context,
            aircraftService,
            flightService,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight, color: Colors.blueAccent, size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    selectedAircraft?.name ?? 'Select',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.blueAccent,
                  size: 14,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAircraftSelectionDialog(
    BuildContext context,
    AircraftSettingsService aircraftService,
    FlightService flightService,
  ) {
    ThemedDialog.show(
      context: context,
      title: 'Select Aircraft',
      content: SizedBox(
        width: double.maxFinite,
        child: aircraftService.aircrafts.isEmpty
            ? const Text(
                'No aircraft available. Please add an aircraft first.',
                style: TextStyle(color: Colors.white70),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: aircraftService.aircrafts.length,
                itemBuilder: (context, index) {
                  final aircraft = aircraftService.aircrafts[index];
                  final isSelected =
                      aircraft.id == aircraftService.selectedAircraft?.id;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0x1A448AFF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0x7F448AFF)
                            : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.flight,
                        color: isSelected
                            ? const Color(0xFF448AFF)
                            : Colors.white54,
                      ),
                      title: Text(
                        aircraft.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${aircraft.manufacturer} ${aircraft.model}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF448AFF),
                            )
                          : null,
                      onTap: () {
                        // Select the aircraft by ID
                        aircraftService.aircraftService.selectAircraft(
                          aircraft.id,
                        );
                        // Set aircraft in flight service
                        flightService.setAircraft(aircraft);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}