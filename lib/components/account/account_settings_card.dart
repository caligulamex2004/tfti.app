import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/app_toast.dart';
import '../../services/pwa_install_service.dart';
import '../shared/pwa_install_guide_sheet.dart';

class AccountSettingsCard extends StatelessWidget {
  final VoidCallback onPreferencesTap;
  final VoidCallback onTipJarTap;
  final bool? isWebOverride;

  const AccountSettingsCard({
    super.key,
    required this.onPreferencesTap,
    required this.onTipJarTap,
    this.isWebOverride,
  });

  Future<void> _launchLegalUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      AppToast.error("Could not open legal link.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool runningOnWeb = isWebOverride ?? kIsWeb;

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
            if (runningOnWeb)
              ListenableBuilder(
                listenable: PwaInstallService.instance,
                builder: (context, _) {
                  final mode = PwaInstallService.instance.resolveMode(
                    isWebOverride: runningOnWeb,
                  );
                  if (mode == PwaInstallMode.none) {
                    return const SizedBox.shrink();
                  }
                  final bool isIos = mode == PwaInstallMode.iosSafariGuide ||
                      mode == PwaInstallMode.iosOtherBrowserGuide;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIos
                                ? Icons.ios_share
                                : Icons.install_mobile_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          isIos ? 'Add to Home Screen' : 'Install TFTI App',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isIos
                              ? 'Step-by-step iPhone / iPad setup'
                              : 'Add to Home Screen or Dock',
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () =>
                            PwaInstallGuideSheet.triggerOrShow(context, mode),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
