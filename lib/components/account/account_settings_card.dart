import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountSettingsCard extends StatelessWidget {
  final VoidCallback onPreferencesTap;
  final VoidCallback onTipJarTap;

  const AccountSettingsCard({
    super.key,
    required this.onPreferencesTap,
    required this.onTipJarTap,
  });

  Future<void> _launchLegalUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open legal link.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.settings),
              ),
              title: const Text(
                "Preferences",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Notifications & Appearance"),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: onPreferencesTap,
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              indent: 60,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Colors.blue,
                ),
              ),
              title: const Text(
                "Terms of Service",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () =>
                  _launchLegalUrl(context, "https://tfti-app.web.app/terms"),
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              indent: 60,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.teal,
                ),
              ),
              title: const Text(
                "Privacy Policy",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () =>
                  _launchLegalUrl(context, "https://tfti-app.web.app/privacy"),
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              indent: 60,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.coffee, color: Colors.amber),
              ),
              title: const Text(
                "Support the Developer",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("Help keep the servers running"),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: onTipJarTap,
            ),
          ],
        ),
      ),
    );
  }
}
