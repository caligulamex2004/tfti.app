import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Pure math helpers for [ImageCropperDialog] so viewport framing, gesture
/// clamping, and high-resolution canvas export stay pixel-for-pixel identical.
class CropTransformMath {
  CropTransformMath._();

  /// Effective dimensions of an image after [quarterTurns] 90-degree clockwise
  /// rotations.
  static Size effectiveImageSize(Size imageSize, int quarterTurns) {
    final normalizedTurns = ((quarterTurns % 4) + 4) % 4;
    if (normalizedTurns.isOdd) {
      return Size(imageSize.height, imageSize.width);
    }
    return imageSize;
  }

  /// Minimum scale factor that guarantees the rotated image completely covers
  /// [cropSize] with no exposed borders.
  static double computeBaseScale({
    required Size imageSize,
    required int quarterTurns,
    required Size cropSize,
  }) {
    final eff = effectiveImageSize(imageSize, quarterTurns);
    if (eff.width <= 0 || eff.height <= 0) return 1.0;
    return math.max(cropSize.width / eff.width, cropSize.height / eff.height);
  }

  /// Computes the crop box size that fits inside [stageSize] with [padding]
  /// while strictly preserving [aspectRatio].
  static Size computeCropSize({
    required Size stageSize,
    required double aspectRatio,
    double padding = 24.0,
    double maxWidth = 600.0,
    double maxHeight = 520.0,
  }) {
    final availW = math.min(
      maxWidth,
      math.max(1.0, stageSize.width - padding * 2),
    );
    final availH = math.min(
      maxHeight,
      math.max(1.0, stageSize.height - padding * 2),
    );

    if (availW / availH > aspectRatio) {
      final h = availH;
      return Size(h * aspectRatio, h);
    } else {
      final w = availW;
      return Size(w, w / aspectRatio);
    }
  }

  /// Clamps a normalized offset (expressed as fractions of `cropSize.width` and
  /// `cropSize.height`) so the image always covers the crop box completely.
  static Offset clampNormalizedOffset({
    required Offset normalizedOffset,
    required Size imageSize,
    required int quarterTurns,
    required double aspectRatio,
    required double scale,
  }) {
    final eff = effectiveImageSize(imageSize, quarterTurns);
    if (eff.width <= 0 || eff.height <= 0) return Offset.zero;

    final imgAspect = eff.width / eff.height;
    final double coverRatioX;
    final double coverRatioY;
    if (imgAspect >= aspectRatio) {
      coverRatioX = (imgAspect / aspectRatio) * scale;
      coverRatioY = scale;
    } else {
      coverRatioX = scale;
      coverRatioY = (aspectRatio / imgAspect) * scale;
    }

    final maxNormDx = math.max(0.0, (coverRatioX - 1.0) / 2.0);
    final maxNormDy = math.max(0.0, (coverRatioY - 1.0) / 2.0);

    return Offset(
      normalizedOffset.dx.clamp(-maxNormDx, maxNormDx),
      normalizedOffset.dy.clamp(-maxNormDy, maxNormDy),
    );
  }

  /// Computes the new image-center offset (in viewport pixels relative to the
  /// crop center) when zooming from [startScale] to [newScale] while keeping
  /// the image point under [startFocalFromCropCenter] pinned under
  /// [currentFocalFromCropCenter].
  static Offset computeFocalZoomOffset({
    required Offset startOffsetPx,
    required double startScale,
    required double newScale,
    required Offset startFocalFromCropCenter,
    required Offset currentFocalFromCropCenter,
  }) {
    final ratio = newScale / startScale;
    return currentFocalFromCropCenter -
        (startFocalFromCropCenter - startOffsetPx) * ratio;
  }

