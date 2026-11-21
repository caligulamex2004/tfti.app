package com.bearmoose.tftiapp

import android.Manifest
import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.ContactsContract
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import java.util.Collections

class TftiFirebaseMessagingService : FlutterFirebaseMessagingService() {

    private data class CachedContact(
        val displayName: String?,
        val structuredFirst: String?,
        val structuredMiddle: String?,
        val structuredLast: String?,
        val hasStructured: Boolean,
        val cachedAtMs: Long,
    )

    private data class ChatBuffer(
        val lines: ArrayDeque<String> = ArrayDeque(),
        var totalCount: Int = 0,
    )

    companion object {
        const val EXTRA_NOTIF_PAYLOAD = "tfti_notif_payload"
        private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_MINI_FORMAT = "flutter.display_name_format_mini"
        private const val CHANNEL_HIGH = "high_importance_channel"
        private const val CHANNEL_CHAT = "chat_channel"

        private const val CONTACT_CACHE_TTL_MS = 5 * 60 * 1000L
        private const val CONTACT_CACHE_MAX_SIZE = 128
        private const val MAX_CHAT_INBOX_LINES = 5
        private const val MAX_TRACKED_CHAT_EVENTS = 32

        private val WHITESPACE_REGEX = Regex("\\s+")
        private val createdChannels: MutableSet<String> =
            Collections.synchronizedSet(HashSet())

        private val contactCacheLock = Any()
        private val contactCache = object : LinkedHashMap<String, CachedContact>(64, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, CachedContact>?): Boolean {
                return size > CONTACT_CACHE_MAX_SIZE
            }
        }

