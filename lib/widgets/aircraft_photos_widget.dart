import 'dart:io';
import 'package:flutter/material.dart';
import '../models/aircraft.dart';
import '../services/media_service.dart';
import '../services/aircraft_settings_service.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AircraftPhotosWidget extends StatefulWidget {
  final Aircraft aircraft;

  const AircraftPhotosWidget({super.key, required this.aircraft});

  @override
  State<AircraftPhotosWidget> createState() => _AircraftPhotosWidgetState();
}

class _AircraftPhotosWidgetState extends State<AircraftPhotosWidget> {
  final MediaService _mediaService = MediaService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final photos = widget.aircraft.photosPaths ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Photos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_library),
                    onPressed: _isLoading ? null : _pickFromGallery,
                    tooltip: 'Add from gallery',
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _isLoading ? null : _takePhoto,
                    tooltip: 'Take photo',
                  ),
                ],
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

        if (photos.isEmpty && !_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No photos yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add photos from gallery or take new ones',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

        if (photos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photoPath = photos[index];
              final file = _mediaService.getFile(photoPath);

              if (file == null) {
                return _buildErrorPhoto(photoPath);
              }

              return _buildPhotoTile(file, photoPath, index);
            },
          ),
      ],
    );
  }

  Widget _buildPhotoTile(File file, String photoPath, int index) {
    return GestureDetector(
      onTap: () => _viewPhoto(file, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                onPressed: () => _deletePhoto(photoPath),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPhoto(String photoPath) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Icon(Icons.broken_image, color: Colors.grey),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                onPressed: () => _deletePhoto(photoPath),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isLoading = true);

    try {
      final photoPath = await _mediaService.pickImageFromGallery();
      if (photoPath != null) {
        await _addPhotoToAircraft(photoPath);
      }
    } catch (e) {
      if (mounted) {
        _handleError(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _takePhoto() async {
    setState(() => _isLoading = true);

    try {
      final photoPath = await _mediaService.takePhoto();
      if (photoPath != null) {
        await _addPhotoToAircraft(photoPath);
      }
    } catch (e) {
      if (mounted) {
        _handleError(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addPhotoToAircraft(String photoPath) async {
    final aircraftService = context.read<AircraftSettingsService>();
    final updatedPhotos = List<String>.from(widget.aircraft.photosPaths ?? []);
    updatedPhotos.add(photoPath);

    final updatedAircraft = widget.aircraft.copyWith(
      photosPaths: updatedPhotos,
      updatedAt: DateTime.now(),
    );

    await aircraftService.updateAircraft(updatedAircraft);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo added successfully')));
    }
  }

  Future<void> _deletePhoto(String photoPath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
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
        await _mediaService.deletePhoto(photoPath);

        // Update aircraft
        if (!mounted) return;
        final aircraftService = context.read<AircraftSettingsService>();
        final updatedPhotos = List<String>.from(
          widget.aircraft.photosPaths ?? [],
        );
        updatedPhotos.remove(photoPath);

        final updatedAircraft = widget.aircraft.copyWith(
          photosPaths: updatedPhotos,
          updatedAt: DateTime.now(),
        );

        await aircraftService.updateAircraft(updatedAircraft);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Photo deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting photo: $e'),
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

  void _viewPhoto(File file, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photos: widget.aircraft.photosPaths ?? [],
          initialIndex: index,
          mediaService: _mediaService,
        ),
      ),
    );
  }

  void _handleError(dynamic error) {
    String message;
    SnackBarAction? action;

    if (error is PermissionException) {
      message = error.message;
      if (error.isPermanentlyDenied) {
        action = SnackBarAction(
          label: 'SETTINGS',
          onPressed: () {
            openAppSettings();
          },
        );
      }
    } else {
      message = 'An error occurred: ${error.toString()}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: action,
      ),
    );
  }
}

class PhotoViewScreen extends StatelessWidget {
  final List<String> photos;
  final int initialIndex;
  final MediaService mediaService;

  const PhotoViewScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.mediaService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Photo ${initialIndex + 1} of ${photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final file = mediaService.getFile(photos[index]);

          if (file == null) {
            return const Center(
              child: Icon(Icons.broken_image, color: Colors.white, size: 64),
            );
          }

          return InteractiveViewer(
            child: Center(child: Image.file(file, fit: BoxFit.contain)),
          );
        },
      ),
    );
  }
}
