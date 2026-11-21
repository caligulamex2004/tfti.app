package com.bearmoose.tftiapp

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bearmoose.tftiapp/notifications"
    private val TAP_CHANNEL = "com.bearmoose.tftiapp/notification_taps"
    private var tapMethodChannel: MethodChannel? = null
    private var pendingNotificationTap: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "cancelAllNotifications") {
                cancelAllNotifications()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        tapMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TAP_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialNotificationTap") {
                    result.success(pendingNotificationTap)
                    pendingNotificationTap = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingNotificationTap = extractNotifPayload(intent)
        if (intent?.extras != null) {
            cancelAllNotifications()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractNotifPayload(intent)
        if (payload != null) {
            if (tapMethodChannel != null) {
                tapMethodChannel?.invokeMethod("onNotificationTap", payload)
            } else {
                pendingNotificationTap = payload
            }
        }
        cancelAllNotifications()
    }

    private fun extractNotifPayload(intent: Intent?): Map<String, String>? {
        val bundle = intent?.getBundleExtra(TftiFirebaseMessagingService.EXTRA_NOTIF_PAYLOAD)
            ?: return null
        val map = HashMap<String, String>()
        for (key in bundle.keySet()) {
            val value = bundle.getString(key)
            if (value != null) {
                map[key] = value
            }
        }
        return if (map.isEmpty()) null else map
    }

    private fun cancelAllNotifications() {
        TftiFirebaseMessagingService.clearChatBuffers()
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancelAll()
        } catch (_: Exception) {}
    }
}
