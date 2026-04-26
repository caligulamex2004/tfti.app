import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../utils/theme_provider.dart';

class AddFriendSection extends StatelessWidget {
  final bool isDark;
  final Color primaryColor;
  final bool useGradient;
  final bool isAddingByUsername;
  final TextEditingController usernameController;
  final TextEditingController phoneController;
  final String statusMessage;
  final Function(bool) onToggleInputType;
  final Function(String) onPhoneChanged;
  final VoidCallback onSubmit;

  const AddFriendSection({
    super.key,
    required this.isDark,
    required this.primaryColor,
    this.useGradient = false,
    required this.isAddingByUsername,
    required this.usernameController,
    required this.phoneController,
    required this.statusMessage,
    required this.onToggleInputType,
    required this.onPhoneChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 20.0,
        top: 20.0,
        right: 20.0,
        bottom: 4.0,
      ),
      decoration: BoxDecoration(
        color: useGradient ? null : Theme.of(context).cardColor,
        gradient: useGradient ? themeProvider.appGradient : null,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Grow the Squad",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
              color: (useGradient || isDark) ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text(
                    "Username",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(
                    "Phone Number",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              selected: {isAddingByUsername},
              onSelectionChanged: (newSelection) {
                HapticFeedback.selectionClick();
                onToggleInputType(newSelection.first);
              },
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                selectedBackgroundColor: primaryColor,
                selectedForegroundColor: themeProvider.onPrimaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: isAddingByUsername
                    ? TextField(
                        controller: usernameController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: "username",
                          prefixText: "@ ",
                          prefixStyle: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        onSubmitted: (_) => onSubmit(),
                      )
                    : IntlPhoneField(
                        controller: phoneController,
                        initialCountryCode: 'US',
                        dropdownIconPosition: IconPosition.trailing,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: "Phone Number",
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade50,
                          counterText: "",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        onChanged: (phone) =>
                            onPhoneChanged(phone.completeNumber),
                        onSubmitted: (_) => onSubmit(),
                      ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: themeProvider.onPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    elevation: 2,
                  ),
                  child: const Text(
                    "Add",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 28,
            child: statusMessage.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        color:
                            statusMessage.contains("Added") ||
                                statusMessage.contains("prepared")
                            ? (isDark ? Colors.greenAccent : Colors.green)
                            : (isDark ? Colors.redAccent : Colors.red),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
