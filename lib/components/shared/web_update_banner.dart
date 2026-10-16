import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/web_update_service.dart';

/// Wraps any widget tree on Flutter Web and displays a sleek, top-anchored banner
/// whenever a new release build is detected by [WebUpdateService].
class WebUpdateBannerWrapper extends StatelessWidget {
  final Widget child;

  /// Overrides [kIsWeb] in widget tests so the banner UI can be tested on the Dart VM.
  @visibleForTesting
  final bool? debugForceWeb;

  const WebUpdateBannerWrapper({
    super.key,
    required this.child,
    @visibleForTesting this.debugForceWeb,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = debugForceWeb ?? kIsWeb;
    if (!isWeb) return child;

    return Directionality(
      // Ensure Directionality is available if wrapped at MaterialApp.builder
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          ValueListenableBuilder<bool>(
            valueListenable: WebUpdateService.instance.updateAvailable,
            builder: (context, hasUpdate, _) {
              if (!hasUpdate) return const SizedBox.shrink();

              return SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.rocket_launch_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Update Available',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  Text(
                                    'A new version of tfti is ready.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () => WebUpdateService.instance.triggerReload(),
                              child: const Text(
                                'Update Now',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Do NOT set `tooltip` here because WebUpdateBannerWrapper
                            // sits at MaterialApp.builder (above Navigator/Overlay),
                            // where Tooltip would throw "No Overlay widget found" on hover.
                            Semantics(
                              button: true,
                              label: 'Dismiss update banner',
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                splashRadius: 16,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                onPressed: () => WebUpdateService.instance.dismiss(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
