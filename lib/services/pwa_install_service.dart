import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pwa_install_service_stub.dart'
    if (dart.library.html) 'pwa_install_service_web.dart';

export 'pwa_install_service_stub.dart' show PwaInstallSnapshot;

/// Effective install UX affordance available in the current browser session.
enum PwaInstallMode {
  none,
  nativePrompt,
  iosSafariGuide,
  iosOtherBrowserGuide,
}

/// Outcome returned from triggering the native browser install prompt.
enum PwaNativeInstallResult {
  accepted,
  dismissed,
  alreadyInstalled,
  unavailable,
}

/// Tracks Web/PWA installation eligibility, standalone status, and iOS
/// "Add to Home Screen" guidance visibility across the feed and account pages.
class PwaInstallService extends ChangeNotifier {
  static final PwaInstallService instance = PwaInstallService._();
  PwaInstallService._();

  static const String dismissedPrefKey = 'web_pwa_install_banner_dismissed_v1';

  bool _initialized = false;
  bool _bannerDismissed = false;
  PwaInstallSnapshot _snapshot = const PwaInstallSnapshot();

  PwaInstallSnapshot get snapshot => _snapshot;
  bool get isBannerDismissed => _bannerDismissed;

  /// Resolves the appropriate install UI mode for the current environment.
  PwaInstallMode resolveMode({
    bool? isWebOverride,
    PwaInstallSnapshot? snapshotOverride,
  }) {
    final runningOnWeb = isWebOverride ?? kIsWeb;
    if (!runningOnWeb) return PwaInstallMode.none;

    final snap = snapshotOverride ?? _snapshot;
    if (snap.isStandalone) return PwaInstallMode.none;
    if (snap.canNativePrompt) return PwaInstallMode.nativePrompt;
    if (snap.isIos) {
      return snap.isIosSafari
          ? PwaInstallMode.iosSafariGuide
          : PwaInstallMode.iosOtherBrowserGuide;
    }
    return PwaInstallMode.none;
  }

  PwaInstallMode get mode => resolveMode();

  bool get shouldShowFeedBanner =>
      !_bannerDismissed && mode != PwaInstallMode.none;

  bool get canShowInSettings => mode != PwaInstallMode.none;

  /// Initializes state listeners and loads banner dismissal persistence.
  Future<void> init({
    bool? isWebOverride,
    PwaInstallSnapshot? snapshotOverride,
  }) async {
    final runningOnWeb = isWebOverride ?? kIsWeb;
    if (!runningOnWeb || _initialized) return;

    _initialized = true;
    if (snapshotOverride == null) {
      subscribeWebPwaInstallStateChanges(_refreshFromWeb);
    }

    _snapshot = snapshotOverride ?? readWebPwaInstallSnapshot();

    try {
      final prefs = await SharedPreferences.getInstance();
      _bannerDismissed = prefs.getBool(dismissedPrefKey) ?? false;
    } catch (_) {
      _bannerDismissed = false;
    }
    notifyListeners();
  }

  void _refreshFromWeb() {
    _snapshot = readWebPwaInstallSnapshot();
    notifyListeners();
  }

  /// Persists dismissal of the home-feed install banner.
  Future<void> dismissFeedBanner() async {
    _bannerDismissed = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(dismissedPrefKey, true);
    } catch (_) {}
  }

  /// Triggers the browser-native install dialog (`navigator.install()` or
  /// captured `beforeinstallprompt`). Must be invoked synchronously inside a
  /// button tap handler before awaiting other futures.
  Future<PwaNativeInstallResult> promptNativeInstall() async {
    final raw = await triggerWebNativeInstallPrompt();
    _refreshFromWeb();
    switch (raw) {
      case 'accepted':
        return PwaNativeInstallResult.accepted;
      case 'dismissed':
        return PwaNativeInstallResult.dismissed;
      case 'already_installed':
        return PwaNativeInstallResult.alreadyInstalled;
      default:
        return PwaNativeInstallResult.unavailable;
    }
  }

  @visibleForTesting
  void setTestState({
    PwaInstallSnapshot? snapshot,
    bool? bannerDismissed,
  }) {
    _initialized = true;
    if (snapshot != null) _snapshot = snapshot;
    if (bannerDismissed != null) _bannerDismissed = bannerDismissed;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    _bannerDismissed = false;
    _snapshot = const PwaInstallSnapshot();
    notifyListeners();
  }
}
