import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';

// stateful widget manages its own image cropping and picking, and simply tells
// the parent page when a new image is ready or if the current one was removed
class BannerPicker extends StatefulWidget {
  final String? existingImageUrl;
  final bool isPast;
  final Function(String? localPath, bool isRemoved) onImageChanged;

  const BannerPicker({
    super.key,
    this.existingImageUrl,
    required this.isPast,
    required this.onImageChanged,
  });

  @override
  State<BannerPicker> createState() => _BannerPickerState();
}

class _BannerPickerState extends State<BannerPicker> {
  String? _localBannerPath;
  bool _removeBanner = false;

  void _showBannerOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasExistingUrl = widget.existingImageUrl != null && !_removeBanner;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndCropBanner(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take a Photo"),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndCropBanner(ImageSource.camera);
              },
            ),
            if (_localBannerPath != null || hasExistingUrl) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "Remove Banner",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _localBannerPath = null;
                    _removeBanner = true;
                  });
                  widget.onImageChanged(null, true);
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCropBanner(ImageSource source) async {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Banner',
          toolbarColor: primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Adjust Banner',
          cancelButtonTitle: 'Cancel',
          doneButtonTitle: 'Save',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (!mounted) return;

    if (croppedFile != null) {
      setState(() {
        _localBannerPath = croppedFile.path;
        _removeBanner = false;
      });
      widget.onImageChanged(_localBannerPath, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final hasExistingUrl = widget.existingImageUrl != null && !_removeBanner;
    final hasLocalImage = _localBannerPath != null;
    final hasImage = hasExistingUrl || hasLocalImage;

    DecorationImage? imageDecoration;
    if (hasLocalImage) {
      imageDecoration = DecorationImage(
        image: FileImage(File(_localBannerPath!)),
        fit: BoxFit.cover,
      );
    } else if (hasExistingUrl) {
      imageDecoration = DecorationImage(
        image: CachedNetworkImageProvider(widget.existingImageUrl!),
        fit: BoxFit.cover,
      );
    }

    return GestureDetector(
      onTap: widget.isPast ? null : _showBannerOptions,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasImage
                    ? primaryColor
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                width: hasImage ? 2 : 1.5,
              ),
              image: imageDecoration,
            ),
            child: !hasImage
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Add Event Banner",
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Container(
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
