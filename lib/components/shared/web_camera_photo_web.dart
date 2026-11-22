// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<Uint8List?> showWebCameraPhotoDialog(
  BuildContext context, {
  String title = 'Take Profile Photo',
  double aspectRatio = 1.0,
  bool showCircleGuide = true,
}) async {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _WebCameraDialog(
      title: title,
      aspectRatio: aspectRatio,
      showCircleGuide: showCircleGuide,
    ),
  );
}

class _WebCameraDialog extends StatefulWidget {
  final String title;
  final double aspectRatio;
  final bool showCircleGuide;

  const _WebCameraDialog({
    required this.title,
    required this.aspectRatio,
    required this.showCircleGuide,
  });

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
        ..setAttribute('playsinline', 'true')
        ..setAttribute('webkit-playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..srcObject = stream;
      try {
        await video.play();
      } catch (_) {}

      _videoElement = video;
      final viewId = 'webcam-capture-${DateTime.now().millisecondsSinceEpoch}';
      _viewType = viewId;

      // Register platform view for the video element
      ui_web.platformViewRegistry.registerViewFactory(
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

      // Capture the full video frame so the user can pan, zoom, and crop freely
      // in the follow-up cropper dialog.
      final canvas = html.CanvasElement(width: vWidth, height: vHeight);
      canvas.context2D.drawImageScaled(
        video,
        0,
        0,
        vWidth,
        vHeight,
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

    final previewWidth = widget.aspectRatio >= 1.2 ? 320.0 : 280.0;
    final previewHeight = previewWidth / widget.aspectRatio;

    return Dialog(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
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
                width: previewWidth,
                height: previewHeight,
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
                              if (widget.showCircleGuide)
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
