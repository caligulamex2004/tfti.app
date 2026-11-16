import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/pwa_install_service.dart';
import '../shared/pwa_install_guide_sheet.dart';

/// Compact Home Feed banner encouraging Web users to install TFTI to their
/// Home Screen / Dock (via native browser prompt or an iOS walkthrough).
class WebPwaInstallBanner extends StatefulWidget {
  final bool? isWebOverride;

  const WebPwaInstallBanner({super.key, this.isWebOverride});

  @override
  State<WebPwaInstallBanner> createState() => _WebPwaInstallBannerState();
}

class _WebPwaInstallBannerState extends State<WebPwaInstallBanner> {
  @override
  void initState() {
    super.initState();
    PwaInstallService.instance.init(isWebOverride: widget.isWebOverride);
  }

  void _onInstallTap(PwaInstallMode mode) {
    PwaInstallGuideSheet.triggerOrShow(context, mode);
  }

  @override
  Widget build(BuildContext context) {
    final bool runningOnWeb = widget.isWebOverride ?? kIsWeb;
    if (!runningOnWeb) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: PwaInstallService.instance,
      builder: (context, _) {
        final service = PwaInstallService.instance;
        final mode = service.resolveMode(isWebOverride: runningOnWeb);
        if (service.isBannerDismissed || mode == PwaInstallMode.none) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;
        final bool isIos = mode == PwaInstallMode.iosSafariGuide ||
            mode == PwaInstallMode.iosOtherBrowserGuide;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIos ? Icons.ios_share : Icons.install_mobile_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Get the TFTI App Icon',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isIos
                            ? 'Add to your iPhone Home Screen for full-screen & quick shortcuts.'
                            : 'Install TFTI on your Home Screen or Dock for instant access.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _onInstallTap(mode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    isIos ? 'How To' : 'Install',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.grey,
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => service.dismissFeedBanner(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
