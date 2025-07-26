import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/logbook_entry.dart';
import '../../models/model.dart' show AircraftCategory;
import '../../models/flight_plan.dart' show FlightRules;
import '../../services/logbook_service.dart';
import '../../services/pilot_service.dart';
import '../../services/aircraft_settings_service.dart';

class LogBookEntryForm extends StatefulWidget {
  final LogBookEntry? entry;

  const LogBookEntryForm({super.key, this.entry});

  @override
  State<LogBookEntryForm> createState() => _LogBookEntryFormState();
}

class _LogBookEntryFormState extends State<LogBookEntryForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _departureController;
  late TextEditingController _arrivalController;
  late TextEditingController _aircraftTypeController;
  late TextEditingController _aircraftIdController;
  late TextEditingController _dayTakeoffsController;
  late TextEditingController _nightTakeoffsController;
  late TextEditingController _dayLandingsController;
  late TextEditingController _nightLandingsController;
  late TextEditingController _flightTrainingController;
  late TextEditingController _groundTrainingController;
  late TextEditingController _simulatorController;
  late TextEditingController _noteController;

  // Date/Time values
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  DateTime? _startMovingDate;
  TimeOfDay? _startMovingTime;
  DateTime? _endMovingDate;
  TimeOfDay? _endMovingTime;

  // Selection values
  String? _selectedPicId;
  String? _selectedSicId;
  String? _selectedAircraftId;
  EngineType? _engineType;
  FlightCondition? _flightCondition;
  FlightRules? _flightRules;
  bool _simulated = false;
  bool _flightReview = false;
  bool _ipc = false;
  bool _checkRide = false;
  bool _faa6158 = false;
  bool _nvgProficiency = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    
    // Initialize controllers
    _departureController = TextEditingController(text: entry?.departureAirport ?? '');
    _arrivalController = TextEditingController(text: entry?.arrivalAirport ?? '');
    _aircraftTypeController = TextEditingController(text: entry?.aircraftType ?? '');
    _aircraftIdController = TextEditingController(text: entry?.aircraftIdentification ?? '');
    _dayTakeoffsController = TextEditingController(text: (entry?.dayTakeoffs ?? 0).toString());
    _nightTakeoffsController = TextEditingController(text: (entry?.nightTakeoffs ?? 0).toString());
    _dayLandingsController = TextEditingController(text: (entry?.dayLandings ?? 0).toString());
    _nightLandingsController = TextEditingController(text: (entry?.nightLandings ?? 0).toString());
    _flightTrainingController = TextEditingController(text: entry?.flightTrainingNote ?? '');
    _groundTrainingController = TextEditingController(text: entry?.groundTrainingNote ?? '');
    _simulatorController = TextEditingController(text: entry?.simulatorNote ?? '');
    _noteController = TextEditingController(text: entry?.note ?? '');

    // Initialize date/time values
    _startDate = entry?.dateTimeStarted ?? DateTime.now();
    _startTime = TimeOfDay.fromDateTime(entry?.dateTimeStarted ?? DateTime.now());
    _endDate = entry?.dateTimeFinished ?? DateTime.now();
    _endTime = TimeOfDay.fromDateTime(entry?.dateTimeFinished ?? DateTime.now());
    
    if (entry?.dateTimeStartedMoving != null) {
      _startMovingDate = entry!.dateTimeStartedMoving!;
      _startMovingTime = TimeOfDay.fromDateTime(entry.dateTimeStartedMoving!);
    }
    
    if (entry?.dateTimeFinishedMoving != null) {
      _endMovingDate = entry!.dateTimeFinishedMoving!;
      _endMovingTime = TimeOfDay.fromDateTime(entry.dateTimeFinishedMoving!);
    }

    // Initialize selection values
    _selectedPicId = entry?.pilotInCommandId ?? context.read<PilotService>().currentPilot?.id;
    _selectedSicId = entry?.secondInCommandId;
    _engineType = entry?.engineType;
    _flightCondition = entry?.flightCondition;
    _flightRules = entry?.flightRules ?? FlightRules.vfr;
    _simulated = entry?.simulated ?? false;
    _flightReview = entry?.flightReview ?? false;
    _ipc = entry?.ipc ?? false;
    _checkRide = entry?.checkRide ?? false;
    _faa6158 = entry?.faa6158 ?? false;
    _nvgProficiency = entry?.nvgProficiency ?? false;
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    _aircraftTypeController.dispose();
    _aircraftIdController.dispose();
    _dayTakeoffsController.dispose();
    _nightTakeoffsController.dispose();
    _dayLandingsController.dispose();
    _nightLandingsController.dispose();
    _flightTrainingController.dispose();
    _groundTrainingController.dispose();
    _simulatorController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      final logBookService = context.read<LogBookService>();

      // Calculate durations
      final startDateTime = _combineDateTime(_startDate, _startTime);
      final endDateTime = _combineDateTime(_endDate, _endTime);
      final trackingDuration = endDateTime.difference(startDateTime);

      Duration? movingDuration;
      if (_startMovingDate != null && _startMovingTime != null && 
          _endMovingDate != null && _endMovingTime != null) {
        final startMoving = _combineDateTime(_startMovingDate!, _startMovingTime!);
        final endMoving = _combineDateTime(_endMovingDate!, _endMovingTime!);
        movingDuration = endMoving.difference(startMoving);
      }

      final entry = LogBookEntry(
        id: widget.entry?.id,
        dateTimeStarted: startDateTime,
        dateTimeStartedMoving: _startMovingDate != null && _startMovingTime != null
            ? _combineDateTime(_startMovingDate!, _startMovingTime!)
            : null,
        departureAirport: _departureController.text.trim().isEmpty 
            ? null : _departureController.text.trim(),
        dateTimeFinished: endDateTime,
        dateTimeFinishedMoving: _endMovingDate != null && _endMovingTime != null
            ? _combineDateTime(_endMovingDate!, _endMovingTime!)
            : null,
        arrivalAirport: _arrivalController.text.trim().isEmpty 
            ? null : _arrivalController.text.trim(),
        engineType: _engineType,
        aircraftType: _aircraftTypeController.text.trim().isEmpty 
            ? null : _aircraftTypeController.text.trim(),
        aircraftIdentification: _aircraftIdController.text.trim().isEmpty 
            ? null : _aircraftIdController.text.trim(),
        pilotInCommandId: _selectedPicId,
        secondInCommandId: _selectedSicId,
        flightTrainingNote: _flightTrainingController.text.trim().isEmpty 
            ? null : _flightTrainingController.text.trim(),
        groundTrainingNote: _groundTrainingController.text.trim().isEmpty 
            ? null : _groundTrainingController.text.trim(),
        simulatorNote: _simulatorController.text.trim().isEmpty 
            ? null : _simulatorController.text.trim(),
        flightReview: _flightReview,
        ipc: _ipc,
        checkRide: _checkRide,
        faa6158: _faa6158,
        nvgProficiency: _nvgProficiency,
        flightCondition: _flightCondition,
        flightRules: _flightRules,
        simulated: _simulated,
        dayTakeoffs: int.tryParse(_dayTakeoffsController.text) ?? 0,
        nightTakeoffs: int.tryParse(_nightTakeoffsController.text) ?? 0,
        dayLandings: int.tryParse(_dayLandingsController.text) ?? 0,
        nightLandings: int.tryParse(_nightLandingsController.text) ?? 0,
        note: _noteController.text.trim().isEmpty 
            ? null : _noteController.text.trim(),
        trackingDuration: trackingDuration,
        movingDuration: movingDuration,
        createdAt: widget.entry?.createdAt,
      );

      if (widget.entry == null) {
        await logBookService.addEntry(entry);
      } else {
        await logBookService.updateEntry(entry);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;
    final pilotService = context.watch<PilotService>();
    final aircraftService = context.watch<AircraftSettingsService>();
    final pilots = pilotService.pilots;
    final aircraft = aircraftService.aircrafts;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit LogBook Entry' : 'New LogBook Entry'),
        actions: [
          TextButton(
            onPressed: _saveEntry,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section: Timing
              _buildSectionHeader('Timing'),
              _buildDateTimeRow(
                'Start',
                _startDate,
                _startTime,
                (date) => setState(() => _startDate = date),
                (time) => setState(() => _startTime = time),
                required: true,
              ),
              _buildDateTimeRow(
                'Start Moving',
                _startMovingDate,
                _startMovingTime,
                (date) => setState(() => _startMovingDate = date),
                (time) => setState(() => _startMovingTime = time),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departureController,
                decoration: const InputDecoration(
                  labelText: 'Departure Airport',
                  hintText: 'ICAO code or name',
                  prefixIcon: Icon(Icons.flight_takeoff),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              _buildDateTimeRow(
                'End',
                _endDate,
                _endTime,
                (date) => setState(() => _endDate = date),
                (time) => setState(() => _endTime = time),
                required: true,
              ),
              _buildDateTimeRow(
                'End Moving',
                _endMovingDate,
                _endMovingTime,
                (date) => setState(() => _endMovingDate = date),
                (time) => setState(() => _endMovingTime = time),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _arrivalController,
                decoration: const InputDecoration(
                  labelText: 'Arrival Airport',
                  hintText: 'ICAO code or name',
                  prefixIcon: Icon(Icons.flight_land),
                ),
                textCapitalization: TextCapitalization.characters,
              ),

              const SizedBox(height: 24),

              // Section: Aircraft
              _buildSectionHeader('Aircraft'),
              DropdownButtonFormField<String>(
                value: _selectedAircraftId,
                decoration: const InputDecoration(
                  labelText: 'Select Aircraft',
                  prefixIcon: Icon(Icons.airplanemode_active),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Manual Entry'),
                  ),
                  ...aircraft.map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.model ?? a.name} (${a.registration ?? a.name})'),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAircraftId = value;
                    if (value != null) {
                      final selectedAircraft = aircraft.firstWhere((a) => a.id == value);
                      _aircraftTypeController.text = selectedAircraft.model ?? '';
                      _aircraftIdController.text = selectedAircraft.registration ?? '';
                      // Set engine type based on aircraft category
                      _engineType = selectedAircraft.category == AircraftCategory.multiEngine
                          ? EngineType.multiEngine
                          : EngineType.singleEngine;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _aircraftTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Aircraft Type',
                        hintText: 'e.g., Cessna 172',
                      ),
                      enabled: _selectedAircraftId == null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _aircraftIdController,
                      decoration: const InputDecoration(
                        labelText: 'Aircraft ID',
                        hintText: 'e.g., N12345',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      enabled: _selectedAircraftId == null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EngineType>(
                value: _engineType,
                decoration: const InputDecoration(
                  labelText: 'Engine Type',
                  prefixIcon: Icon(Icons.settings),
                ),
                items: const [
                  DropdownMenuItem(
                    value: EngineType.singleEngine,
                    child: Text('Single Engine'),
                  ),
                  DropdownMenuItem(
                    value: EngineType.multiEngine,
                    child: Text('Multi Engine'),
                  ),
                ],
                onChanged: (value) => setState(() => _engineType = value),
              ),

              const SizedBox(height: 24),

              // Section: Pilot Experience
              _buildSectionHeader('Pilot Experience'),
              DropdownButtonFormField<String>(
                value: _selectedPicId,
                decoration: const InputDecoration(
                  labelText: 'Pilot in Command',
                  prefixIcon: Icon(Icons.person),
                ),
                items: pilots.map((pilot) => DropdownMenuItem(
                  value: pilot.id,
                  child: Text(pilot.name),
                )).toList(),
                onChanged: (value) => setState(() => _selectedPicId = value),
                validator: (value) {
                  if (value == null) {
                    return 'Please select pilot in command';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSicId,
                decoration: const InputDecoration(
                  labelText: 'Second in Command (Optional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Solo Flight'),
                  ),
                  ...pilots
                      .where((p) => p.id != _selectedPicId)
                      .map((pilot) => DropdownMenuItem(
                    value: pilot.id,
                    child: Text(pilot.name),
                  )),
                ],
                onChanged: (value) => setState(() => _selectedSicId = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _flightTrainingController,
                decoration: const InputDecoration(
                  labelText: 'Flight Training Note',
                  hintText: 'Training activities performed',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _groundTrainingController,
                decoration: const InputDecoration(
                  labelText: 'Ground Training Note',
                  hintText: 'Ground training received',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _simulatorController,
                decoration: const InputDecoration(
                  labelText: 'Simulator Note',
                  hintText: 'Simulator training details',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Flight Review'),
                    selected: _flightReview,
                    onSelected: (value) => setState(() => _flightReview = value),
                  ),
                  FilterChip(
                    label: const Text('IPC'),
                    selected: _ipc,
                    onSelected: (value) => setState(() => _ipc = value),
                  ),
                  FilterChip(
                    label: const Text('Check Ride'),
                    selected: _checkRide,
                    onSelected: (value) => setState(() => _checkRide = value),
                  ),
                  FilterChip(
                    label: const Text('FAA 61.58'),
                    selected: _faa6158,
                    onSelected: (value) => setState(() => _faa6158 = value),
                  ),
                  FilterChip(
                    label: const Text('NVG Proficiency'),
                    selected: _nvgProficiency,
                    onSelected: (value) => setState(() => _nvgProficiency = value),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section: Conditions of Flight
              _buildSectionHeader('Conditions of Flight'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FlightCondition>(
                      value: _flightCondition,
                      decoration: const InputDecoration(
                        labelText: 'Day/Night',
                        prefixIcon: Icon(Icons.brightness_4),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: FlightCondition.day,
                          child: Text('Day'),
                        ),
                        DropdownMenuItem(
                          value: FlightCondition.night,
                          child: Text('Night'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _flightCondition = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<FlightRules>(
                      value: _flightRules,
                      decoration: const InputDecoration(
                        labelText: 'VFR/IFR',
                        prefixIcon: Icon(Icons.visibility),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: FlightRules.vfr,
                          child: Text('VFR'),
                        ),
                        DropdownMenuItem(
                          value: FlightRules.ifr,
                          child: Text('IFR'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _flightRules = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Simulated Conditions'),
                value: _simulated,
                onChanged: (value) => setState(() => _simulated = value),
              ),

              const SizedBox(height: 24),

              // Section: Departures and Landings
              _buildSectionHeader('Departures and Landings'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dayTakeoffsController,
                      decoration: const InputDecoration(
                        labelText: 'Day Takeoffs',
                        prefixIcon: Icon(Icons.flight_takeoff),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _nightTakeoffsController,
                      decoration: const InputDecoration(
                        labelText: 'Night Takeoffs',
                        prefixIcon: Icon(Icons.nights_stay),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dayLandingsController,
                      decoration: const InputDecoration(
                        labelText: 'Day Landings',
                        prefixIcon: Icon(Icons.flight_land),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _nightLandingsController,
                      decoration: const InputDecoration(
                        labelText: 'Night Landings',
                        prefixIcon: Icon(Icons.nights_stay),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section: Notes
              _buildSectionHeader('Notes'),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Flight Notes',
                  hintText: 'Additional notes about the flight',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _buildDateTimeRow(
    String label,
    DateTime? date,
    TimeOfDay? time,
    Function(DateTime) onDateChanged,
    Function(TimeOfDay) onTimeChanged, {
    bool required = false,
  }) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final hasValue = date != null && time != null;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            required ? '$label *' : label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      onDateChanged(picked);
                      if (time == null) {
                        onTimeChanged(TimeOfDay.now());
                      }
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      date != null ? dateFormat.format(date) : 'Select date',
                      style: date == null
                          ? TextStyle(color: Theme.of(context).hintColor)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      onTimeChanged(picked);
                      if (date == null) {
                        onDateChanged(DateTime.now());
                      }
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      time != null ? time.format(context) : 'Select time',
                      style: time == null
                          ? TextStyle(color: Theme.of(context).hintColor)
                          : null,
                    ),
                  ),
                ),
              ),
              if (!required && hasValue)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    onDateChanged(DateTime.now());
                    onTimeChanged(TimeOfDay.now());
                    setState(() {
                      if (label.contains('Start Moving')) {
                        _startMovingDate = null;
                        _startMovingTime = null;
                      } else if (label.contains('End Moving')) {
                        _endMovingDate = null;
                        _endMovingTime = null;
                      }
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}