/// Current web PWA installation capability snapshot.
class PwaInstallSnapshot {
  final bool isStandalone;
  final bool isIos;
  final bool isIosSafari;
  final bool isInAppBrowser;
  final bool canNativePrompt;

  const PwaInstallSnapshot({
    this.isStandalone = false,
    this.isIos = false,
    this.isIosSafari = false,
    this.isInAppBrowser = false,
    this.canNativePrompt = false,
  });
}

PwaInstallSnapshot readWebPwaInstallSnapshot() => const PwaInstallSnapshot();

Future<String> triggerWebNativeInstallPrompt() async => 'unavailable';

void subscribeWebPwaInstallStateChanges(void Function() onChanged) {}
