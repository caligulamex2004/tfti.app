// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<Uint8List?> showWebCameraPhotoDialog(BuildContext context) async {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _WebCameraDialog(),
  );
}

class _WebCameraDialog extends StatefulWidget {
  const _WebCameraDialog();

  @override
  State<_WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<_WebCameraDialog> {
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  String? _viewType;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebcam();
  }

  Future<void> _initWebcam() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        setState(() {
          _errorMessage = "Camera access is not supported by your browser.";
          _isLoading = false;
        });
        return;
      }

      final stream = await mediaDevices.getUserMedia({'video': true});
      _mediaStream = stream;

      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..srcObject = stream;

      _videoElement = video;
      final viewId = 'webcam-capture-${DateTime.now().millisecondsSinceEpoch}';
      _viewType = viewId;

      // Register platform view for the video element
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        viewId,
        (int id) => video,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Webcam init error: $e");
      if (mounted) {
        setState(() {
          _errorMessage =
              "Could not access camera. Please allow camera permissions in your browser.";
          _isLoading = false;
        });
      }
    }
  }

  void _capturePhoto() {
    if (_videoElement == null) return;

    try {
      final video = _videoElement!;
      final vWidth = video.videoWidth > 0 ? video.videoWidth : 640;
      final vHeight = video.videoHeight > 0 ? video.videoHeight : 480;

      // Crop to a square centered on the video for the avatar
      final int size = vWidth < vHeight ? vWidth : vHeight;
      final int startX = (vWidth - size) ~/ 2;
      final int startY = (vHeight - size) ~/ 2;

      final canvas = html.CanvasElement(width: size, height: size);
      canvas.context2D.drawImageScaledFromSource(
        video,
        startX,
        startY,
        size,
        size,
        0,
        0,
        size,
        size,
      );

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.95);
      final base64String = dataUrl.split(',').last;
      final bytes = Uint8List.fromList(base64Decode(base64String));

      _stopStream();
      Navigator.pop(context, bytes);
    } catch (e) {
      debugPrint("Error capturing photo from webcam: $e");
    }
  }

  void _stopStream() {
    _mediaStream?.getTracks().forEach((track) {
      track.stop();
    });
    _mediaStream = null;
    _videoElement?.srcObject = null;
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Take Profile Photo",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 280,
                height: 280,
                color: Colors.black,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.videocam_off_rounded,
                                    color: Colors.white70,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton(
                                    onPressed: _initWebcam,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text("Retry"),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              if (_viewType != null)
                                HtmlElementView(viewType: _viewType!),
                              // Circular avatar guide overlay
                              Container(
                                width: 240,
                                height: 240,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage == null && !_isLoading)
              ElevatedButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: const Text(
                  "Snap Photo",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
