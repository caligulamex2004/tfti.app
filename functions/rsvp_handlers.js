const RSVP_COOLDOWN_MS = 60 * 1000;

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
    if (beforeStatus !== afterStatus && afterStatus !== "going") {
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

    // Skip if the user's effective decision did not change (e.g., going -> pending -> going).
    if (afterData.lastNotifiedRsvpStatus === afterStatus) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "same_as_last_notified"};
    }

    // Prevent rapid-tap spam within the cooldown window.
    const lastNotifiedMs = timestampToMillis(afterData.lastRsvpNotifiedAt);
    if (lastNotifiedMs !== null && (nowMs - lastNotifiedMs) < RSVP_COOLDOWN_MS) {
        return {releasedCount, notifiedRecipients: [], skippedReason: "cooldown_active"};
    }

    const eventRef = db.collection("events").doc(eventId);
    const eventDoc = await eventRef.get();
    if (!eventDoc.exists) {
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

    // Record notification state immediately to keep rapid retries and
    // going -> pending -> going transitions deduplicated.
    await eventRef.collection("invitations").doc(userId).update({
        lastNotifiedRsvpStatus: afterStatus,
        lastRsvpNotifiedAt: FieldValue.serverTimestamp(),
    });

    const tokens = [];
    const notifiedRecipients = [];

    for (const recipientId of recipientIds) {
        const recipientDoc = await db.collection("users").doc(recipientId).get();
        if (!recipientDoc.exists) continue;

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

    const responderDoc = await db.collection("users").doc(userId).get();
    const responderName = responderDoc.exists
        ? (responderDoc.data()?.displayName || "Someone")
        : "Someone";
    const eventTitle = eventData.title || "your hangout";

    const notifTitle = afterStatus === "going" ? "RSVP Update ✅" : "RSVP Update";
    const notifBody = afterStatus === "going"
        ? `${responderName} is going to ${eventTitle}`
        : `${responderName} can't make it to ${eventTitle}`;

    const payload = {
        notification: {
            title: notifTitle,
            body: notifBody,
        },
        data: {
            type: "rsvp_update",
            eventId: eventId,
            responderId: userId,
            rsvpStatus: afterStatus,
        },
        android: {
            priority: "high",
            notification: {
                channelId: "high_importance_channel",
                notificationCount: 1,
            },
        },
        apns: {
            payload: {
                aps: {
                    badge: 1,
                    sound: "default",
                },
            },
        },
        webpush: createWebPushConfig(notifTitle, notifBody, eventId, "rsvp_update"),
    };

    await sendMulticastToTokens(tokens, payload);
    return {releasedCount, notifiedRecipients, skippedReason: null};
}

module.exports = {
    RSVP_COOLDOWN_MS,
    timestampToMillis,
    releaseClaimedRolesForUser,
    handleInvitationRsvpChange,
};
