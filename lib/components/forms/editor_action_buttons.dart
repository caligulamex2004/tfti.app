import 'package:flutter/material.dart';
import '../../utils/theme_provider.dart';

class EditorActionButtons extends StatelessWidget {
  final bool isEditing;
  final bool isMainHost;
  final bool isPast;
  final bool isLoading;
  final String submitText;
  final VoidCallback onSubmit;
  final VoidCallback onDelete;

  const EditorActionButtons({
    super.key,
    required this.isEditing,
    required this.isMainHost,
    required this.isPast,
    required this.isLoading,
    required this.submitText,
    required this.onSubmit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: (isPast || isLoading) ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: themeProvider.onPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              submitText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        if (isEditing && isMainHost) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: (isPast || isLoading) ? null : onDelete,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              "Delete Hangout",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }
}
