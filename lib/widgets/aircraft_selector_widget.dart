import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/aircraft.dart';
import '../services/aircraft_settings_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';

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
      return Container(
        decoration: BoxDecoration(
          color: AppColors.sectionBackgroundColor,
          borderRadius: AppTheme.extraLargeRadius,
          border: Border.all(color: AppColors.sectionBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.flight, size: 48, color: AppColors.primaryAccent),
              const SizedBox(height: 8),
              Text(
                'No aircraft configured',
                style: TextStyle(fontSize: 16, color: AppColors.primaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Add aircraft in the settings',
                style: TextStyle(fontSize: 14, color: AppColors.secondaryTextColor),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedAircraft?.id,
          decoration: InputDecoration(
            labelText: 'Select Aircraft',
            labelStyle: TextStyle(color: AppColors.secondaryTextColor),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryAccent),
              borderRadius: BorderRadius.circular(8),
            ),
            fillColor: AppColors.fillColorFaint,
            filled: true,
          ),
          style: TextStyle(color: AppColors.primaryTextColor),
          dropdownColor: AppColors.dialogBackgroundColor,
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
              color: AppColors.fillColorFaint,
              borderRadius: AppTheme.defaultRadius,
              border: Border.all(color: AppColors.primaryAccent),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedAircraft!.manufacturer ?? ""} ${_selectedAircraft!.model ?? ""}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                if (_selectedAircraft!.cruiseSpeed > 0)
                  Text(
                    'Cruise Speed: ${_selectedAircraft!.cruiseSpeed} kts',
                    style: TextStyle(color: AppColors.secondaryTextColor),
                  ),
                if (_selectedAircraft!.fuelConsumption > 0)
                  Text(
                    'Fuel Burn: ${_selectedAircraft!.fuelConsumption.toStringAsFixed(1)} gal/hr',
                    style: TextStyle(color: AppColors.secondaryTextColor),
                  ),
                if (_selectedAircraft!.maxTakeoffWeight > 0)
                  Text(
                    'MTOW: ${_selectedAircraft!.maxTakeoffWeight} lbs',
                    style: TextStyle(color: AppColors.secondaryTextColor),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
