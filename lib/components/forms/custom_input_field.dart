import 'package:flutter/material.dart';

// Every text field created by using this will now have the same styling and iOS keyboard logic
class CustomInputField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final Color? prefixIconColor;
  final Widget? suffixIcon;
  final TextEditingController? controller;
  final bool readOnly;
  final bool enabled;
  final int? maxLength;
  final int? maxLines;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  const CustomInputField({
    super.key,
    required this.label,
    this.hint,
    required this.prefixIcon,
    this.prefixIconColor,
    this.suffixIcon,
    this.controller,
    this.readOnly = false,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final fillColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      enabled: enabled,
      maxLength: maxLength,
      maxLines: maxLines,
      onTap: onTap,
      onTapOutside: (_) =>
          FocusScope.of(context).unfocus(), // Master Keyboard Fix
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines != null && maxLines! > 1,
        counterText: "",
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        prefixIcon: Icon(prefixIcon, color: prefixIconColor ?? primaryColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: primaryColor.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }
}