  /// Renders the cropped region of [image] to PNG bytes at
  /// `[outputWidth] x [outputHeight]`.
  static Future<Uint8List> cropImageToPng({
    required ui.Image image,
    required int quarterTurns,
    required double aspectRatio,
    required double scale,
    required Offset normalizedOffset,
    required int outputWidth,
    required int outputHeight,
  }) async {
    final outW = math.max(1, outputWidth);
    final outH = math.max(1, outputHeight);
    final cropSize = Size(outW.toDouble(), outH.toDouble());
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final clampedNorm = clampNormalizedOffset(
      normalizedOffset: normalizedOffset,
      imageSize: imageSize,
      quarterTurns: quarterTurns,
      aspectRatio: aspectRatio,
      scale: scale,
    );

    final baseScale = computeBaseScale(
      imageSize: imageSize,
      quarterTurns: quarterTurns,
      cropSize: cropSize,
    );
    final displayScale = baseScale * scale;
    final offsetPx = Offset(
      clampedNorm.dx * cropSize.width,
      clampedNorm.dy * cropSize.height,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fill an opaque background so transparent PNGs convert cleanly to JPEG.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cropSize.width, cropSize.height),
      Paint()..color = Colors.white,
    );

    canvas.save();
    canvas.translate(
      cropSize.width / 2.0 + offsetPx.dx,
      cropSize.height / 2.0 + offsetPx.dy,
    );
    final normalizedTurns = ((quarterTurns % 4) + 4) % 4;
    if (normalizedTurns != 0) {
      canvas.rotate(normalizedTurns * math.pi / 2.0);
    }
    canvas.scale(displayScale);
    canvas.drawImage(
      image,
      Offset(-image.width / 2.0, -image.height / 2.0),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(outW, outH);
    try {
      final byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw StateError('Failed to encode cropped image bytes.');
      }
      return byteData.buffer.asUint8List();
    } finally {
      croppedImage.dispose();
      picture.dispose();
    }
  }
}

/// Pure-Flutter interactive image cropper designed for seamless touch (pinch,
/// pan, double-tap) and desktop (drag, scroll-wheel, slider) cropping across
/// Web PWAs (including iPadOS/iOS Safari) without external JS/CDN dependencies.
class ImageCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final double aspectRatio;
  final bool isCircle;
  final String title;
  final int outputWidth;
  final int outputHeight;
  final double maxScale;

  const ImageCropperDialog({
    super.key,
    required this.imageBytes,
    this.aspectRatio = 1.0,
    this.isCircle = false,
    this.title = 'Adjust Photo',
    this.outputWidth = 1024,
    this.outputHeight = 1024,
    this.maxScale = 5.0,
  });

  /// Presents the cropper as a full-screen dialog route and returns the cropped
  /// PNG bytes, or `null` if the user cancels.
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    double aspectRatio = 1.0,
    bool isCircle = false,
    String title = 'Adjust Photo',
    int outputWidth = 1024,
    int outputHeight = 1024,
    double maxScale = 5.0,
  }) {
    return Navigator.of(context, rootNavigator: true).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => ImageCropperDialog(
          imageBytes: imageBytes,
          aspectRatio: aspectRatio,
          isCircle: isCircle,
          title: title,
          outputWidth: outputWidth,
          outputHeight: outputHeight,
          maxScale: maxScale,
        ),
      ),
    );
  }

  @override
  State<ImageCropperDialog> createState() => _ImageCropperDialogState();
}

class _ImageCropperDialogState extends State<ImageCropperDialog> {
  ui.Image? _image;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isInteracting = false;
  String? _errorMessage;

  double _scale = 1.0;
  Offset _normalizedOffset = Offset.zero;
  int _quarterTurns = 0;

  // Gesture baseline state
  double _gestureStartScale = 1.0;
  Offset _gestureStartOffsetPx = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;
  Offset? _lastDoubleTapLocalPos;

