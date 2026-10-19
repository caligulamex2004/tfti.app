import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/rpg_glass_card.dart';

class VibeOptionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> pollOptions;
  final VoidCallback onAddOption;
  final Function(int) onRemoveOption;
  final Function(int) onSelectLocation;
  final Function(int) onClearLocation;

  const VibeOptionsCard({
    super.key,
    required this.pollOptions,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onSelectLocation,
    required this.onClearLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return RpgGlassCard(
      title: "Vibe Options",
      icon: Icons.format_list_bulleted,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "${pollOptions.length}/5 OPTIONS",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: primaryColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Pick some ideas and let the crew decide! You can always update the options later if plans change.",
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pollOptions.length,
            itemBuilder: (context, index) {
              final locText = (pollOptions[index]['location']
                      as TextEditingController)
                  .text;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "OPTION ${index + 1}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        if (index > 1)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: isDark
                                ? Colors.red.shade300
                                : Colors.red.shade600,
                            tooltip: "Remove option",
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              onRemoveOption(index);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller:
                          pollOptions[index]['title'] as TextEditingController,
                      maxLength: 30,
                      textCapitalization: TextCapitalization.words,
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        labelText: "Activity",
                        hintText: "e.g. Disc Golf, Happy Hour",
                        labelStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        counterText: "",
                        prefixIcon: Icon(
                          Icons.local_activity_outlined,
                          color: primaryColor,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: primaryColor.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pollOptions[index]['location']
                          as TextEditingController,
                      readOnly: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onSelectLocation(index);
                      },
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: "Location (Optional)",
                        hintText: "Tap to search address...",
                        labelStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        counterText: "",
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                          color: primaryColor,
                          size: 20,
                        ),
                        suffixIcon: locText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  onClearLocation(index);
                                },
                              )
                            : null,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: primaryColor.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (pollOptions.length < 5)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onAddOption();
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: Text(
                    "Add Option (${pollOptions.length}/5)",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(
                      color: primaryColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
