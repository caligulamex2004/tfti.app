import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/waitlist_service.dart';
import '../../utils/theme_provider.dart';

class MobileWaitlistDialog extends StatefulWidget {
  final String initialPlatform;
  final WaitlistService? waitlistService;

  const MobileWaitlistDialog({
    super.key,
    this.initialPlatform = 'both',
    this.waitlistService,
  });

  static Future<void> show(
    BuildContext context, {
    String initialPlatform = 'both',
    WaitlistService? waitlistService,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => MobileWaitlistDialog(
        initialPlatform: initialPlatform,
        waitlistService: waitlistService,
      ),
    );
  }

  @override
  State<MobileWaitlistDialog> createState() => _MobileWaitlistDialogState();
}

class _MobileWaitlistDialogState extends State<MobileWaitlistDialog> {
  late String _selectedPlatform;
  final _emailController = TextEditingController();
  late final WaitlistService _waitlistService;

  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPlatform = widget.initialPlatform;
    _waitlistService = widget.waitlistService ?? WaitlistService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (email.isEmpty) {
      setState(() => _errorMessage = "Please enter your email address.");
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = "Please enter a valid email address.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _waitlistService.joinWaitlist(
        email: email,
        platform: _selectedPlatform,
        source: 'web_login',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Something went wrong. Please try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isSuccess
              ? _buildSuccessView(context, isDark, primaryColor)
              : _buildFormView(context, isDark, primaryColor),
        ),
      ),
    );
  }

  Widget _buildFormView(BuildContext context, bool isDark, Color primaryColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Symbols.rocket_launch,
                color: primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Mobile App Waitlist",
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "iOS & Android coming soon",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          "We're preparing our native mobile apps for launch. Sign up below to get early beta access and launch day notifications.",
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 18),

        // Platform Selector
        Text(
          "Platform preference:",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPlatformOption(
                label: "iOS",
                icon: Icons.apple,
                value: "ios",
                primaryColor: primaryColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPlatformOption(
                label: "Android",
                icon: Icons.android,
                value: "android",
                primaryColor: primaryColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPlatformOption(
                label: "Both",
                icon: Symbols.devices,
                value: "both",
                primaryColor: primaryColor,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Email TextField
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: "Your email address",
            hintText: "you@example.com",
            prefixIcon: Icon(Icons.email_outlined, color: primaryColor, size: 20),
            errorText: _errorMessage,
            filled: true,
            fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
        const SizedBox(height: 22),

        // Submit Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: themeProvider.onPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: themeProvider.onPrimaryColor,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Notify Me at Launch",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformOption({
    required String label,
    required IconData icon,
    required String value,
    required Color primaryColor,
    required bool isDark,
  }) {
    final isSelected = _selectedPlatform == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlatform = value;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? themeProvider.pillBackgroundColor
              : themeProvider.chipUnselectedBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? themeProvider.pillBackgroundColor
                : themeProvider.chipBorderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? themeProvider.pillTextColor
                  : themeProvider.chipUnselectedTextColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? themeProvider.pillTextColor
                    : themeProvider.chipUnselectedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, bool isDark, Color primaryColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 44,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          "You're on the list! 🎉",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "We've reserved your spot. As soon as the app is ready on ${_selectedPlatform == 'both' ? 'iOS and Android' : (_selectedPlatform == 'ios' ? 'iOS' : 'Android')}, we'll send an invite to:",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _emailController.text.trim(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: themeProvider.onPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Done",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
