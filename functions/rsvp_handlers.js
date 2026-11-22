const RSVP_COOLDOWN_MS = 60 * 1000;
const MAX_NOTIF_TITLE_CHARS = 120;
const MAX_NOTIF_BODY_CHARS = 280;
const GET_ALL_CHUNK_SIZE = 100;

/**
 * Clips a string to `maxChars` characters, appending an ellipsis when truncated.
 * Prevents large chat messages from pushing FCM payloads past the 4 KB limit.
 * @param {*} value
 * @param {number} maxChars
 * @return {string}
 */
function clipText(value, maxChars = MAX_NOTIF_BODY_CHARS) {
    if (value === null || value === undefined) return "";
    const str = String(value);
    if (str.length <= maxChars) return str;
    return `${str.slice(0, Math.max(0, maxChars - 1))}…`;
}

/**
 * Fetches multiple Firestore DocumentReferences in minimal RPC round-trips.
 * Uses `db.getAll(...)` (chunked at 100 refs) when available in Admin SDK,
 * falling back to `Promise.all(refs.map(r => r.get()))` for lightweight mocks.
 * @param {object} db
 * @param {Array<object>} refs
 * @return {Promise<Array<object>>}
 */
async function fetchDocsByRefs(db, refs) {
    if (!Array.isArray(refs) || refs.length === 0) return [];
    if (typeof db.getAll === "function") {
        const results = [];
        for (let i = 0; i < refs.length; i += GET_ALL_CHUNK_SIZE) {
            const chunk = refs.slice(i, i + GET_ALL_CHUNK_SIZE);
            const docs = await db.getAll(...chunk);
            results.push(...docs);
        }
        return results;
    }
    return Promise.all(refs.map((ref) => ref.get()));
}

/**
 * Converts a Firestore Timestamp, Date, or numeric millis value into epoch milliseconds.
 * Returns null if the value is missing or invalid.
 * @param {*} value
 * @return {number|null}
 */
function timestampToMillis(value) {
    if (value === null || value === undefined) return null;
    if (typeof value.toMillis === "function") {
        return value.toMillis();
    }
    if (value instanceof Date) {
        return value.getTime();
    }
    if (typeof value.toDate === "function") {
        return value.toDate().getTime();
    }
    if (typeof value === "number" && Number.isFinite(value)) {
        return value;
    }
    if (typeof value._seconds === "number") {
        const nanos = typeof value._nanoseconds === "number" ? value._nanoseconds : 0;
        return (value._seconds * 1000) + Math.floor(nanos / 1e6);
    }
    return null;
}

/**
 * Releases any Squad Needs roles claimed by `userId` on `eventId` when their
 * status is no longer `'going'`.
 *
 * @param {object} params
 * @param {object} params.db
 * @param {object} params.FieldValue
 * @param {string} params.eventId
 * @param {string} params.userId
 * @param {object} [params.logger]
 * @return {Promise<number>} Number of roles released
 */
async function releaseClaimedRolesForUser({db, FieldValue, eventId, userId, logger}) {
    const rolesSnap = await db
        .collection("events")
        .doc(eventId)
        .collection("roles")
        .where("claimedByUid", "==", userId)
        .get();

    if (!rolesSnap || rolesSnap.empty) {
        return 0;
    }

    const batch = db.batch();
    for (const roleDoc of rolesSnap.docs) {
        batch.update(roleDoc.ref, {
            claimedByUid: FieldValue.delete(),
            claimedByName: FieldValue.delete(),
            claimedAt: FieldValue.delete(),
        });
    }
    await batch.commit();

    if (logger) {
        logger.log(`Auto-released ${rolesSnap.size} Squad Need(s) for user ${userId} on event ${eventId}.`);
    }
    return rolesSnap.size;
}

/**
 * Extracts a user's phone number from their Firestore profile document.
 * @param {object|null|undefined} userData
 * @return {string}
 */
function extractUserPhone(userData) {
    if (!userData || typeof userData !== "object") return "";
    const raw = userData.phoneNumber || userData.phone || "";
    return typeof raw === "string" ? raw.trim() : "";
}

/**
 * Builds an FCM multicast payload whose Android delivery uses a data-only block
 * (so `TftiFirebaseMessagingService` can resolve on-device contact names in
 * background/killed state), while preserving APNs and WebPush alert payloads.
 *
 * @param {object} params
 * @return {object}
 */
