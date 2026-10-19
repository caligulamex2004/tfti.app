import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Encapsulates the visual identity, colors, and iconography for each event type
/// (Hangout vs Vibe Check).
class EventTypeVisuals {
  final String label;
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;
  final Color glowColor;
  final Color pillBackgroundColor;
  final Color pillBorderColor;
  final Color pillTextColor;
  final LinearGradient defaultBannerGradient;

  const EventTypeVisuals({
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
    required this.glowColor,
    required this.pillBackgroundColor,
    required this.pillBorderColor,
    required this.pillTextColor,
    required this.defaultBannerGradient,
  });

  /// Resolves the visual identity for an event based on whether it is a Vibe Check or Hangout.
  static EventTypeVisuals forType({required bool isVibeCheck}) {
    if (isVibeCheck) {
      return EventTypeVisuals(
        label: "VIBE CHECK",
        icon: Symbols.earthquake,
        primaryColor: const Color(0xFFF59E0B), // Warm Amber 500
        accentColor: const Color(0xFFFBBF24),  // Amber 400
        glowColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        pillBackgroundColor: const Color(0xFF78350F).withValues(alpha: 0.35),
        pillBorderColor: const Color(0xFFF59E0B).withValues(alpha: 0.6),
        pillTextColor: const Color(0xFFFDE68A), // Light Amber
        defaultBannerGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF140C03),
            Color(0xFF2E1903),
            Color(0xFF452405),
          ],
        ),
      );
    } else {
      return EventTypeVisuals(
        label: "HANGOUT",
        icon: Icons.how_to_vote,
        primaryColor: const Color(0xFF3B82F6), // Royal Blue 500
        accentColor: const Color(0xFF60A5FA),  // Blue 400
        glowColor: const Color(0xFF2563EB).withValues(alpha: 0.35),
        pillBackgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
        pillBorderColor: const Color(0xFF3B82F6).withValues(alpha: 0.6),
        pillTextColor: const Color(0xFFBFDBFE), // Light Royal Blue
        defaultBannerGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF060B14),
            Color(0xFF0F1E36),
            Color(0xFF1E3A8A),
          ],
        ),
      );
    }
  }
}