  // Cached latest layout metrics for gesture callbacks
  Size _stageSize = Size.zero;
  Size _cropSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    try {
      final decoded = await decodeImageFromList(widget.imageBytes);
      if (!mounted) {
        decoded.dispose();
        return;
      }
      setState(() {
        _image = decoded;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ImageCropperDialog decode error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load this image. Please try another photo.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Size get _imageSize {
    final img = _image;
    if (img == null) return Size.zero;
    return Size(img.width.toDouble(), img.height.toDouble());
  }

  bool get _hasTransformChanges =>
      (_scale - 1.0).abs() > 0.001 ||
      _normalizedOffset.distance > 0.001 ||
      _quarterTurns % 4 != 0;

  Offset _clampNormalized(Offset norm, double scale, [int? turns]) {
    if (_image == null) return Offset.zero;
    return CropTransformMath.clampNormalizedOffset(
      normalizedOffset: norm,
      imageSize: _imageSize,
      quarterTurns: turns ?? _quarterTurns,
      aspectRatio: widget.aspectRatio,
      scale: scale,
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_image == null || _cropSize.isEmpty) return;
    _gestureStartScale = _scale;
    _gestureStartOffsetPx = Offset(
      _normalizedOffset.dx * _cropSize.width,
      _normalizedOffset.dy * _cropSize.height,
    );
    _gestureStartFocalPoint = details.localFocalPoint;
    setState(() => _isInteracting = true);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_image == null || _cropSize.isEmpty) return;
    final cropCenter = Offset(_stageSize.width / 2.0, _stageSize.height / 2.0);
    final newScale = (_gestureStartScale * details.scale).clamp(
      1.0,
      widget.maxScale,
    );

    final newOffsetPx = CropTransformMath.computeFocalZoomOffset(
      startOffsetPx: _gestureStartOffsetPx,
      startScale: _gestureStartScale,
      newScale: newScale,
      startFocalFromCropCenter: _gestureStartFocalPoint - cropCenter,
      currentFocalFromCropCenter: details.localFocalPoint - cropCenter,
    );

    final rawNorm = Offset(
      newOffsetPx.dx / _cropSize.width,
      newOffsetPx.dy / _cropSize.height,
    );

    setState(() {
      _scale = newScale;
      _normalizedOffset = _clampNormalized(rawNorm, newScale);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isInteracting) {
      setState(() => _isInteracting = false);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _image == null || _cropSize.isEmpty) {
      return;
    }
    final zoomFactor = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
    final newScale = (_scale * zoomFactor).clamp(1.0, widget.maxScale);
    if ((newScale - _scale).abs() < 0.0001) return;

    final cropCenter = Offset(_stageSize.width / 2.0, _stageSize.height / 2.0);
    final focalFromCenter = event.localPosition - cropCenter;
    final currentOffsetPx = Offset(
      _normalizedOffset.dx * _cropSize.width,
      _normalizedOffset.dy * _cropSize.height,
    );
    final newOffsetPx = CropTransformMath.computeFocalZoomOffset(
      startOffsetPx: currentOffsetPx,
      startScale: _scale,
      newScale: newScale,
      startFocalFromCropCenter: focalFromCenter,
      currentFocalFromCropCenter: focalFromCenter,
    );
    final rawNorm = Offset(
      newOffsetPx.dx / _cropSize.width,
      newOffsetPx.dy / _cropSize.height,
    );

    setState(() {
      _scale = newScale;
      _normalizedOffset = _clampNormalized(rawNorm, newScale);
    });
  }

  void _onDoubleTap() {
    if (_image == null || _cropSize.isEmpty) return;
    if (_scale > 1.05) {
      setState(() {
        _scale = 1.0;
        _normalizedOffset = Offset.zero;
      });
      return;
    }

    final targetScale = math.min(2.0, widget.maxScale);
    final cropCenter = Offset(_stageSize.width / 2.0, _stageSize.height / 2.0);
    final tapPos = _lastDoubleTapLocalPos ?? cropCenter;
    final focalFromCenter = tapPos - cropCenter;
    final currentOffsetPx = Offset(
      _normalizedOffset.dx * _cropSize.width,
      _normalizedOffset.dy * _cropSize.height,
    );
    final newOffsetPx = CropTransformMath.computeFocalZoomOffset(
      startOffsetPx: currentOffsetPx,
      startScale: _scale,
      newScale: targetScale,
      startFocalFromCropCenter: focalFromCenter,
      currentFocalFromCropCenter: focalFromCenter,
    );
    final rawNorm = Offset(
      newOffsetPx.dx / _cropSize.width,
      newOffsetPx.dy / _cropSize.height,
    );

    setState(() {
      _scale = targetScale;
      _normalizedOffset = _clampNormalized(rawNorm, targetScale);
    });
  }

  void _setZoomFromSlider(double newScale) {
    if (_image == null) return;
    final clampedScale = newScale.clamp(1.0, widget.maxScale);
    final ratio = clampedScale / _scale;
    final scaledNorm = _normalizedOffset * ratio;
    setState(() {
      _scale = clampedScale;
      _normalizedOffset = _clampNormalized(scaledNorm, clampedScale);
    });
  }

  void _rotateBy(int deltaTurns) {
    if (_image == null) return;
    final nextTurns = (_quarterTurns + deltaTurns) % 4;
    setState(() {
      _quarterTurns = nextTurns;
      _scale = 1.0;
      _normalizedOffset = Offset.zero;
    });
  }

  void _reset() {
    setState(() {
      _scale = 1.0;
      _normalizedOffset = Offset.zero;
      _quarterTurns = 0;
    });
  }

  Future<void> _saveCrop() async {
    final img = _image;
    if (img == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final pngBytes = await CropTransformMath.cropImageToPng(
        image: img,
        quarterTurns: _quarterTurns,
        aspectRatio: widget.aspectRatio,
        scale: _scale,
        normalizedOffset: _normalizedOffset,
        outputWidth: widget.outputWidth,
        outputHeight: widget.outputHeight,
      );
      if (!mounted) return;
      Navigator.of(context).pop(pngBytes);
    } catch (e) {
      debugPrint('ImageCropperDialog crop error: $e');
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to crop image. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    const bgColor = Color(0xFF0E1015);
    const surfaceColor = Color(0xFF181B22);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 84,
        leading: TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilledButton(
                onPressed: (_isLoading || _errorMessage != null || _isSaving)
                    ? null
                    : _saveCrop,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _stageSize = constraints.biggest;
                        _cropSize = CropTransformMath.computeCropSize(
                          stageSize: _stageSize,
                          aspectRatio: widget.aspectRatio,
                        );
                        final cropRect = Rect.fromCenter(
                          center: Offset(
                            _stageSize.width / 2.0,
                            _stageSize.height / 2.0,
                          ),
                          width: _cropSize.width,
                          height: _cropSize.height,
                        );

                        return Listener(
                          onPointerSignal: _onPointerSignal,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: _onScaleUpdate,
                            onScaleEnd: _onScaleEnd,
                            onDoubleTapDown: (d) =>
                                _lastDoubleTapLocalPos = d.localPosition,
                            onDoubleTap: _onDoubleTap,
                            child: ClipRect(
                              child: CustomPaint(
                                size: _stageSize,
                                painter: _CropStagePainter(
                                  image: _image!,
                                  cropRect: cropRect,
                                  isCircle: widget.isCircle,
                                  quarterTurns: _quarterTurns,
                                  scale: _scale,
                                  normalizedOffset: _normalizedOffset,
                                  showStrongGrid: _isInteracting,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: surfaceColor,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Drag to move • Pinch or slide to zoom',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Zoom Out',
                                  icon: const Icon(
                                    Icons.zoom_out_rounded,
                                    color: Colors.white70,
                                  ),
                                  onPressed: _scale <= 1.001
                                      ? null
                                      : () => _setZoomFromSlider(_scale - 0.25),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: primaryColor,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      overlayColor: primaryColor.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    child: Slider(
                                      value: _scale.clamp(1.0, widget.maxScale),
                                      min: 1.0,
                                      max: widget.maxScale,
                                      onChanged: _setZoomFromSlider,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Zoom In',
                                  icon: const Icon(
                                    Icons.zoom_in_rounded,
                                    color: Colors.white70,
                                  ),
                                  onPressed: _scale >= widget.maxScale - 0.001
                                      ? null
                                      : () => _setZoomFromSlider(_scale + 0.25),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                _ToolbarActionButton(
                                  icon: Icons.rotate_left_rounded,
                                  label: 'Rotate Left',
                                  onPressed: () => _rotateBy(-1),
                                ),
                                _ToolbarActionButton(
                                  icon: Icons.rotate_right_rounded,
                                  label: 'Rotate Right',
                                  onPressed: () => _rotateBy(1),
                                ),
                                _ToolbarActionButton(
                                  icon: Icons.refresh_rounded,
                                  label: 'Reset',
                                  onPressed: _hasTransformChanges
                                      ? _reset
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ToolbarActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ToolbarActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? Colors.white : Colors.white30;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 20, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}

class _CropStagePainter extends CustomPainter {
  final ui.Image image;
  final Rect cropRect;
  final bool isCircle;
  final int quarterTurns;
  final double scale;
  final Offset normalizedOffset;
  final bool showStrongGrid;

  const _CropStagePainter({
    required this.image,
    required this.cropRect,
    required this.isCircle,
    required this.quarterTurns,
    required this.scale,
    required this.normalizedOffset,
    required this.showStrongGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final baseScale = CropTransformMath.computeBaseScale(
      imageSize: imageSize,
      quarterTurns: quarterTurns,
      cropSize: cropRect.size,
    );
    final displayScale = baseScale * scale;
    final offsetPx = Offset(
      normalizedOffset.dx * cropRect.width,
      normalizedOffset.dy * cropRect.height,
    );

    // 1. Draw the transformed image
    canvas.save();
    canvas.translate(
      cropRect.center.dx + offsetPx.dx,
      cropRect.center.dy + offsetPx.dy,
    );
    final normalizedTurns = ((quarterTurns % 4) + 4) % 4;
    if (normalizedTurns != 0) {
      canvas.rotate(normalizedTurns * math.pi / 2.0);
    }
    canvas.scale(displayScale);
    canvas.drawImage(
      image,
      Offset(-image.width / 2.0, -image.height / 2.0),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    // 2. Dim everything outside the crop mask
    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (isCircle) {
      overlayPath.addOval(cropRect);
    } else {
      overlayPath.addRect(cropRect);
    }
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );

    // 3. Rule-of-thirds guides clipped inside the crop cutout
    canvas.save();
    if (isCircle) {
      canvas.clipPath(Path()..addOval(cropRect));
    } else {
      canvas.clipRect(cropRect);
    }
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: showStrongGrid ? 0.45 : 0.2)
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 2; i++) {
      final dx = cropRect.left + cropRect.width * (i / 3.0);
      final dy = cropRect.top + cropRect.height * (i / 3.0);
      canvas.drawLine(
        Offset(dx, cropRect.top),
        Offset(dx, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, dy),
        Offset(cropRect.right, dy),
        gridPaint,
      );
    }
    canvas.restore();

    // 4. Crisp border around the crop cutout
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (isCircle) {
      canvas.drawOval(cropRect, borderPaint);
    } else {
      canvas.drawRect(cropRect, borderPaint);
      // Corner accents for rectangular banner framing
      final cornerLen = math.min(20.0, cropRect.shortestSide * 0.15);
      final cornerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final corners = [
        // Top-left
        [
          Offset(cropRect.left, cropRect.top + cornerLen),
          cropRect.topLeft,
          Offset(cropRect.left + cornerLen, cropRect.top),
        ],
        // Top-right
        [
          Offset(cropRect.right - cornerLen, cropRect.top),
          cropRect.topRight,
          Offset(cropRect.right, cropRect.top + cornerLen),
        ],
        // Bottom-right
        [
          Offset(cropRect.right, cropRect.bottom - cornerLen),
          cropRect.bottomRight,
          Offset(cropRect.right - cornerLen, cropRect.bottom),
        ],
        // Bottom-left
        [
          Offset(cropRect.left + cornerLen, cropRect.bottom),
          cropRect.bottomLeft,
          Offset(cropRect.left, cropRect.bottom - cornerLen),
        ],
      ];

      for (final pts in corners) {
        final p = Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy);
        canvas.drawPath(p, cornerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CropStagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.cropRect != cropRect ||
        oldDelegate.isCircle != isCircle ||
        oldDelegate.quarterTurns != quarterTurns ||
        oldDelegate.scale != scale ||
        oldDelegate.normalizedOffset != normalizedOffset ||
        oldDelegate.showStrongGrid != showStrongGrid;
  }
}
