import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_version.dart';
import 'web_update_service_stub.dart'
    if (dart.library.html) 'web_update_service_web.dart';

/// Service responsible for polling `/version.json` on Flutter Web
/// and notifying listeners when a newer release build has been deployed.
class WebUpdateService {
  static final WebUpdateService instance = WebUpdateService._();
  WebUpdateService._();

  /// ValueNotifier indicating whether a newer build is available on the server.
  final ValueNotifier<bool> updateAvailable = ValueNotifier<bool>(false);

  Timer? _pollingTimer;
  bool _isChecking = false;

  /// Starts polling for updates if running on Flutter Web.
  void start() {
    if (!kIsWeb) return;

    // Initial check on boot
    checkForUpdate();

    // Re-check periodically every 15 minutes
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      checkForUpdate();
    });
  }

  /// Cancels polling.
  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Manually triggers a check against `/version.json` with a cache-busting timestamp.
  Future<void> checkForUpdate() async {
    if (!kIsWeb || _isChecking) return;
    _isChecking = true;

    try {
      final uri = Uri.parse('/version.json?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final rawBuild = data['build_number'];
          final int serverBuild = rawBuild is int
              ? rawBuild
              : int.tryParse(rawBuild?.toString() ?? '0') ?? 0;

          if (serverBuild > AppVersion.buildNumber) {
            debugPrint(
              '🚀 [WebUpdate] Update available: local build=${AppVersion.buildNumber}, server build=$serverBuild',
            );
            updateAvailable.value = true;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [WebUpdate] Version check bypassed: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Reloads the web page to activate the new bundle.
  Future<void> triggerReload() async {
    updateAvailable.value = false;
    await reloadWebPage();
  }

  /// Dismisses the update banner for the current session.
  void dismiss() {
    updateAvailable.value = false;
  }
}
