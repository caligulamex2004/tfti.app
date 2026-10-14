import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeRsvpWidget extends StatefulWidget {
  final String currentStatus;
  final bool isLocked;
  final Function(String) onRsvp;

  const SwipeRsvpWidget({
    super.key,
    required this.currentStatus,
    this.isLocked = false,
    required this.onRsvp,
  });

  @override
  State<SwipeRsvpWidget> createState() => _SwipeRsvpWidgetState();
}

class _SwipeRsvpWidgetState extends State<SwipeRsvpWidget> {
  double _dragPosition = 0.0;
  bool _isDragging = false;

  void _handleDragUpdate(DragUpdateDetails details, double maxDrag) {
    setState(() {
      _isDragging = true;
      _dragPosition += details.delta.dx;

      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
      if (_dragPosition < -maxDrag) _dragPosition = -maxDrag;
    });
  }

  void _handleDragEnd(double maxDrag) {
    setState(() => _isDragging = false);

    if (_dragPosition > maxDrag * 0.7) {
      widget.onRsvp('going');
      setState(() => _dragPosition = maxDrag);
    } else if (_dragPosition < -maxDrag * 0.7) {
      widget.onRsvp('declined');
      setState(() => _dragPosition = -maxDrag);
    } else {
      setState(() => _dragPosition = 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant SwipeRsvpWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStatus != oldWidget.currentStatus) {
      _dragPosition = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        final bool isCompact = trackWidth < 280;

        // --- 1. LOCKED STATE ---
        if (widget.isLocked && widget.currentStatus == 'pending') {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isCompact ? 12 : 16,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: Colors.grey, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "RSVP Closed",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }

        // --- 2. GOING STATE ---
        if (widget.currentStatus == 'going') {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isCompact ? 12 : 16,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: isCompact
                ? Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "You're in! 🤗",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!widget.isLocked)
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => widget.onRsvp('pending'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.green.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "Change",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "You're in! 🤗",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!widget.isLocked)
                        TextButton(
                          onPressed: () => widget.onRsvp('pending'),
                          child: const Text(
                            "Change",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
          );
        }

        // --- 3. DECLINED STATE ---
        if (widget.currentStatus == 'declined') {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isCompact ? 12 : 16,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: isCompact
                ? Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel, color: Colors.red, size: 24),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Missing out.",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!widget.isLocked)
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => widget.onRsvp('pending'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "Change RSVP",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.cancel, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "You're missing out.",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!widget.isLocked)
                        TextButton(
                          onPressed: () => widget.onRsvp('pending'),
                          child: const Text(
                            "Change",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
          );
        }

        // --- 4. COMPACT PENDING STATE (Squished Buttons) ---
        if (isCompact) {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onRsvp('declined');
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "Decline",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onRsvp('going');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "I'm In!",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // --- 5. FULL PENDING STATE (The Slider) ---
        const double thumbWidth = 100.0;
        final double maxDrag = (trackWidth - thumbWidth) / 2;

        return Container(
          width: trackWidth,
          height: 65,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(35),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 24,
                child: Text(
                  "« I'M OUT",
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Positioned(
                right: 24,
                child: Text(
                  "LET'S GO »",
                  style: TextStyle(
                    color: Colors.green.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: (trackWidth / 2) - (thumbWidth / 2) + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _handleDragUpdate(details, maxDrag),
                  onHorizontalDragEnd: (details) => _handleDragEnd(maxDrag),
                  child: Container(
                    width: thumbWidth,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chevron_left,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "SWIPE",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
