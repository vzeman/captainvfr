import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/checklist.dart';

/// Service to manage checklists using Hive for persistence.
class ChecklistService extends ChangeNotifier {
  static const _boxName = 'checklists';
  late Box<Checklist> _box;

  /// All stored checklists.
  List<Checklist> get checklists => _box.values.toList();

  /// Initialize Hive box for checklists.
  Future<void> initialize() async {
    _box = await Hive.openBox<Checklist>(_boxName);
  }

  /// Add or update a checklist.
  Future<void> saveChecklist(Checklist checklist) async {
    await _box.put(checklist.id, checklist);
    notifyListeners();
  }

  /// Delete checklist by id.
  Future<void> deleteChecklist(String id) async {
    await _box.delete(id);
    notifyListeners();
  }
  
  /// Get checklists for a specific model
  List<Checklist> getChecklistsForModel(String modelId) {
    return checklists.where((c) => c.modelId == modelId).toList();
  }
  
  /// Get checklists for a specific aircraft (by model ID)
  List<Checklist> getChecklistsForAircraft(String aircraftModelId) {
    return getChecklistsForModel(aircraftModelId);
  }
  
  /// Export checklists to JSON file
  Future<void> exportChecklists(List<Checklist> checklistsToExport) async {
    try {
      // Create JSON data
      final jsonData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'checklists': checklistsToExport.map((c) => c.toJson()).toList(),
      };
      
      // Convert to JSON string
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'checklists_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${tempDir.path}/$fileName');
      
      // Write to file
      await file.writeAsString(jsonString);
      
      // Share the file
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'CaptainVFR Checklists Export',
        text: 'Exported ${checklistsToExport.length} checklist(s)',
      );
      
      // Clean up temp file after sharing
      await file.delete();
    } catch (e) {
      debugPrint('Error exporting checklists: $e');
      rethrow;
    }
  }
  
  /// Import checklists from JSON file
  Future<ImportResult> importChecklists() async {
    try {
      // Pick JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result == null || result.files.single.path == null) {
        return ImportResult(imported: 0, skipped: 0, errors: []);
      }
      
      // Read file
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      // Validate format
      if (!jsonData.containsKey('checklists') || jsonData['checklists'] is! List) {
        throw Exception('Invalid checklist export format');
      }
      
      int imported = 0;
      int skipped = 0;
      List<String> errors = [];
      final uuid = const Uuid();
      
      // Import each checklist
      for (final checklistJson in jsonData['checklists']) {
        try {
          final checklist = Checklist.fromJson(checklistJson);
          
          // Check if checklist with same name already exists
          final existingChecklist = checklists.firstWhere(
            (c) => c.name == checklist.name && 
                   c.manufacturerId == checklist.manufacturerId &&
                   c.modelId == checklist.modelId,
            orElse: () => Checklist(
              id: '',
              name: '',
              manufacturerId: '',
              modelId: '',
            ),
          );
          
          if (existingChecklist.id.isNotEmpty) {
            skipped++;
            continue;
          }
          
          // Generate new ID to avoid conflicts
          checklist.id = uuid.v4();
          
          // Save checklist
          await saveChecklist(checklist);
          imported++;
        } catch (e) {
          errors.add('Failed to import checklist: ${checklistJson['name'] ?? 'Unknown'}');
          debugPrint('Error importing checklist: $e');
        }
      }
      
      return ImportResult(
        imported: imported,
        skipped: skipped,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error importing checklists: $e');
      rethrow;
    }
  }
  
  /// Export a single checklist
  Future<void> exportChecklist(Checklist checklist) async {
    await exportChecklists([checklist]);
  }
}

/// Result of import operation
class ImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;
  
  ImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });
  
  bool get hasErrors => errors.isNotEmpty;
  int get total => imported + skipped + errors.length;
}
