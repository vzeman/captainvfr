import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/aircraft.dart';
import '../services/media_service.dart';
import '../services/aircraft_settings_service.dart';

class AircraftDocumentsWidget extends StatefulWidget {
  final Aircraft aircraft;
  
  const AircraftDocumentsWidget({
    super.key,
    required this.aircraft,
  });

  @override
  State<AircraftDocumentsWidget> createState() => _AircraftDocumentsWidgetState();
}

class _AircraftDocumentsWidgetState extends State<AircraftDocumentsWidget> {
  final MediaService _mediaService = MediaService();
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    final documents = widget.aircraft.documentsPaths ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Documents',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _isLoading ? null : _addDocument,
                tooltip: 'Add document',
              ),
            ],
          ),
        ),
        
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          ),
        
        if (documents.isEmpty && !_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No documents yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add images of AFM, POH, or other aircraft documents',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        if (documents.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final docPath = documents[index];
              final file = _mediaService.getFile(docPath);
              
              return _buildDocumentTile(file, docPath);
            },
          ),
      ],
    );
  }
  
  Widget _buildDocumentTile(File? file, String docPath) {
    final fileName = _mediaService.getFileName(docPath);
    final isImage = _mediaService.isImage(docPath);
    final extension = _mediaService.getFileExtension(docPath);
    final exists = file != null;
    
    IconData icon;
    Color iconColor;
    
    if (!exists) {
      icon = Icons.broken_image;
      iconColor = Colors.red;
    } else if (isImage) {
      icon = Icons.image;
      iconColor = Colors.blue;
    } else {
      switch (extension) {
        case '.pdf':
          icon = Icons.picture_as_pdf;
          iconColor = Colors.red;
          break;
        case '.doc':
        case '.docx':
          icon = Icons.description;
          iconColor = Colors.blue.shade700;
          break;
        case '.txt':
          icon = Icons.text_snippet;
          iconColor = Colors.grey;
          break;
        default:
          icon = Icons.insert_drive_file;
          iconColor = Colors.grey;
      }
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          size: 40,
          color: iconColor,
        ),
        title: Text(
          fileName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: exists
            ? Text(
                'Tap to open',
                style: TextStyle(color: Colors.grey.shade600),
              )
            : const Text(
                'File not found',
                style: TextStyle(color: Colors.red),
              ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _deleteDocument(docPath),
          tooltip: 'Delete',
        ),
        onTap: exists ? () => _openDocument(file) : null,
      ),
    );
  }
  
  Future<void> _addDocument() async {
    // Show dialog to let user choose between camera or gallery for image documents
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Document Image'),
        content: const Text(
          'You can add images of your aircraft documents (AFM, POH, etc.).\n\n'
          'Note: PDF and DOC files are not supported at this time.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Take Photo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Choose from Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    setState(() => _isLoading = true);
    
    try {
      String? documentPath;
      if (source == ImageSource.camera) {
        documentPath = await _mediaService.takePhoto();
      } else {
        documentPath = await _mediaService.pickImageFromGallery();
      }
      
      if (documentPath != null) {
        await _addDocumentToAircraft(documentPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _addDocumentToAircraft(String documentPath) async {
    final aircraftService = context.read<AircraftSettingsService>();
    final updatedDocuments = List<String>.from(widget.aircraft.documentsPaths ?? []);
    updatedDocuments.add(documentPath);
    
    final updatedAircraft = widget.aircraft.copyWith(
      documentsPaths: updatedDocuments,
      updatedAt: DateTime.now(),
    );
    
    await aircraftService.updateAircraft(updatedAircraft);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document added successfully')),
      );
    }
  }
  
  Future<void> _deleteDocument(String documentPath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text(
          'Are you sure you want to delete "${_mediaService.getFileName(documentPath)}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      try {
        // Delete from storage
        await _mediaService.deleteDocument(documentPath);
        
        // Update aircraft
        if (!mounted) return;
        final aircraftService = context.read<AircraftSettingsService>();
        final updatedDocuments = List<String>.from(widget.aircraft.documentsPaths ?? []);
        updatedDocuments.remove(documentPath);
        
        final updatedAircraft = widget.aircraft.copyWith(
          documentsPaths: updatedDocuments,
          updatedAt: DateTime.now(),
        );
        
        await aircraftService.updateAircraft(updatedAircraft);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting document: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
  
  Future<void> _openDocument(File file) async {
    try {
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not open document';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}