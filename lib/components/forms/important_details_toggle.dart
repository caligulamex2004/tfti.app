import 'package:flutter/material.dart';

class ImportantDetailsToggle extends StatelessWidget {
  final bool isImportant;
  final bool isPast;
  final ValueChanged<bool> onChanged;

  const ImportantDetailsToggle({
    super.key,
    required this.isImportant,
    required this.isPast,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: isPast ? null : () => onChanged(!isImportant),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isImportant
                ? Colors.red
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isImportant ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isImportant ? Icons.gpp_maybe : Icons.gpp_maybe_outlined,
              size: 20,
              color: isImportant
                  ? Colors.red
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  "Important Details",
                  maxLines: 1,
                  style: TextStyle(
                    fontWeight:
                        isImportant ? FontWeight.bold : FontWeight.normal,
                    color: isImportant
                        ? Colors.red
                        : (isDark ? Colors.white : Colors.black87),
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