function buildPersonNotificationPayload({
    type,
    eventId,
    eventTitle,
    title,
    body,
    actorUid,
    actorName,
    actorPhone,
    channelId = "high_importance_channel",
    androidPriority = "high",
    extraData = {},
    createWebPushConfig,
}) {
    const clippedTitle = clipText(title, MAX_NOTIF_TITLE_CHARS);
    const clippedBody = clipText(body, MAX_NOTIF_BODY_CHARS);
    const clippedEventTitle = clipText(eventTitle || "", MAX_NOTIF_TITLE_CHARS);

    const stringifiedExtra = {};
    for (const [key, val] of Object.entries(extraData)) {
        if (val !== undefined && val !== null) {
            const strVal = typeof val === "string" ? val : String(val);
            stringifiedExtra[key] = key === "messageText"
                ? clipText(strVal, MAX_NOTIF_BODY_CHARS)
                : strVal;
        }
    }

    return {
        data: {
            type: String(type),
            eventId: String(eventId),
            eventTitle: clippedEventTitle,
            actorUid: String(actorUid || ""),
            actorName: clipText(actorName || "Someone", 80),
            actorPhone: String(actorPhone || ""),
            title: clippedTitle,
            body: clippedBody,
            channelId: String(channelId),
            ...stringifiedExtra,
        },
        android: {
            priority: androidPriority,
        },
        apns: {
            payload: {
                aps: {
                    alert: {
                        title: clippedTitle,
                        body: clippedBody,
                    },
                    badge: 1,
                    sound: "default",
                },
            },
        },
        webpush: createWebPushConfig(clippedTitle, clippedBody, eventId, type),
    };
}

/**
 * Handles invitation document updates (and optional direct RSVP creates):
 * 1. Auto-releases claimed Squad Needs when a user transitions away from `'going'`.
 * 2. Notifies the event host and co-host when another invitee genuinely transitions
 *    to `'going'` or `'declined'` before the RSVP deadline, skipping bulk Vibe Check
 *    auto-resolutions, `'pending'` transitions, unchanged effective decisions, and
 *    rapid flips within the 60-second cooldown window.
 *
 * @param {object} params
 * @return {Promise<{releasedCount: number, notifiedRecipients: string[], skippedReason: string|null}>}
 */
