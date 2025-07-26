import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/pilot.dart';
import '../models/endorsement.dart';
import '../models/license.dart';
import 'license_service.dart';

class PilotService extends ChangeNotifier {
  static const String _pilotsBoxName = 'pilots';
  static const String _endorsementsBoxName = 'endorsements';
  static const String _currentPilotKey = 'current_pilot_id';
  
  Box<Pilot>? _pilotsBox;
  Box<Endorsement>? _endorsementsBox;
  Box? _settingsBox;
  final LicenseService _licenseService;
  
  List<Pilot> _pilots = [];
  List<Endorsement> _endorsements = [];
  String? _currentPilotId;

  PilotService({required LicenseService licenseService}) 
      : _licenseService = licenseService;

  List<Pilot> get pilots => List.unmodifiable(_pilots);
  List<Endorsement> get endorsements => List.unmodifiable(_endorsements);
  
  Pilot? get currentPilot {
    if (_currentPilotId == null) return null;
    try {
      return _pilots.firstWhere((p) => p.id == _currentPilotId);
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    try {
      _pilotsBox = await Hive.openBox<Pilot>(_pilotsBoxName);
      _endorsementsBox = await Hive.openBox<Endorsement>(_endorsementsBoxName);
      _settingsBox = await Hive.openBox('pilot_settings');
      
      _loadPilots();
      _loadEndorsements();
      _loadCurrentPilot();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing PilotService: $e');
      throw Exception('Failed to initialize pilot service');
    }
  }

  void _loadPilots() {
    if (_pilotsBox != null && _pilotsBox!.isOpen) {
      _pilots = _pilotsBox!.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
  }

  void _loadEndorsements() {
    if (_endorsementsBox != null && _endorsementsBox!.isOpen) {
      _endorsements = _endorsementsBox!.values.toList()
        ..sort((a, b) => a.validFrom.compareTo(b.validFrom));
    }
  }

  void _loadCurrentPilot() {
    _currentPilotId = _settingsBox?.get(_currentPilotKey);
  }

  Future<void> setCurrentPilot(String? pilotId) async {
    _currentPilotId = pilotId;
    if (pilotId != null) {
      await _settingsBox?.put(_currentPilotKey, pilotId);
    } else {
      await _settingsBox?.delete(_currentPilotKey);
    }
    notifyListeners();
  }

  // Pilot CRUD operations
  Future<Pilot> addPilot(Pilot pilot) async {
    if (_pilotsBox == null) throw Exception('Service not initialized');
    
    // If this is the first pilot or marked as current user, set as current
    if (_pilots.isEmpty || pilot.isCurrentUser) {
      await setCurrentPilot(pilot.id);
      
      // If marked as current user, unmark all others
      if (pilot.isCurrentUser) {
        for (var existingPilot in _pilots) {
          if (existingPilot.isCurrentUser && existingPilot.id != pilot.id) {
            await updatePilot(existingPilot.copyWith(isCurrentUser: false));
          }
        }
      }
    }
    
    await _pilotsBox!.put(pilot.id, pilot);
    _loadPilots();
    notifyListeners();
    return pilot;
  }

  Future<void> updatePilot(Pilot pilot) async {
    if (_pilotsBox == null) throw Exception('Service not initialized');
    
    // If marked as current user, unmark all others
    if (pilot.isCurrentUser) {
      for (var existingPilot in _pilots) {
        if (existingPilot.isCurrentUser && existingPilot.id != pilot.id) {
          await _pilotsBox!.put(
            existingPilot.id, 
            existingPilot.copyWith(isCurrentUser: false)
          );
        }
      }
      await setCurrentPilot(pilot.id);
    }
    
    await _pilotsBox!.put(pilot.id, pilot);
    _loadPilots();
    notifyListeners();
  }

  Future<void> deletePilot(String pilotId) async {
    if (_pilotsBox == null) throw Exception('Service not initialized');
    
    // Don't allow deleting the current pilot
    if (_currentPilotId == pilotId) {
      throw Exception('Cannot delete the current pilot');
    }
    
    // Delete associated licenses and endorsements
    final pilot = _pilotsBox!.get(pilotId);
    if (pilot != null) {
      // Delete licenses
      for (final licenseId in pilot.licenseIds) {
        await _licenseService.deleteLicense(licenseId);
      }
      
      // Delete endorsements
      for (final endorsementId in pilot.endorsementIds) {
        await deleteEndorsement(endorsementId);
      }
    }
    
    await _pilotsBox!.delete(pilotId);
    _loadPilots();
    notifyListeners();
  }

  Pilot? getPilotById(String id) {
    try {
      return _pilots.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // Endorsement CRUD operations
  Future<Endorsement> addEndorsement(Endorsement endorsement, String pilotId) async {
    if (_endorsementsBox == null || _pilotsBox == null) {
      throw Exception('Service not initialized');
    }
    
    await _endorsementsBox!.put(endorsement.id, endorsement);
    
    // Add endorsement to pilot
    final pilot = _pilotsBox!.get(pilotId);
    if (pilot != null) {
      final updatedEndorsementIds = List<String>.from(pilot.endorsementIds)
        ..add(endorsement.id);
      await updatePilot(pilot.copyWith(endorsementIds: updatedEndorsementIds));
    }
    
    _loadEndorsements();
    notifyListeners();
    return endorsement;
  }

  Future<void> updateEndorsement(Endorsement endorsement) async {
    if (_endorsementsBox == null) throw Exception('Service not initialized');
    
    await _endorsementsBox!.put(endorsement.id, endorsement);
    _loadEndorsements();
    notifyListeners();
  }

  Future<void> deleteEndorsement(String endorsementId) async {
    if (_endorsementsBox == null || _pilotsBox == null) {
      throw Exception('Service not initialized');
    }
    
    // Remove from all pilots
    for (final pilot in _pilots) {
      if (pilot.endorsementIds.contains(endorsementId)) {
        final updatedEndorsementIds = List<String>.from(pilot.endorsementIds)
          ..remove(endorsementId);
        await updatePilot(pilot.copyWith(endorsementIds: updatedEndorsementIds));
      }
    }
    
    await _endorsementsBox!.delete(endorsementId);
    _loadEndorsements();
    notifyListeners();
  }

  Endorsement? getEndorsementById(String id) {
    try {
      return _endorsements.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Endorsement> getEndorsementsForPilot(String pilotId) {
    final pilot = getPilotById(pilotId);
    if (pilot == null) return [];
    
    return pilot.endorsementIds
        .map((id) => getEndorsementById(id))
        .where((e) => e != null)
        .cast<Endorsement>()
        .toList();
  }

  List<License> getLicensesForPilot(String pilotId) {
    final pilot = getPilotById(pilotId);
    if (pilot == null) return [];
    
    return pilot.licenseIds
        .map((id) => _licenseService.getLicenseById(id))
        .where((l) => l != null)
        .cast<License>()
        .toList();
  }

  // Add license to pilot
  Future<void> addLicenseToPilot(String licenseId, String pilotId) async {
    final pilot = getPilotById(pilotId);
    if (pilot == null) throw Exception('Pilot not found');
    
    if (!pilot.licenseIds.contains(licenseId)) {
      final updatedLicenseIds = List<String>.from(pilot.licenseIds)
        ..add(licenseId);
      await updatePilot(pilot.copyWith(licenseIds: updatedLicenseIds));
    }
  }

  // Remove license from pilot
  Future<void> removeLicenseFromPilot(String licenseId, String pilotId) async {
    final pilot = getPilotById(pilotId);
    if (pilot == null) throw Exception('Pilot not found');
    
    if (pilot.licenseIds.contains(licenseId)) {
      final updatedLicenseIds = List<String>.from(pilot.licenseIds)
        ..remove(licenseId);
      await updatePilot(pilot.copyWith(licenseIds: updatedLicenseIds));
    }
  }

  // Check for expiring endorsements
  List<Endorsement> getExpiringEndorsements({int days = 30}) {
    return _endorsements
        .where((e) => e.willExpireWithinDays(days))
        .toList();
  }

  @override
  void dispose() {
    _pilotsBox?.close();
    _endorsementsBox?.close();
    super.dispose();
  }
}