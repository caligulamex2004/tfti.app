import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../pages/hangout_editor_page.dart';
import '../../pages/vibe_check_editor_page.dart';
import '../../utils/theme_provider.dart';

class HomeActionFab extends StatelessWidget {
  const HomeActionFab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FloatingActionButton(
      backgroundColor: primaryColor,
      foregroundColor: themeProvider.onPrimaryColor,
      elevation: 4,
      shape: const CircleBorder(),
      heroTag: "btn_create_action",
      child: const Icon(Icons.add, size: 28),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(
                      Icons.how_to_vote,
                      size: 28,
                      color: primaryColor,
                    ),
                    title: const Text(
                      "Hangout",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: const Text(
                      "Let the squad know what's happening.",
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HangoutEditorPage(),
                        ),
                      );
                    },
                  ),
                  Divider(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: Icon(
                      Symbols.earthquake,
                      size: 28,
                      color: primaryColor,
                    ),
                    title: const Text(
                      "Vibe Check",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: const Text(
                      "Give options and let the squad decide.",
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VibeCheckEditorPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