        private val chatBufferLock = Any()
        private val chatBuffers = object : LinkedHashMap<String, ChatBuffer>(16, 0.75f, true) {
            override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, ChatBuffer>?): Boolean {
                return size > MAX_TRACKED_CHAT_EVENTS
            }
        }

        fun clearChatBuffers() {
            synchronized(chatBufferLock) {
                chatBuffers.clear()
            }
        }
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // Cheap in-memory guards first to avoid ActivityManager IPC on non-matching messages.
        if (remoteMessage.notification != null) {
            return
        }

        val data = remoteMessage.data
        val type = data["type"] ?: return
        if (type != "rsvp_update" && type != "chat" && type != "chat_mention" && type != "whisper") {
            return
        }

        // Foreground delivery is handled by FlutterFirebaseMessagingReceiver -> InAppNotificationToastWrapper.
        if (isAppInForeground(applicationContext)) {
            return
        }

        val (title, body) = resolveTitleAndBody(data, type)
        if (title.isBlank() && body.isBlank()) {
            return
        }

        val channelId = data["channelId"]?.takeIf { it.isNotBlank() }
            ?: if (type == "chat_mention" || type == "rsvp_update") CHANNEL_HIGH else CHANNEL_CHAT

        showNotification(
            remoteMessage = remoteMessage,
            type = type,
            title = title,
            body = body,
            channelId = channelId,
            isHighPriority = channelId == CHANNEL_HIGH,
        )
    }

    private fun isAppInForeground(context: Context): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return false
        val appProcesses = activityManager.runningAppProcesses ?: return false
        val packageName = context.packageName
        for (processInfo in appProcesses) {
            if (processInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                processInfo.processName == packageName
            ) {
                return true
            }
        }
        return false
    }

    private fun resolveTitleAndBody(data: Map<String, String>, type: String): Pair<String, String> {
        val rawTitle = data["title"] ?: "TFTI Alert"
        val rawBody = data["body"] ?: ""

        val actorName = data["actorName"]?.trim().orEmpty()
        val actorPhone = data["actorPhone"]?.trim().orEmpty()
        if (actorName.isEmpty() && actorPhone.isEmpty()) {
            return rawTitle to rawBody
        }

        val format = loadMiniProfileFormat()
        val resolvedName = resolveContactFormattedName(actorPhone, format)
            ?: formatName(actorName, format)

        if (resolvedName.isBlank()) {
            return rawTitle to rawBody
        }

        val eventTitle = data["eventTitle"]?.trim().orEmpty()
        val isWhisper = data["isWhisper"] == "true" ||
            type == "whisper" ||
            !data["whisperRecipientId"].isNullOrBlank()

        return when {
            type == "rsvp_update" -> {
                val rsvpStatus = data["rsvpStatus"]
                val targetEvent = eventTitle.ifEmpty { "your hangout" }
                if (rsvpStatus == "going") {
                    "RSVP Update ✅" to "$resolvedName is going to $targetEvent"
                } else {
                    "RSVP Update" to "$resolvedName can't make it to $targetEvent"
                }
            }
            isWhisper -> {
                val targetTitle = eventTitle.ifEmpty { rawTitle.ifEmpty { "Event Chat" } }
                targetTitle to "🤫 $resolvedName sent you a whisper"
            }
            type == "chat_mention" -> {
                val targetEvent = eventTitle.ifEmpty { "Event Chat" }
                val messageText = data["messageText"] ?: rawBody
                "$resolvedName mentioned you in $targetEvent" to messageText
            }
            else -> {
                val targetTitle = eventTitle.ifEmpty { rawTitle.ifEmpty { "Event Chat" } }
                val messageText = data["messageText"].orEmpty()
                val bodyText = if (messageText.isNotEmpty()) "$resolvedName: $messageText" else rawBody
                targetTitle to bodyText
            }
        }
    }

    private fun loadMiniProfileFormat(): String {
        val prefs = getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(PREF_MINI_FORMAT, "firstName") ?: "firstName"
    }

    private fun resolveContactFormattedName(rawPhone: String, format: String): String? {
        if (rawPhone.isBlank()) return null
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) return null

        val needsStructured = format != "fullName"
        val nowMs = SystemClock.elapsedRealtime()

        val cached: CachedContact? = synchronized(contactCacheLock) {
            val entry = contactCache[rawPhone]
            if (entry != null && (nowMs - entry.cachedAtMs) < CONTACT_CACHE_TTL_MS) {
                entry
            } else {
                if (entry != null) contactCache.remove(rawPhone)
                null
            }
        }

        val resolvedEntry: CachedContact = if (cached != null && (!needsStructured || cached.hasStructured || cached.displayName == null)) {
            cached
        } else {
            queryContactFromProvider(rawPhone, needsStructured, nowMs)
        }

        val matchedDisplayName = resolvedEntry.displayName?.takeIf { it.isNotEmpty() } ?: return null
        if (format == "fullName") {
            return matchedDisplayName
        }

        val firstValid = isDistinctWordMatch(matchedDisplayName, resolvedEntry.structuredFirst)
        val validatedFirst = if (firstValid) extractFirstName(resolvedEntry.structuredFirst) else null
        val validatedMiddle = if (firstValid && format == "givenName") resolvedEntry.structuredMiddle else null
        val validatedLast = if (format == "firstNameLastInitial" &&
            isDistinctWordMatch(matchedDisplayName, resolvedEntry.structuredLast)
        ) {
            resolvedEntry.structuredLast
        } else {
            null
        }

        return formatName(
            fullName = matchedDisplayName,
            format = format,
            structuredFirst = validatedFirst,
            structuredMiddle = validatedMiddle,
            structuredLast = validatedLast,
        ).takeIf { it.isNotBlank() }
    }

    private fun queryContactFromProvider(
        rawPhone: String,
        needsStructured: Boolean,
        nowMs: Long,
    ): CachedContact {
        val lookupUri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(rawPhone),
        )
        val projection = if (needsStructured) {
            arrayOf(
                ContactsContract.PhoneLookup.CONTACT_ID,
                ContactsContract.PhoneLookup.DISPLAY_NAME,
            )
        } else {
            arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)
        }

        var contactId: Long? = null
        var displayName: String? = null
        try {
            contentResolver.query(lookupUri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    if (needsStructured) {
                        val idIdx = cursor.getColumnIndex(ContactsContract.PhoneLookup.CONTACT_ID)
                        if (idIdx >= 0) contactId = cursor.getLong(idIdx)
                    }
                    val nameIdx = cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME)
                    if (nameIdx >= 0) displayName = cursor.getString(nameIdx)?.trim()
                }
            }
        } catch (_: Exception) {
            return CachedContact(null, null, null, null, hasStructured = false, cachedAtMs = nowMs)
        }

        val matchedDisplayName = displayName?.takeIf { it.isNotEmpty() }
        if (matchedDisplayName == null) {
            val miss = CachedContact(null, null, null, null, hasStructured = true, cachedAtMs = nowMs)
            synchronized(contactCacheLock) { contactCache[rawPhone] = miss }
            return miss
        }

        var structuredFirst: String? = null
        var structuredMiddle: String? = null
        var structuredLast: String? = null

        if (needsStructured && contactId != null) {
            try {
                val dataProjection = arrayOf(
                    ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME,
                    ContactsContract.CommonDataKinds.StructuredName.MIDDLE_NAME,
                    ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME,
                )
                val selection =
                    "${ContactsContract.Data.CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?"
                val selectionArgs = arrayOf(
                    contactId.toString(),
                    ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE,
                )
                contentResolver.query(
                    ContactsContract.Data.CONTENT_URI,
                    dataProjection,
                    selection,
                    selectionArgs,
                    null,
                )?.use { dataCursor ->
                    if (dataCursor.moveToFirst()) {
                        structuredFirst = dataCursor.getString(0)?.trim()
                        structuredMiddle = dataCursor.getString(1)?.trim()
                        structuredLast = dataCursor.getString(2)?.trim()
                    }
                }
            } catch (_: Exception) {
                // Fall back to displayName parsing
            }
        }

        val entry = CachedContact(
            displayName = matchedDisplayName,
            structuredFirst = structuredFirst,
            structuredMiddle = structuredMiddle,
            structuredLast = structuredLast,
            hasStructured = needsStructured,
            cachedAtMs = nowMs,
        )
        synchronized(contactCacheLock) { contactCache[rawPhone] = entry }
        return entry
    }

    private fun isDistinctWordMatch(displayName: String, candidate: String?): Boolean {
        val clean = candidate?.trim().orEmpty()
        if (clean.isEmpty()) return false
        val regex = Regex("\\b" + Regex.escape(clean) + "\\b", RegexOption.IGNORE_CASE)
        return regex.containsMatchIn(displayName)
    }

    private fun formatName(
        fullName: String?,
        format: String,
        structuredFirst: String? = null,
        structuredMiddle: String? = null,
        structuredLast: String? = null,
    ): String {
        val trimmed = fullName?.trim().orEmpty()
        if (trimmed.isEmpty()) return ""

        return when (format) {
            "fullName" -> trimmed
            "firstNameLastInitial" -> extractFirstNameLastInitial(trimmed, structuredFirst, structuredLast)
            "givenName" -> extractGivenName(trimmed, structuredFirst, structuredMiddle)
            else -> {
                if (!structuredFirst.isNullOrBlank()) {
                    extractFirstName(structuredFirst)
                } else {
                    extractFirstName(trimmed)
                }
            }
        }
    }

    private fun extractFirstName(fullName: String?): String {
        val trimmed = fullName?.trim().orEmpty()
        if (trimmed.isEmpty()) return ""

        if (trimmed.contains(",")) {
            val commaParts = trimmed.split(",")
            if (commaParts.size > 1) {
                val afterComma = commaParts[1].trim()
                if (afterComma.isNotEmpty()) {
                    val wordsAfter = afterComma.split(WHITESPACE_REGEX)
                    if (wordsAfter.isNotEmpty() && wordsAfter[0].isNotEmpty()) {
                        return wordsAfter[0]
                    }
                }
            }
            return commaParts[0].trim()
        }

        return trimmed.split(WHITESPACE_REGEX).firstOrNull().orEmpty()
    }

    private fun extractFirstNameLastInitial(
        fullName: String,
        firstName: String?,
        lastName: String?,
    ): String {
        val first = if (!firstName.isNullOrBlank()) {
            extractFirstName(firstName)
        } else {
            extractFirstName(fullName)
        }
        if (first.isEmpty()) return ""

        val lastWord: String? = when {
            !lastName.isNullOrBlank() -> lastName.trim().split(WHITESPACE_REGEX).lastOrNull()
            fullName.contains(",") -> {
                val commaParts = fullName.split(",")
                if (commaParts.size > 1 && commaParts[1].trim().isNotEmpty() && commaParts[0].trim().isNotEmpty()) {
                    commaParts[0].trim().split(WHITESPACE_REGEX).lastOrNull()
                } else {
                    null
                }
            }
            else -> {
                val parts = fullName.split(WHITESPACE_REGEX)
                if (parts.size >= 2) parts.last() else null
            }
        }

        return if (!lastWord.isNullOrEmpty()) {
            "$first ${lastWord[0].uppercaseChar()}."
        } else {
            first
        }
    }

    private fun extractGivenName(
        fullName: String,
        structuredFirst: String?,
        structuredMiddle: String?,
    ): String {
        val sFirst = structuredFirst?.trim().orEmpty()
        val sMiddle = structuredMiddle?.trim().orEmpty()
        if (sFirst.isNotEmpty()) {
            val combined = if (sMiddle.isNotEmpty() && !sFirst.lowercase().endsWith(sMiddle.lowercase())) {
                "$sFirst $sMiddle"
            } else {
                sFirst
            }
            val normalizedCombined = combined.split(WHITESPACE_REGEX).joinToString(" ")
            if (normalizedCombined.contains(" ")) {
                val pattern = Regex("\\b" + Regex.escape(normalizedCombined) + "\\b", RegexOption.IGNORE_CASE)
                if (pattern.containsMatchIn(fullName)) {
                    return normalizedCombined
                }
            }
        }

        if (fullName.contains(",")) {
            val commaParts = fullName.split(",")
            if (commaParts.size > 1) {
                val afterComma = commaParts[1].trim()
                if (afterComma.isNotEmpty()) {
                    return afterComma.split(WHITESPACE_REGEX).joinToString(" ")
                }
            }
            return commaParts[0].trim()
        }

        val parts = fullName.split(WHITESPACE_REGEX)
        return if (parts.size >= 3) {
            parts.subList(0, parts.size - 1).joinToString(" ")
        } else {
            parts.firstOrNull().orEmpty()
        }
    }

    private fun showNotification(
        remoteMessage: RemoteMessage,
        type: String,
        title: String,
        body: String,
        channelId: String,
        isHighPriority: Boolean,
    ) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && createdChannels.add(channelId)) {
            val channelName = if (channelId == CHANNEL_HIGH) "Important Alerts" else "Chat Messages"
            val importance = if (isHighPriority) {
                NotificationManager.IMPORTANCE_HIGH
            } else {
                NotificationManager.IMPORTANCE_DEFAULT
            }
            val channel = NotificationChannel(channelId, channelName, importance)
            manager.createNotificationChannel(channel)
        }

        val payloadBundle = Bundle().apply {
            for ((k, v) in remoteMessage.data) {
                putString(k, v)
            }
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_NOTIF_PAYLOAD, payloadBundle)
        }

        val eventId = remoteMessage.data["eventId"]?.trim().orEmpty()
        val isChatType = (type == "chat" || type == "chat_mention" || type == "whisper") && eventId.isNotEmpty()

        val notificationId: Int
        val displayTitle: String
        val style: NotificationCompat.Style
        var messageCount = 1

        if (isChatType) {
            notificationId = "tfti_chat:$eventId".hashCode()
            val eventTitle = remoteMessage.data["eventTitle"]?.trim().orEmpty()
            val inboxLine = if (type == "chat_mention") "$title — $body" else body

            val snapshotLines: List<String>
            synchronized(chatBufferLock) {
                val buffer = chatBuffers.getOrPut(eventId) { ChatBuffer() }
                buffer.totalCount += 1
                messageCount = buffer.totalCount
                if (inboxLine.isNotBlank()) {
                    buffer.lines.addLast(inboxLine)
                    while (buffer.lines.size > MAX_CHAT_INBOX_LINES) {
                        buffer.lines.removeFirst()
                    }
                }
                snapshotLines = buffer.lines.toList()
            }

            if (messageCount > 1 && snapshotLines.size > 1) {
                displayTitle = eventTitle.ifEmpty { title }
                val inboxStyle = NotificationCompat.InboxStyle()
                    .setBigContentTitle(displayTitle)
                    .setSummaryText("$messageCount new messages")
                for (line in snapshotLines) {
                    inboxStyle.addLine(line)
                }
                style = inboxStyle
            } else {
                displayTitle = title
                style = NotificationCompat.BigTextStyle().bigText(body)
            }
        } else {
            val notifKey = remoteMessage.messageId
                ?: "$eventId:$type:${System.currentTimeMillis()}"
            notificationId = notifKey.hashCode()
            displayTitle = title
            style = NotificationCompat.BigTextStyle().bigText(body)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val smallIconRes = applicationInfo.icon.takeIf { it != 0 } ?: R.mipmap.launcher_icon

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(smallIconRes)
            .setContentTitle(displayTitle)
            .setContentText(body)
            .setStyle(style)
            .setNumber(messageCount)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(
                if (isHighPriority) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT,
            )

        if (isChatType) {
            builder.setGroup("tfti_chat_$eventId")
        }

        manager.notify(notificationId, builder.build())
    }
}