async function handleInvitationRsvpChange({
    db,
    FieldValue,
    eventId,
    userId,
    beforeData,
    afterData,
    getUserTokens,
    createWebPushConfig,
    sendMulticastToTokens,
    logger = console,
    nowMs = Date.now(),
}) {
    if (!afterData) {
        return {releasedCount: 0, notifiedRecipients: [], skippedReason: "missing_after"};
    }

    const beforeStatus = beforeData?.status || null;
    const afterStatus = afterData.status || null;

    let releasedCount = 0;
    // Only users leaving 'going' can hold claimed Squad Needs.
    if (beforeStatus === "going" && afterStatus !== "going") {
        releasedCount = await releaseClaimedRolesForUser({
            db,
            FieldValue,
            eventId,
            userId,
            logger,
        });
    }

    if (afterStatus !== "going" && afterStatus !== "declined") {
        return {releasedCount, notifiedRecipients: [], skippedReason: "non_notifiable_status"};
    }

    if (beforeStatus === afterStatus) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "status_unchanged"};
    }

    // Only notify on user-initiated RSVPs (which stamp `respondedAt`),
    // skipping bulk Vibe Check auto-resolution updates.
    const beforeRespondedMs = timestampToMillis(beforeData?.respondedAt);
    const afterRespondedMs = timestampToMillis(afterData.respondedAt);
    if (afterRespondedMs === null || afterRespondedMs === beforeRespondedMs) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "no_responded_at_change"};
    }

    const eventRef = db.collection("events").doc(eventId);
    const notifStateRef = eventRef.collection("rsvpNotifState").doc(userId);
    const [eventDoc, notifStateDoc] = await fetchDocsByRefs(db, [eventRef, notifStateRef]);

    const notifStateData = notifStateDoc?.exists ? (notifStateDoc.data() || {}) : {};
    // Read cooldown/dedup state from the isolated `rsvpNotifState` doc (falling back
    // to legacy fields on `afterData` for smooth migration).
    const lastNotifiedStatus =
        notifStateData.lastNotifiedRsvpStatus ?? afterData.lastNotifiedRsvpStatus ?? null;
    const lastNotifiedMs = timestampToMillis(
        notifStateData.lastRsvpNotifiedAt ?? afterData.lastRsvpNotifiedAt
    );

    // Skip if the user's effective decision did not change (e.g., going -> pending -> going).
    if (lastNotifiedStatus === afterStatus) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "same_as_last_notified"};
    }

    // Prevent rapid-tap spam within the cooldown window.
    if (lastNotifiedMs !== null && (nowMs - lastNotifiedMs) < RSVP_COOLDOWN_MS) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "cooldown_active"};
    }

    if (!eventDoc?.exists) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "event_not_found"};
    }

    const eventData = eventDoc.data() || {};
    if (eventData.isPast === true) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "event_is_past"};
    }

    const eventTimeMs = timestampToMillis(eventData.time);
    if (eventTimeMs !== null) {
        const deadlineOffsetMin = eventData.rsvpDeadline || 0;
        const deadlineMs = eventTimeMs + (deadlineOffsetMin * 60 * 1000);
        if (nowMs > deadlineMs) {
            return {releasedCount, notifiedRecipients: [], skippedReason: "past_rsvp_deadline"};
        }
    }

    const recipientIds = [eventData.hostId, eventData.coHostId].filter(
        (id, index, arr) =>
            typeof id === "string" &&
            id.length > 0 &&
            id !== userId &&
            arr.indexOf(id) === index
    );

    if (recipientIds.length === 0) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "no_recipients"};
    }

    // Batch-fetch host, co-host, and responder user profiles in a single RPC.
    const userRefs = [...recipientIds, userId].map((uid) => db.collection("users").doc(uid));
    const userDocs = await fetchDocsByRefs(db, userRefs);
    const recipientDocs = userDocs.slice(0, recipientIds.length);
    const responderDoc = userDocs[recipientIds.length];

    const tokens = [];
    const notifiedRecipients = [];

    for (let i = 0; i < recipientIds.length; i++) {
        const recipientId = recipientIds[i];
        const recipientDoc = recipientDocs[i];
        if (!recipientDoc?.exists) continue;

        const recipientData = recipientDoc.data() || {};
        const blockedUids = recipientData.blockedUids || [];
        if (blockedUids.includes(userId)) {
            continue;
        }

        const wantsRsvp = recipientData.notificationSettings?.rsvp ?? true;
        if (!wantsRsvp) {
            continue;
        }

        const recipientTokens = getUserTokens(recipientData);
        if (recipientTokens.length > 0) {
            tokens.push(...recipientTokens);
            notifiedRecipients.push(recipientId);
        }
    }

    if (tokens.length === 0) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "no_eligible_tokens"};
    }

    const responderData = responderDoc?.exists ? (responderDoc.data() || {}) : {};
    const responderName = responderData.displayName || "Someone";
    const responderPhone = extractUserPhone(responderData);
    const eventTitle = eventData.title || "your hangout";

    const notifTitle = afterStatus === "going" ? "RSVP Update ✅" : "RSVP Update";
    const notifBody = afterStatus === "going"
        ? `${responderName} is going to ${eventTitle}`
        : `${responderName} can't make it to ${eventTitle}`;

    const payload = buildPersonNotificationPayload({
        type: "rsvp_update",
        eventId,
        eventTitle,
        title: notifTitle,
        body: notifBody,
        actorUid: userId,
        actorName: responderName,
        actorPhone: responderPhone,
        channelId: "high_importance_channel",
        androidPriority: "high",
        extraData: {
            responderId: userId,
            rsvpStatus: afterStatus,
        },
        createWebPushConfig,
    });

    // Store cooldown/dedup state on the isolated `rsvpNotifState` doc rather than
    // mutating `invitations/{userId}` so `notifyHostOnRsvpChange` isn't re-triggered.
    await Promise.all([
        notifStateRef.set({
            lastNotifiedRsvpStatus: afterStatus,
            lastRsvpNotifiedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
        sendMulticastToTokens(tokens, payload),
    ]);

    return {releasedCount, notifiedRecipients, skippedReason: null};
}

module.exports = {
    RSVP_COOLDOWN_MS,
    MAX_NOTIF_TITLE_CHARS,
    MAX_NOTIF_BODY_CHARS,
    clipText,
    fetchDocsByRefs,
    timestampToMillis,
    extractUserPhone,
    buildPersonNotificationPayload,
    releaseClaimedRolesForUser,
    handleInvitationRsvpChange,
};
