// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

const String _baseTitle = 'thanks for the invite';

/// Updates both the document title (`(count) thanks for the invite`)
/// and the W3C App Badging API for installed PWAs (`navigator.setAppBadge`).
void setWebBadge(int count) {
  try {
    if (count > 0) {
      html.document.title = '($count) $_baseTitle';
    } else {
      html.document.title = _baseTitle;
    }
  } catch (_) {
    // Ignore if document access is restricted
  }

  try {
    final nav = js.context['navigator'];
    if (nav != null) {
      if (count > 0 && nav['setAppBadge'] != null) {
        nav.callMethod('setAppBadge', [count]);
      } else if (count <= 0 && nav['clearAppBadge'] != null) {
        nav.callMethod('clearAppBadge');
      }
    }
  } catch (_) {
    // Ignore if badging API is not supported or permitted
  }
}

void clearWebBadge() {
  setWebBadge(0);
}
