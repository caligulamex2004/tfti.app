import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

import 'pwa_install_service_stub.dart' show PwaInstallSnapshot;

export 'pwa_install_service_stub.dart' show PwaInstallSnapshot;

js.JsObject? _getBridge() {
  final dynamic bridge = js.context['__tftiPwaInstall'];
  if (bridge is js.JsObject) {
    return bridge;
  }
  return null;
}

PwaInstallSnapshot readWebPwaInstallSnapshot() {
  try {
    final bridge = _getBridge();
    if (bridge == null) return const PwaInstallSnapshot();

    final dynamic stateObj = bridge.callMethod('getState');
    final bool canPrompt = bridge.callMethod('canNativePrompt') == true;
    if (stateObj is! js.JsObject) {
      return PwaInstallSnapshot(canNativePrompt: canPrompt);
    }

    return PwaInstallSnapshot(
      isStandalone: stateObj['isStandalone'] == true,
      isIos: stateObj['isIos'] == true,
      isIosSafari: stateObj['isIosSafari'] == true,
      isInAppBrowser: stateObj['isInAppBrowser'] == true,
      canNativePrompt: canPrompt,
    );
  } catch (_) {
    return const PwaInstallSnapshot();
  }
}

/// Invokes the browser's Web Install API (`navigator.install()`) or deferred
/// `beforeinstallprompt` synchronously on call so transient user activation is preserved.
Future<String> triggerWebNativeInstallPrompt() {
  final completer = Completer<String>();
  try {
    final bridge = _getBridge();
    if (bridge == null) {
      return Future.value('unavailable');
    }
    bridge.callMethod('promptInstall', [
      (dynamic outcome) {
        if (!completer.isCompleted) {
          completer.complete(outcome?.toString() ?? 'unavailable');
        }
      },
    ]);
  } catch (_) {
    if (!completer.isCompleted) {
      completer.complete('unavailable');
    }
  }
  return completer.future;
}

bool _listenerAttached = false;

void subscribeWebPwaInstallStateChanges(void Function() onChanged) {
  if (_listenerAttached) return;
  _listenerAttached = true;
  html.window.addEventListener('tfti-pwa-install-state', (_) => onChanged());
}
