// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Programmatically clears any stale service worker registrations and browser
/// caches, forces revalidation of the core entrypoints, and reloads the page.
Future<void> reloadWebPage() async {
  try {
    final sw = html.window.navigator.serviceWorker;
    if (sw != null) {
      final registrations = await sw.getRegistrations();
      for (final dynamic reg in registrations) {
        await reg.unregister();
      }
    }
  } catch (_) {
    // Ignore if serviceWorker API is restricted or unavailable
  }

  try {
    final caches = html.window.caches;
    if (caches != null) {
      final dynamic keys = await caches.keys();
      if (keys is Iterable) {
        for (final dynamic key in keys) {
          await caches.delete(key.toString());
        }
      }
    }
  } catch (_) {
    // Ignore if CacheStorage API is restricted or unavailable
  }

  try {
    await Future.wait([
      html.window.fetch('/flutter_bootstrap.js', {'cache': 'reload'}),
      html.window.fetch('/main.dart.js', {'cache': 'reload'}),
    ]).timeout(const Duration(seconds: 3));
  } catch (_) {
    // Proceed to reload even if pre-fetch times out
  }

  try {
    html.window.location.reload();
  } catch (_) {
    // Fallback if window.location access fails
  }
}
