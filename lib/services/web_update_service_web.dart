// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Programmatically reloads the current browser page to pull and activate
/// the latest web bundle and service worker assets.
void reloadWebPage() {
  try {
    html.window.location.reload();
  } catch (e) {
    // Fallback if window.location access fails
  }
}
