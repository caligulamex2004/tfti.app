import 'package:flutter/material.dart';
import '../../utils/event_type_visuals.dart';

/// A reusable badge/pill that identifies an event as a "HANGOUT" (Royal Blue)
/// or a "VIBE CHECK" (Amber), featuring the event type's signature icon and typography.
class EventTypePill extends StatelessWidget {
  final bool isVibeCheck;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const EventTypePill({
    super.key,
    required this.isVibeCheck,
    this.fontSize = 10,
    this.iconSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = EventTypeVisuals.forType(isVibeCheck: isVibeCheck);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: visuals.pillBackgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: visuals.pillBorderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            visuals.icon,
            size: iconSize,
            color: visuals.pillTextColor,
          ),
          const SizedBox(width: 4),
          Text(
            visuals.label,
            style: TextStyle(
              color: visuals.pillTextColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
