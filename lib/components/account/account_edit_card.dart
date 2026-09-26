import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AccountEditCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController statusController;
  final String phoneNumber;
  final bool showPhoneNumber;
  final ValueChanged<bool> onShowPhoneChanged;
  final int selectedColorValue;
  final List<Color> colors;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onSave;

  const AccountEditCard({
    super.key,
    required this.nameController,
    required this.statusController,
    required this.phoneNumber,
    required this.showPhoneNumber,
    required this.onShowPhoneChanged,
    required this.selectedColorValue,
    required this.colors,
    required this.onColorSelected,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Edit Profile",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 24),

          // DISPLAY NAME
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            maxLength: 50,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: "Display Name",
              labelStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              prefixIcon: Icon(Icons.person, color: primaryColor),
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: primaryColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              counterText: "",
            ),
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              onSave();
            },
            onEditingComplete: () {
              FocusManager.instance.primaryFocus?.unfocus();
              onSave();
            },
          ),
          const SizedBox(height: 16),

          // MOOD / STATUS
          TextField(
            controller: statusController,
            textInputAction: TextInputAction.done,
            maxLength: 35,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: "I'm feeling like...",
              labelStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              prefixIcon: Icon(Symbols.mood, color: primaryColor),
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: primaryColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              counterText: "",
            ),
            onTapOutside: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              onSave();
            },
            onEditingComplete: () {
              FocusManager.instance.primaryFocus?.unfocus();
              onSave();
            },
          ),
          const SizedBox(height: 16),

          // PHONE NUMBER & PRIVACY TOGGLE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_android, size: 20, color: primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phoneNumber.isNotEmpty
                            ? phoneNumber
                            : "No phone number",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Show to Squad",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: showPhoneNumber,
                  activeThumbColor: primaryColor,
                  onChanged: (val) {
                    onShowPhoneChanged(val);
                    onSave();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // SIGNATURE COLOR
          Text(
            "Signature Color",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: colors.map((color) {
              final isSelected = selectedColorValue == color.toARGB32();
              final isWhite = color == Colors.white;

              return GestureDetector(
                onTap: () {
                  onColorSelected(color);
                  onSave();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 48 : 42,
                  height: isSelected ? 48 : 42,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (isWhite && !isDark
                                ? Colors.grey.shade400
                                : Colors.white)
                          : (isWhite && !isDark
                                ? Colors.grey.shade300
                                : Colors.transparent),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: isWhite ? Colors.grey.shade800 : Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
