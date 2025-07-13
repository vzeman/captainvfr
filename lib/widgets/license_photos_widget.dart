import 'dart:io';
import 'package:flutter/material.dart';
import '../models/license.dart';
import '../services/media_service.dart';
import '../services/license_service.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

class LicensePhotosWidget extends StatefulWidget {
  final License license;

  const LicensePhotosWidget({super.key, required this.license});

  @override
  State<LicensePhotosWidget> createState() => _LicensePhotosWidgetState();
}

class _LicensePhotosWidgetState extends State<LicensePhotosWidget> {
  final MediaService _mediaService = MediaService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final photos = widget.license.imagePaths ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'License Images',
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
                    'No images yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add photos of your license',
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
      final photoPath = await _mediaService.pickLicenseImageFromGallery();
      if (photoPath != null) {
        await _addPhotoToLicense(photoPath);
      }
    } on PermissionException catch (e) {
      if (mounted) {
        _showPermissionError(e);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
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

  Future<void> _takePhoto() async {
    setState(() => _isLoading = true);

    try {
      final photoPath = await _mediaService.takeLicensePhoto();
      if (photoPath != null) {
        await _addPhotoToLicense(photoPath);
      }
    } on PermissionException catch (e) {
      if (mounted) {
        _showPermissionError(e);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: ${e.toString()}'),
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

  Future<void> _addPhotoToLicense(String photoPath) async {
    final licenseService = context.read<LicenseService>();
    final updatedPhotos = List<String>.from(widget.license.imagePaths ?? []);
    updatedPhotos.add(photoPath);

    final updatedLicense = widget.license.copyWith(imagePaths: updatedPhotos);

    await licenseService.updateLicense(widget.license.id, updatedLicense);

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
        await _mediaService.deleteLicensePhoto(photoPath);

        // Update license
        if (!mounted) return;
        final licenseService = context.read<LicenseService>();
        final updatedPhotos = List<String>.from(
          widget.license.imagePaths ?? [],
        );
        updatedPhotos.remove(photoPath);

        final updatedLicense = widget.license.copyWith(
          imagePaths: updatedPhotos,
        );

        await licenseService.updateLicense(widget.license.id, updatedLicense);

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
        builder: (context) => LicensePhotoViewScreen(
          photos: widget.license.imagePaths ?? [],
          initialIndex: index,
          mediaService: _mediaService,
        ),
      ),
    );
  }

  void _showPermissionError(PermissionException e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(e.title),
        content: Text(e.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (e.isPermanentlyDenied)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }
}

class LicensePhotoViewScreen extends StatelessWidget {
  final List<String> photos;
  final int initialIndex;
  final MediaService mediaService;

  const LicensePhotoViewScreen({
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
