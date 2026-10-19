import 'package:flutter/material.dart';
import '../../utils/event_type_visuals.dart';

/// A rich procedural default banner rendered when an event does not have an uploaded banner image.
///
/// Features:
/// - Event-type seeded base gradient (Royal Blue for Hangout, Warm Amber for Vibe Check)
/// - Ambient radial glow orb in the accent color
/// - Watermarked background glyph matching the event type's identity
/// - Thumbnail variant for compact list tiles (e.g. [CardLandscapeTile])
class DefaultEventBanner extends StatelessWidget {
  final bool isVibeCheck;
  final bool isThumbnail;
  final double? thumbnailSize;

  const DefaultEventBanner({
    super.key,
    required this.isVibeCheck,
  })  : isThumbnail = false,
        thumbnailSize = null;

  const DefaultEventBanner.thumbnail({
    super.key,
    required this.isVibeCheck,
    this.thumbnailSize = 60,
  }) : isThumbnail = true;

  @override
  Widget build(BuildContext context) {
    final visuals = EventTypeVisuals.forType(isVibeCheck: isVibeCheck);

    if (isThumbnail) {
      final size = thumbnailSize ?? 60.0;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: visuals.defaultBannerGradient,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    visuals.glowColor,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Icon(
              visuals.icon,
              size: size * 0.45,
              color: visuals.accentColor,
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base Event-Type Gradient
        Container(
          decoration: BoxDecoration(
            gradient: visuals.defaultBannerGradient,
          ),
        ),
        // Ambient Radial Glow Orb in the upper-right
        Positioned(
          top: -50,
          right: -20,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  visuals.glowColor,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Subtle Secondary Glow in the lower-left for depth
        Positioned(
          bottom: -40,
          left: -30,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  visuals.glowColor.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Subtle Watermark Icon in the background
        Positioned(
          right: 12,
          bottom: 8,
          child: Icon(
            visuals.icon,
            size: 96,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}
