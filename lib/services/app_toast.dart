import 'dart:async';
import 'package:flutter/foundation.dart';

/// Semantic categories for unified in-app toast banners.
enum AppToastType {
  success,
  error,
  warning,
  info,
}

/// Payload representing a local UI toast banner rendered by
/// [InAppNotificationToastWrapper].
class AppToastMessage {
  final String id;
  final String message;
  final String? title;
  final AppToastType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppToastMessage({
    required this.id,
    required this.message,
    this.title,
    this.type = AppToastType.info,
    this.duration = const Duration(seconds: 3),
    this.actionLabel,
    this.onAction,
  });
}

/// Centralized, context-free toast service replacing legacy [SnackBar]s
/// with the app's unified top-anchored floating toast banner.
class AppToast {
  AppToast._();

  static int _counter = 0;
  static final StreamController<AppToastMessage> _controller =
      StreamController<AppToastMessage>.broadcast();

  /// Broadcast stream consumed by [InAppNotificationToastWrapper].
  static Stream<AppToastMessage> get onToast => _controller.stream;

  /// Displays a floating top toast banner with the given [message] and [type].
  static void show(
    String message, {
    String? title,
    AppToastType type = AppToastType.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final resolvedDuration = duration ??
        switch (type) {
          AppToastType.error || AppToastType.warning => const Duration(seconds: 4),
          AppToastType.success || AppToastType.info => const Duration(seconds: 3),
        };

    _counter++;
    _controller.add(
      AppToastMessage(
        id: 'toast_$_counter',
        message: message,
        title: title,
        type: type,
        duration: resolvedDuration,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  /// Displays a green confirmation toast.
  static void success(
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      message,
      title: title,
      type: AppToastType.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Displays a red error toast.
  static void error(
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      message,
      title: title,
      type: AppToastType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Displays an amber warning toast.
  static void warning(
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      message,
      title: title,
      type: AppToastType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Displays a neutral/primary informational toast.
  static void info(
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      message,
      title: title,
      type: AppToastType.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
