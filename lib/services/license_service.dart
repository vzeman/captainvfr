import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/license.dart';

class LicenseService extends ChangeNotifier {
  static const String _storageKey = 'pilot_licenses';
  List<License> _licenses = [];
  bool _isLoading = false;

  List<License> get licenses => List.unmodifiable(_licenses);
  bool get isLoading => _isLoading;

  // Get all expired licenses
  List<License> get expiredLicenses {
    return _licenses.where((license) => license.isExpired).toList();
  }

  // Get licenses expiring within 30 days
  List<License> get expiringLicenses {
    return _licenses.where((license) => license.willExpireWithinDays(30)).toList();
  }

  // Get licenses that need attention (expired or expiring soon)
  List<License> get licensesNeedingAttention {
    return _licenses.where((license) => 
      license.isExpired || license.willExpireWithinDays(30)
    ).toList();
  }

  // Initialize service and load licenses
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await loadLicenses();
    } catch (e) {
      debugPrint('Error initializing license service: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load licenses from storage
  Future<void> loadLicenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? licensesJson = prefs.getString(_storageKey);
      
      if (licensesJson != null) {
        final List<dynamic> decoded = json.decode(licensesJson);
        _licenses = decoded.map((json) => License.fromJson(json)).toList();
        
        // Sort by expiration date (soonest first)
        _licenses.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading licenses: $e');
      _licenses = [];
    }
  }

  // Save licenses to storage
  Future<void> _saveLicenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String licensesJson = json.encode(
        _licenses.map((license) => license.toJson()).toList(),
      );
      await prefs.setString(_storageKey, licensesJson);
    } catch (e) {
      debugPrint('Error saving licenses: $e');
      rethrow;
    }
  }

  // Add a new license
  Future<void> addLicense(License license) async {
    _licenses.add(license);
    _licenses.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
    await _saveLicenses();
    notifyListeners();
  }

  // Update an existing license
  Future<void> updateLicense(String id, License updatedLicense) async {
    final index = _licenses.indexWhere((license) => license.id == id);
    if (index != -1) {
      _licenses[index] = updatedLicense;
      _licenses.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      await _saveLicenses();
      notifyListeners();
    }
  }

  // Delete a license
  Future<void> deleteLicense(String id) async {
    _licenses.removeWhere((license) => license.id == id);
    await _saveLicenses();
    notifyListeners();
  }

  // Get license by ID
  License? getLicenseById(String id) {
    try {
      return _licenses.firstWhere((license) => license.id == id);
    } catch (e) {
      return null;
    }
  }

  // Clear all licenses (for testing or reset)
  Future<void> clearAllLicenses() async {
    _licenses.clear();
    await _saveLicenses();
    notifyListeners();
  }
}