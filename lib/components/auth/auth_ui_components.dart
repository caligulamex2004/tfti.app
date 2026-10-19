import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme_provider.dart';

// --- AUTH TEXT FIELD ---
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isNumber;
  final String? prefixText;
  final int? maxLength;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isNumber = false,
    this.prefixText,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        prefixIcon: Icon(icon, color: primaryColor),
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        filled: true,
        fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        counterText: "", // Hides the max length counter natively
      ),
    );
  }
}

// --- AUTH BUTTON ---
class AuthButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthButton({
    super.key,
    required this.text,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: themeProvider.onPrimaryColor,
          disabledBackgroundColor: primaryColor.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: onPressed == null ? 0 : 2,
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: themeProvider.onPrimaryColor,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

// --- AUTH CHECKBOX ---
class AuthCheckbox extends StatelessWidget {
  final String text;
  final bool value;
  final Function(bool?) onChanged;
  final VoidCallback? onTextTap;

  const AuthCheckbox({
    super.key,
    required this.text,
    required this.value,
    required this.onChanged,
    this.onTextTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: primaryColor,
            side: BorderSide(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onTextTap,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: onTextTap != null
                    ? primaryColor
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                decoration: onTextTap != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- RECAPTCHA TERMS DISCLOSURE ---
class RecaptchaDisclosure extends StatelessWidget {
  const RecaptchaDisclosure({super.key});

  static const String privacyPolicyUrl = "https://policies.google.com/privacy";
  static const String termsOfServiceUrl = "https://policies.google.com/terms";

  Future<void> _launchExternal(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not launch $url: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final mutedColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
      child: Text.rich(
        TextSpan(
          text: "This site is protected by reCAPTCHA and the Google ",
          style: TextStyle(
            fontSize: 11,
            color: mutedColor,
            height: 1.35,
          ),
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InkWell(
                onTap: () => _launchExternal(privacyPolicyUrl),
                child: Text(
                  "Privacy Policy",
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryColor,
                    decoration: TextDecoration.underline,
                    decorationColor: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const TextSpan(text: " and "),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: InkWell(
                onTap: () => _launchExternal(termsOfServiceUrl),
                child: Text(
                  "Terms of Service",
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryColor,
                    decoration: TextDecoration.underline,
                    decorationColor: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const TextSpan(text: " apply."),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
