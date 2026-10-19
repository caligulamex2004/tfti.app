import 'package:flutter/material.dart';

// master wrapper for the beautiful, elevated card UI ("The Vitals", "The Extras", etc.)
class RpgGlassCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  // Optional overrides & additions
  final Color? iconColor;
  final Color? titleColor;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? contentPadding;

  const RpgGlassCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.titleColor,
    this.trailing,
    this.margin,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Use the custom colors if provided, otherwise fall back to the defaults
    final effectiveIconColor = iconColor ?? primaryColor;
    final effectiveTitleColor =
        titleColor ?? (isDark ? Colors.white : Colors.black87);

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Material(
                  color: effectiveIconColor.withValues(alpha: 0.15),
                  shape: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(7.0),
                    child: Icon(icon, color: effectiveIconColor, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: effectiveTitleColor,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          Padding(
            padding: contentPadding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}
