import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';

class MediaService {
  static const String photosDirectory = 'aircraft_photos';
  static const String documentsDirectory = 'aircraft_documents';
  
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();
  
  // Get app's documents directory
  Future<Directory> _getAppDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory;
  }
  
  // Get photos directory
  Future<Directory> _getPhotosDirectory() async {
    final appDir = await _getAppDirectory();
    final photosDir = Directory(path.join(appDir.path, photosDirectory));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }
  
  // Get documents directory
  Future<Directory> _getDocumentsDirectory() async {
    final appDir = await _getAppDirectory();
    final docsDir = Directory(path.join(appDir.path, documentsDirectory));
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    return docsDir;
  }
  
  // Request permissions
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    return true;
  }
  
  // Pick image from gallery
  Future<String?> pickImageFromGallery() async {
    if (!await _requestPermission()) {
      throw Exception('Permission denied');
    }
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _saveImageToStorage(image);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      rethrow;
    }
  }
  
  // Take photo with camera
  Future<String?> takePhoto() async {
    if (!await _requestPermission()) {
      throw Exception('Permission denied');
    }
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _saveImageToStorage(image);
      }
      return null;
    } catch (e) {
      debugPrint('Error taking photo: $e');
      rethrow;
    }
  }
  
  // Save image to app storage
  Future<String> _saveImageToStorage(XFile image) async {
    try {
      final photosDir = await _getPhotosDirectory();
      final fileName = '${_uuid.v4()}${path.extension(image.path)}';
      final filePath = path.join(photosDir.path, fileName);
      
      await image.saveTo(filePath);
      return filePath;
    } catch (e) {
      debugPrint('Error saving image: $e');
      rethrow;
    }
  }
  
  // Delete photo
  Future<void> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      rethrow;
    }
  }
  
  // Delete multiple photos
  Future<void> deletePhotos(List<String> photoPaths) async {
    for (final photoPath in photoPaths) {
      await deletePhoto(photoPath);
    }
  }
  
  // Get file from path
  File? getFile(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting file: $e');
      return null;
    }
  }
  
  // Pick document file
  Future<String?> pickDocument() async {
    if (!await _requestPermission()) {
      throw Exception('Permission denied');
    }
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
      );
      
      if (result != null && result.files.single.path != null) {
        return await _saveDocumentToStorage(result.files.single);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking document: $e');
      rethrow;
    }
  }
  
  // Save document to app storage
  Future<String> _saveDocumentToStorage(PlatformFile file) async {
    try {
      final docsDir = await _getDocumentsDirectory();
      final fileName = '${_uuid.v4()}_${file.name}';
      final filePath = path.join(docsDir.path, fileName);
      
      if (file.path != null) {
        final sourceFile = File(file.path!);
        await sourceFile.copy(filePath);
        return filePath;
      } else {
        throw Exception('File path is null');
      }
    } catch (e) {
      debugPrint('Error saving document: $e');
      rethrow;
    }
  }
  
  // Delete document
  Future<void> deleteDocument(String documentPath) async {
    try {
      final file = File(documentPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }
  
  // Delete multiple documents
  Future<void> deleteDocuments(List<String> documentPaths) async {
    for (final docPath in documentPaths) {
      await deleteDocument(docPath);
    }
  }
  
  // Get file name from path
  String getFileName(String filePath) {
    return path.basename(filePath);
  }
  
  // Get file extension
  String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }
  
  // Check if file is an image
  bool isImage(String filePath) {
    final ext = getFileExtension(filePath);
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(ext);
  }
  
  // Check if file is a document
  bool isDocument(String filePath) {
    final ext = getFileExtension(filePath);
    return ['.pdf', '.doc', '.docx', '.txt'].contains(ext);
  }
  
  // Clean up orphaned files (files not referenced by any aircraft)
  Future<void> cleanupOrphanedFiles(List<String> referencedPaths) async {
    try {
      final photosDir = await _getPhotosDirectory();
      final docsDir = await _getDocumentsDirectory();
      
      // Clean photos directory
      await _cleanupDirectory(photosDir, referencedPaths);
      
      // Clean documents directory
      await _cleanupDirectory(docsDir, referencedPaths);
    } catch (e) {
      debugPrint('Error cleaning up orphaned files: $e');
    }
  }
  
  Future<void> _cleanupDirectory(Directory dir, List<String> referencedPaths) async {
    if (!await dir.exists()) return;
    
    final files = dir.listSync();
    for (final file in files) {
      if (file is File && !referencedPaths.contains(file.path)) {
        try {
          await file.delete();
          debugPrint('Deleted orphaned file: ${file.path}');
        } catch (e) {
          debugPrint('Error deleting orphaned file: $e');
        }
      }
    }
  }
}