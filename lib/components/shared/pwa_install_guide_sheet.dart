import 'package:flutter/material.dart';

import '../../services/app_toast.dart';
import '../../services/pwa_install_service.dart';

/// Visual, step-by-step bottom sheet guiding iOS/iPadOS users through adding
/// the TFTI web app to their Home Screen.
class PwaInstallGuideSheet extends StatelessWidget {
  final PwaInstallMode mode;
  final bool isInAppBrowser;

  const PwaInstallGuideSheet({
    super.key,
    required this.mode,
    this.isInAppBrowser = false,
  });

  static Future<void> show(
    BuildContext context, {
    required PwaInstallMode mode,
    bool isInAppBrowser = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => PwaInstallGuideSheet(
        mode: mode,
        isInAppBrowser: isInAppBrowser,
      ),
    );
  }

  /// Triggers the browser-native install prompt for [PwaInstallMode.nativePrompt]
  /// synchronously from a tap handler, or opens the step-by-step iOS guide sheet.
  static void triggerOrShow(BuildContext context, PwaInstallMode mode) {
    final service = PwaInstallService.instance;
    if (mode == PwaInstallMode.nativePrompt) {
      // Call synchronously inside tap handler to preserve browser user activation.
      service.promptNativeInstall().then((result) {
        if (!context.mounted) return;
        if (result == PwaNativeInstallResult.accepted) {
          service.dismissFeedBanner();
          AppToast.success(
            'TFTI added! Launch anytime from your Home Screen or Dock.',
          );
        } else if (result == PwaNativeInstallResult.unavailable) {
          AppToast.info(
            'Use your browser\'s Install or Share menu to add TFTI.',
          );
        }
      });
      return;
    }

    show(
      context,
      mode: mode,
      isInAppBrowser: service.snapshot.isInAppBrowser,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bool needsBrowserSwitch = mode == PwaInstallMode.iosOtherBrowserGuide;

    final List<_InstallStep> steps = needsBrowserSwitch
        ? [
            _InstallStep(
              stepNumber: 1,
              icon: isInAppBrowser ? Icons.open_in_browser : Icons.ios_share,
              title: isInAppBrowser
                  ? 'Open in Safari first'
                  : 'Tap the Share button or open in Safari',
              subtitle: isInAppBrowser
                  ? 'In-app browsers hide Add to Home Screen. Tap the Safari compass or Share menu to open tfti.app in Safari.'
                  : 'Tap the Share icon in your browser bar (or switch to Safari for full support).',
            ),
            const _InstallStep(
              stepNumber: 2,
              icon: Icons.add_box_outlined,
              title: 'Select "Add to Home Screen"',
              subtitle:
                  'Scroll down the Share sheet and tap Add to Home Screen.',
            ),
            const _InstallStep(
              stepNumber: 3,
              icon: Icons.check_circle_outline_rounded,
              title: 'Tap "Add" & launch TFTI',
              subtitle:
                  'Opens full-screen with push notifications and long-press shortcuts.',
            ),
          ]
        : const [
            _InstallStep(
              stepNumber: 1,
              icon: Icons.ios_share,
              title: 'Tap the Share button in Safari',
              subtitle:
                  'Look for the square-with-arrow icon in Safari\'s bottom bar (or top bar on iPad).',
            ),
            _InstallStep(
              stepNumber: 2,
              icon: Icons.add_box_outlined,
              title: 'Scroll down & tap "Add to Home Screen"',
              subtitle:
                  'You may need to scroll slightly past AirDrop and Copy.',
            ),
            _InstallStep(
              stepNumber: 3,
              icon: Icons.check_circle_outline_rounded,
              title: 'Tap "Add" in the top right',
              subtitle:
                  'TFTI gets its own Home Screen icon with full-screen mode, push alerts, and long-press shortcuts.',
            ),
          ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.install_mobile_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add TFTI to Home Screen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Unlock full-screen view, push alerts & quick shortcuts.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < steps.length; i++) ...[
                    _InstallStepTile(
                      step: steps[i],
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    if (i < steps.length - 1)
                      Divider(
                        height: 18,
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallStep {
  final int stepNumber;
  final IconData icon;
  final String title;
  final String subtitle;

  const _InstallStep({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _InstallStepTile extends StatelessWidget {
  final _InstallStep step;
  final Color primaryColor;
  final bool isDark;

  const _InstallStepTile({
    required this.step,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(step.icon, size: 18, color: primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${step.stepNumber}. ${step.title}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                step.subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
