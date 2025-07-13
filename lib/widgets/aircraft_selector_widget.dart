import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/aircraft.dart';
import '../services/aircraft_settings_service.dart';

class AircraftSelectorWidget extends StatefulWidget {
  final Function(Aircraft?) onAircraftSelected;
  final Aircraft? selectedAircraft;

  const AircraftSelectorWidget({
    super.key,
    required this.onAircraftSelected,
    this.selectedAircraft,
  });

  @override
  State<AircraftSelectorWidget> createState() => _AircraftSelectorWidgetState();
}

class _AircraftSelectorWidgetState extends State<AircraftSelectorWidget> {
  Aircraft? _selectedAircraft;

  @override
  void initState() {
    super.initState();
    _selectedAircraft = widget.selectedAircraft;
  }

  @override
  Widget build(BuildContext context) {
    final aircraftService = context.watch<AircraftSettingsService>();
    final aircrafts = aircraftService.aircrafts;

    if (aircrafts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.flight, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'No aircraft configured',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                'Add aircraft in the settings',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Aircraft',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedAircraft?.id,
              decoration: const InputDecoration(
                labelText: 'Aircraft',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flight),
              ),
              isExpanded: true,
              items: aircrafts.map((aircraft) {
                return DropdownMenuItem(
                  value: aircraft.id,
                  child: Text(
                    '${aircraft.name} ${aircraft.registration != null ? "(${aircraft.registration})" : ""}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (aircraftId) {
                final aircraft = aircraftId != null
                    ? aircrafts.firstWhere((a) => a.id == aircraftId)
                    : null;
                setState(() {
                  _selectedAircraft = aircraft;
                });
                widget.onAircraftSelected(aircraft);
              },
            ),
            if (_selectedAircraft != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedAircraft!.manufacturer ?? ""} ${_selectedAircraft!.model ?? ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    if (_selectedAircraft!.cruiseSpeed > 0)
                      Text(
                        'Cruise Speed: ${_selectedAircraft!.cruiseSpeed} kts',
                      ),
                    if (_selectedAircraft!.fuelConsumption > 0)
                      Text(
                        'Fuel Burn: ${_selectedAircraft!.fuelConsumption.toStringAsFixed(1)} gal/hr',
                      ),
                    if (_selectedAircraft!.maxTakeoffWeight > 0)
                      Text('MTOW: ${_selectedAircraft!.maxTakeoffWeight} lbs'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
