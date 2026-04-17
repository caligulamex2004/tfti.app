import 'package:flutter/material.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Pick some ideas and let the crew decide! You can always update the options later if plans change.",
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pollOptions.length,
            itemBuilder: (context, index) {
              return Card(
                elevation: 0,
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Option ${index + 1}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          if (index > 1)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => onRemoveOption(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller:
                            pollOptions[index]['title']
                                as TextEditingController,
                        maxLength: 30,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: "Activity (e.g. Disc Golf)",
                          counterText: "",
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller:
                            pollOptions[index]['location']
                                as TextEditingController,
                        readOnly: true,
                        onTap: () => onSelectLocation(index),
                        maxLength: 100,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: "Tap to search address... (Optional)",
                          counterText: "",
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          prefixIcon: const Icon(Icons.location_on, size: 18),
                          suffixIcon:
                              (pollOptions[index]['location']
                                      as TextEditingController)
                                  .text
                                  .isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => onClearLocation(index),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (pollOptions.length < 5)
            Center(
              child: TextButton.icon(
                onPressed: onAddOption,
                icon: Icon(Icons.add_circle, color: primaryColor),
                label: Text(
                  "Add another option",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
