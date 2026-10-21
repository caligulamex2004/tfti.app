const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// --- NOTIFICATION HELPERS (Multi-Device & Web Push) ---
function getUserTokens(userData) {
    if (!userData) return [];
    const tokens = new Set();
    if (Array.isArray(userData.fcmTokens)) {
        for (const t of userData.fcmTokens) {
            if (typeof t === "string" && t.trim().length > 0) {
                tokens.add(t.trim());
            }
        }
    }
    if (typeof userData.fcmToken === "string" && userData.fcmToken.trim().length > 0) {
        tokens.add(userData.fcmToken.trim());
    }
    return Array.from(tokens);
}

function createWebPushConfig(title, body, eventId, type) {
    const link = eventId
        ? `https://tfti-app.web.app/?eventId=${encodeURIComponent(eventId)}&type=${encodeURIComponent(type || 'event')}`
        : "https://tfti-app.web.app/";
    return {
        notification: {
            title: title,
            body: body,
            icon: "/icons/Icon-192.png",
            badge: "/icons/Icon-192.png"
        },
        fcmOptions: {
            link: link
        }
    };
}

async function sendMulticastToTokens(tokens, basePayload) {
    if (!tokens || tokens.length === 0) return;
    const uniqueTokens = Array.from(new Set(tokens.filter(t => typeof t === "string" && t.length > 0)));
    if (uniqueTokens.length === 0) return;

    const message = {
        ...basePayload,
        tokens: uniqueTokens
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(message);
        logger.log(`Multicast sent to ${uniqueTokens.length} devices: ${response.successCount} succeeded, ${response.failureCount} failed.`);

        if (response.failureCount > 0) {
            const deadTokens = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    const errCode = resp.error?.code;
                    if (
                        errCode === "messaging/registration-token-not-registered" ||
                        errCode === "messaging/invalid-registration-token"
                    ) {
                        deadTokens.push(uniqueTokens[idx]);
                    }
                }
            });

            if (deadTokens.length > 0) {
                for (let i = 0; i < deadTokens.length; i += 10) {
                    const chunk = deadTokens.slice(i, i + 10);
                    try {
                        const usersToPrune = await db.collection("users")
                            .where("fcmTokens", "array-contains-any", chunk)
                            .get();

                        const batch = db.batch();
                        usersToPrune.docs.forEach(doc => {
                            batch.update(doc.ref, {
                                fcmTokens: admin.firestore.FieldValue.arrayRemove(...chunk)
                            });
                        });
                        if (!usersToPrune.empty) {
                            await batch.commit();
                            logger.log(`Pruned ${deadTokens.length} stale FCM token(s) from user profiles.`);
                        }
                    } catch (pruneErr) {
                        logger.error("Failed to prune stale tokens:", pruneErr);
                    }
                }
            }
        }
    } catch (error) {
        logger.error("Error executing sendMulticastToTokens:", error);
    }
}

// --- 1. THE JANITOR: Delete events that have expired past their keepAlive limit ---
exports.dailyCleanup = onSchedule({
    schedule: "0 0,12 * * *", // Runs exactly at Midnight and Noon
    timeZone: "America/New_York",
}, async (event) => {
    const now = new Date();
    
    // The absolute minimum lifespan is 24 hours. 
    // We use this as our base query to avoid fetching active, brand new events.
    const baseCutoff = new Date(now.getTime());
    baseCutoff.setHours(baseCutoff.getHours() - 24); 

    const snapshot = await db.collection("events")
        .where("time", "<", admin.firestore.Timestamp.fromDate(baseCutoff))
        .get();

    if (snapshot.empty) {
        logger.log("No potentially old events to clean up.");
        return;
    } 

    const batch = db.batch();
    const bucket = admin.storage().bucket(); // Instantiates the storage bucket
    let deleteCount = 0;

    for (const doc of snapshot.docs) {
        const data = doc.data();
        const keepAliveDays = data.keepAliveDays || 0;
        const eventTime = data.time.toDate();
        
        // Calculate the true expiration date based on the host's keepAlive setting.
        // Default is 1 day (24 hours). Otherwise, use the keepAliveDays setting.
        const lifespanDays = keepAliveDays > 0 ? keepAliveDays : 1;
        const expirationTime = new Date(eventTime.getTime() + (lifespanDays * 24 * 60 * 60 * 1000));
        
        // If the event hasn't reached its true expiration time yet, spare it!
        if (now < expirationTime) {
            continue;
        }

        const eventId = doc.id;

        // --- Wipe associated images in Firebase Storage ---
        // Array of all storage folder prefixes associated with this event
        const storagePaths = [
            `chat_images/${eventId}/`,
            `event_banners/${eventId}/`
        ];

        for (const path of storagePaths) {
            try {
                await bucket.deleteFiles({ prefix: path });
                logger.log(`Wiped storage path: ${path}`);
            } catch (error) {
                // Logs the error but doesn't stop the rest of the cleanup
                logger.error(`Storage deletion failed for path ${path}:`, error);
            }
        }

        // Wipe Messages
        const messages = await doc.ref.collection("messages").get();
        messages.forEach(msg => batch.delete(msg.ref));

        // Wipe Invitations
        const invitations = await doc.ref.collection("invitations").get();
        invitations.forEach(invite => batch.delete(invite.ref));

        // --- Wipe Squad Needs / Roles ---
        const roles = await doc.ref.collection("roles").get();
        roles.forEach(role => batch.delete(role.ref));

        // Delete the Parent Event
        batch.delete(doc.ref);
        deleteCount++;
    }

    if (deleteCount > 0) {
        await batch.commit();
        logger.log(`Cleanup complete: Deleted ${deleteCount} expired events.`);
    } else {
        logger.log("Cleanup complete: Checked events, but none have reached their extended keepAlive expiration yet.");
    }
});

// --- 2. THE BOUNCER: Reactive Ban Check ---
exports.enforceBan = onDocumentCreated("events/{eventId}/messages/{messageId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const senderId = data.senderId;

    if (!senderId) return;

    const userDoc = await db.collection("users").doc(senderId).get();
    
    if (userDoc.exists && userDoc.data().isBanned === true) {
        await snapshot.ref.delete();
        logger.log(`BANNED USER DETECTED: Deleted message from ${senderId}`);
    }
});

// --- 3. SMART POSTMAN: New Invite Notification ---
exports.sendInviteNotification = onDocumentCreated("events/{eventId}/invitations/{userId}", async (event) => {
    const userId = event.params.userId;
    const eventId = event.params.eventId;

    try {
        await db.collection("events").doc(eventId).update({
            visibleTo: admin.firestore.FieldValue.arrayUnion(userId)
        });
        logger.log(`Added ${userId} to visibleTo for event ${eventId}`);
    } catch (e) {
        logger.error(`Failed to update visibleTo: ${e}`);
    }

    const eventDoc = await db.collection("events").doc(eventId).get();
    const eventData = eventDoc.data() || {};
    const hostId = eventData.hostId;
    const eventTitle = eventData.title || "New Event";

    if (userId === hostId) {
        logger.log(`Skipping invite notification for host ${userId}`);
        return;
    }

    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const tokens = getUserTokens(userData);

    // --- NEW: SHADOW BAN CHECK ---
    const blockedUids = userData?.blockedUids || [];
    if (hostId && blockedUids.includes(hostId)) {
        logger.log(`Shadow Ban Active: User ${userId} blocked Host ${hostId}. Silencing invite notification.`);
        return; // Silently kill the notification!
    }

    const wantsInvites = userData?.notificationSettings?.invites ?? true;
    if (tokens.length === 0 || !wantsInvites) return;

    const payload = {
        notification: {
            title: "You're Invited! 📨",
            body: `You have been invited to ${eventTitle}`
        },
        data: { type: "invite", eventId: eventId },
        android: {
            priority: "high", 
            notification: { 
                channelId: "high_importance_channel",
                notificationCount: 1
            }
        },
        apns: {
            payload: {
                aps: {
                    badge: 1, 
                    sound: "default"
                }
            }
        },
        webpush: createWebPushConfig("You're Invited! 📨", `You have been invited to ${eventTitle}`, eventId, "invite")
    };

    await sendMulticastToTokens(tokens, payload);
});

// --- 4. SMART POSTMAN: Event Update Notification ---
exports.notifyEventUpdate = onDocumentUpdated("events/{eventId}", async (event) => {
    const newData = event.data.after.data();
    const oldData = event.data.before.data();
    const eventId = event.params.eventId;
    
    // --- Detect Vibe Check Conversion ---
    const isVibeCheckConversion = oldData.type === 'vibe_check' && newData.type === 'event';

    const oldTime = oldData.time ? oldData.time.toDate().toString() : "";
    const newTime = newData.time ? newData.time.toDate().toString() : "";
    
    const timeChanged = oldTime !== newTime;
    const locationChanged = newData.location !== oldData.location;

    // If nothing important changed AND it's not a conversion, kill the function
    if (!timeChanged && !locationChanged && !isVibeCheckConversion) {
        return; 
    }

    const invitationsSnap = await db.collection(`events/${eventId}/invitations`).get();
    if (invitationsSnap.empty) return;

    const tokens = [];
    for (const invite of invitationsSnap.docs) {
        const userId = invite.id;
        if (userId === newData.hostId) continue; // Don't notify the host of their own action

        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();
        
        // --- NEW: SHADOW BAN CHECK ---
        const blockedUids = userData?.blockedUids || [];
        if (blockedUids.includes(newData.hostId)) {
            continue; // Silently skip notifying this user about the host's updates
        }

        const wantsUpdates = userData?.notificationSettings?.updates ?? true;
        
        const userTokens = getUserTokens(userData);
        if (userTokens.length > 0 && wantsUpdates) {
            tokens.push(...userTokens);
        }
    }

    if (tokens.length === 0) return;

    let notifTitle = `Update: ${newData.title}`;
    let bodyText = "Details have changed.";

    // --- Route the notification text based on what actually happened ---
    if (isVibeCheckConversion) {
        notifTitle = "Vibe Check Locked In! 🔒";
        bodyText = `The squad has spoken. We're doing ${newData.title} at ${newData.location}!`;
    } else if (timeChanged) {
        bodyText = "⏳ New Time: Plans have been rescheduled!";
    } else if (locationChanged) {
        bodyText = "📍 New Location: The venue has changed!";
    }

    const payload = {
        notification: {
            title: notifTitle,
            body: bodyText
        },
        data: {
            type: "event_update",
            eventId: eventId
        },
        android: {
            priority: "high",
            notification: { 
                channelId: "high_importance_channel",
                notificationCount: 1
            }
        },
        apns: {
            payload: {
                aps: {
                    badge: 1,
                    sound: "default"
                }
            }
        },
        webpush: createWebPushConfig(notifTitle, bodyText, eventId, "event_update")
    };

    await sendMulticastToTokens(tokens, payload);
});

// --- 5. SMART POSTMAN: New Chat Message & Mentions ---
exports.notifyNewChatMessage = onDocumentCreated("events/{eventId}/messages/{messageId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageData = snapshot.data();
    const senderId = messageData.senderId;
    const senderName = messageData.senderName || "Someone";
    const text = messageData.text;
    const eventId = event.params.eventId;
    
    const mentionedUids = messageData.mentionedUids || [];

    const eventDoc = await db.collection("events").doc(eventId).get();
    const eventTitle = eventDoc.data()?.title || "Event Chat";

    const invitationsSnap = await db.collection(`events/${eventId}/invitations`).get();
    
    const standardTokens = [];
    const mentionedTokens = [];

    for (const invite of invitationsSnap.docs) {
        const userId = invite.id;
        const inviteData = invite.data();
        
        if (userId === senderId) continue; 

        const userDoc = await db.collection("users").doc(userId).get();
        const userData = userDoc.data();
        const userTokens = getUserTokens(userData);
        if (userTokens.length === 0) continue;

        // --- NEW: SHADOW BAN CHECK ---
        const blockedUids = userData?.blockedUids || [];
        if (blockedUids.includes(senderId)) {
            continue; // Shadow Ban: Completely ignore this message/mention for this user
        }

        const isMentioned = mentionedUids.includes(userId);
        
        // Global User Preferences
        const wantsChat = userData?.notificationSettings?.chat ?? true;
        const wantsMentions = userData?.notificationSettings?.mentions ?? true;
        
        // Local Event Setting (From the mute button!)
        const isChatMuted = inviteData?.isMuted ?? false;

        // Route the tokens based on global AND local preferences
        if (isMentioned && wantsMentions) {
            mentionedTokens.push(...userTokens);
        } else if (wantsChat && !isChatMuted && !isMentioned) {
            standardTokens.push(...userTokens);
        }
    }

    // 1. Send High-Priority Mention Notifications
    if (mentionedTokens.length > 0) {
        const mentionPayload = {
            notification: {
                title: `${senderName} mentioned you in ${eventTitle}`,
                body: text
            },
            data: { type: "chat_mention", eventId: eventId },
            android: {
                priority: "high", 
                notification: { channelId: "high_importance_channel" } 
            },
            apns: {
                payload: { aps: { sound: "default" } }
            },
            webpush: createWebPushConfig(`${senderName} mentioned you in ${eventTitle}`, text, eventId, "chat_mention")
        };

        await sendMulticastToTokens(mentionedTokens, mentionPayload);
    }

    // 2. Send Standard Chat Notifications
    if (standardTokens.length > 0) {
        const standardPayload = {
            notification: {
                title: eventTitle,
                body: `${senderName}: ${text}`
            },
            data: { type: "chat", eventId: eventId },
            android: {
                priority: "normal", 
                notification: { channelId: "chat_channel" } 
            },
            apns: {
                payload: { aps: { sound: "default" } }
            },
            webpush: createWebPushConfig(eventTitle, `${senderName}: ${text}`, eventId, "chat")
        };

        await sendMulticastToTokens(standardTokens, standardPayload);
    }
});

// --- 6. THE REMINDER: Better Get Going Notification ---
exports.notifyBetterGetGoing = onSchedule({
    schedule: "every 5 minutes",
    timeZone: "America/New_York",
    }, async (event) => {
    const now = new Date();
    const inOneHour = new Date(now.getTime() + 60 * 60 * 1000);

    // Find events happening within the next 60 minutes
    const snapshot = await db.collection("events")
        .where("time", "<=", admin.firestore.Timestamp.fromDate(inOneHour))
        .where("time", ">", admin.firestore.Timestamp.fromDate(now))
        .get();

    if (snapshot.empty) return;

    for (const doc of snapshot.docs) {
        const eventId = doc.id;
        const eventData = doc.data();

        // Skip if we already sent the 60-minute warning
        if (eventData.notifiedBetterGetGoing) continue;

        // Mark as notified immediately to prevent duplicate sends
        await doc.ref.update({ notifiedBetterGetGoing: true });

        // Get everyone who is officially "going" (this includes the host)
        const invitationsSnap = await db.collection(`events/${eventId}/invitations`)
            .where("status", "==", "going")
            .get();

        if (invitationsSnap.empty) continue;

        const tokens = [];
        for (const invite of invitationsSnap.docs) {
            const userId = invite.id;
            const userDoc = await db.collection("users").doc(userId).get();
            const userData = userDoc.data();

            // Respect notification settings (defaulting to true if undefined)
            const wantsReminders = userData?.notificationSettings?.reminder_hour ?? true;
            const userTokens = getUserTokens(userData);
            if (userTokens.length > 0 && wantsReminders) {
                tokens.push(...userTokens);
            }
        }

        if (tokens.length === 0) continue;

        const payload = {
            notification: {
                title: "Better get going! 🏃",
                body: `${eventData.title} starts in less than an hour.`
            },
            data: { type: "event_reminder", eventId: eventId },
            android: {
                priority: "high",
                notification: { channelId: "high_importance_channel" }
            },
            apns: {
                payload: { aps: { sound: "default" } }
            },
            webpush: createWebPushConfig("Better get going! 🏃", `${eventData.title} starts in less than an hour.`, eventId, "event_reminder")
        };

        await sendMulticastToTokens(tokens, payload);
    }
});

// --- 7. THE KICKOFF: Happening Now Notification ---
exports.notifyHappeningNow = onSchedule({
    schedule: "every 5 minutes",
    timeZone: "America/New_York",
}, async (event) => {
    const now = new Date();
    // Look back up to 1 hour to catch events that just started
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000); 

    const snapshot = await db.collection("events")
        .where("time", "<=", admin.firestore.Timestamp.fromDate(now))
        .where("time", ">", admin.firestore.Timestamp.fromDate(oneHourAgo))
        .get();

    if (snapshot.empty) return;

    for (const doc of snapshot.docs) {
        const eventId = doc.id;
        const eventData = doc.data();

        // Skip if we already sent the kickoff notification
        if (eventData.notifiedHappeningNow) continue;

        // Mark as notified immediately
        await doc.ref.update({ notifiedHappeningNow: true });

        // Get everyone who is officially "going"
        const invitationsSnap = await db.collection(`events/${eventId}/invitations`)
            .where("status", "==", "going")
            .get();

        if (invitationsSnap.empty) continue;

        const tokens = [];
        for (const invite of invitationsSnap.docs) {
            const userId = invite.id;
            const userDoc = await db.collection("users").doc(userId).get();
            const userData = userDoc.data();

            const wantsReminders = userData?.notificationSettings?.reminder_start ?? true;
            const userTokens = getUserTokens(userData);
            if (userTokens.length > 0 && wantsReminders) {
                tokens.push(...userTokens);
            }
        }

        if (tokens.length === 0) continue;

        const payload = {
            notification: {
                title: "Happening Now! 🔥",
                body: `${eventData.title} is officially starting!`
            },
            data: { type: "event_start", eventId: eventId },
            android: {
                priority: "high",
                notification: { channelId: "high_importance_channel" }
            },
            apns: {
                payload: { aps: { sound: "default" } }
            },
            webpush: createWebPushConfig("Happening Now! 🔥", `${eventData.title} is officially starting!`, eventId, "event_start")
        };

        await sendMulticastToTokens(tokens, payload);
    }
});

// --- 8. THE DECIDER: Auto-Resolve Expired Vibe Checks ---
exports.resolveExpiredVibeChecks = onSchedule({
    schedule: "every 1 minutes", // Wakes up every 60 seconds to check for expired polls
    timeZone: "America/New_York",
}, async (event) => {
    const now = new Date();
    
    // Find all active vibe checks that haven't been resolved or tied yet
    const snapshot = await db.collection("events")
        .where("type", "==", "vibe_check")
        .where("lockedOptionId", "==", null)
        .where("isTieBreakerNeeded", "==", false)
        .get();

    if (snapshot.empty) return;

    const batch = db.batch();
    let resolveCount = 0;
    const notificationsToSend = []; // NEW: Array to hold our captain notifications

    for (const doc of snapshot.docs) {
        const eventData = doc.data();
        const eventId = doc.id;
        
        if (!eventData.time) continue;
        
        const eventTime = eventData.time.toDate();
        const rsvpDeadlineOffset = eventData.rsvpDeadline || 0; 
        const deadlineTime = new Date(eventTime.getTime() + (rsvpDeadlineOffset * 60 * 1000));

        // If the deadline hasn't passed yet, leave it alone!
        if (now <= deadlineTime) continue;

        // --- It's past the deadline. Time to resolve! ---
        const invitesSnap = await doc.ref.collection("invitations").get();
        
        let voteCounts = {};
        invitesSnap.docs.forEach(inviteDoc => {
            const invite = inviteDoc.data();
            if (invite.status === 'declined') return; 
            
            const votes = invite.votes || [];
            votes.forEach(v => {
                voteCounts[v] = (voteCounts[v] || 0) + 1;
            });
        });

        const pollOptions = eventData.pollOptions || [];
        if (pollOptions.length === 0) continue;

        let maxVotes = -1;
        let winningIds = [];

        for (const opt of pollOptions) {
            const optId = opt.id;
            const count = voteCounts[optId] || 0;
            if (count > maxVotes) {
                maxVotes = count;
                winningIds = [optId];
            } else if (count === maxVotes) {
                winningIds.push(optId);
            }
        }

        if (winningIds.length === 1) {
            // Clear Winner!
            const winnerId = winningIds[0];
            const winnerOpt = pollOptions.find(o => o.id === winnerId);

            batch.update(doc.ref, {
                type: 'event', 
                lockedOptionId: winnerId,
                title: winnerOpt.title,
                location: winnerOpt.location,
                isTieBreakerNeeded: false,
                lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            invitesSnap.docs.forEach(inviteDoc => {
                const invite = inviteDoc.data();
                if (invite.status === 'declined') return;

                const votes = invite.votes || [];
                let newStatus = votes.includes(winnerId) ? 'going' : 'pending';
                
                if (invite.role === 'host' || invite.role === 'co-host') {
                    newStatus = 'going';
                }

                batch.update(inviteDoc.ref, { status: newStatus });
            });
            
            logger.log(`Vibe Check ${eventId} resolved with winner: ${winnerOpt.title}`);
            resolveCount++;

        } else if (winningIds.length > 1) {
            // It's a Tie! 
            batch.update(doc.ref, {
                isTieBreakerNeeded: true,
                lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            logger.log(`Vibe Check ${eventId} ended in a tie.`);
            resolveCount++;

            // NEW: Queue up a notification for the Captain
            if (eventData.hostId) {
                notificationsToSend.push({
                    hostId: eventData.hostId,
                    eventId: eventId,
                    eventTitle: eventData.title || "your hangout"
                });
            }
        }
    }

    if (resolveCount > 0) {
        await batch.commit();
        logger.log(`Auto-resolved ${resolveCount} expired vibe checks.`);

        // Dispatch the tie-breaker push notifications
        for (const notif of notificationsToSend) {
            try {
                const hostDoc = await db.collection("users").doc(notif.hostId).get();
                const hostData = hostDoc.data();
                const hostTokens = getUserTokens(hostData);
                
                if (hostTokens.length > 0) {
                    const payload = {
                        notification: {
                            title: "Tie Breaker Needed! ⚖️",
                            body: `The squad is split! Open '${notif.eventTitle}' to lock in the final plan.`
                        },
                        data: {
                            type: "event_update", // Triggers your app to open the Event Details Page
                            eventId: notif.eventId
                        },
                        android: {
                            priority: "high",
                            notification: { channelId: "high_importance_channel" }
                        },
                        apns: {
                            payload: {
                                aps: { badge: 1, sound: "default" }
                            }
                        },
                        webpush: createWebPushConfig("Tie Breaker Needed! ⚖️", `The squad is split! Open '${notif.eventTitle}' to lock in the final plan.`, notif.eventId, "event_update")
                    };
                    await sendMulticastToTokens(hostTokens, payload);
                    logger.log(`Tie-breaker notification sent to host ${notif.hostId} for event ${notif.eventId}`);
                }
            } catch (err) {
                logger.error(`Failed to send tie-breaker notification to ${notif.hostId}:`, err);
            }
        }
    }
});

// --- 9. THE GAME MASTER: Award Points & Send Notification ---
exports.awardLootDrops = onSchedule("every 15 minutes", async (event) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    try {
        // 1. THE SWEEP
        // Query events that have passed their endTime AND have not yet rewarded the host
        const eventsSnapshot = await db.collection("events")
            .where("pointsAwarded", "==", false)
            .where("endTime", "<=", now)
            .get();

        if (eventsSnapshot.empty) {
            console.log("No completed events waiting for loot drops.");
            return;
        }

        console.log(`Processing ${eventsSnapshot.size} ended events...`);

        // Process each event
        for (const eventDoc of eventsSnapshot.docs) {
            const eventId = eventDoc.id;
            const eventData = eventDoc.data();
            const hostId = eventData.hostId;
            const coHostId = eventData.coHostId; // Extract co-host if one exists

            // Prevent processing if there's no host
            if (!hostId) continue;

            // 2. THE CALCULATION
            // Count how many people officially went (including the host)
            const invitesSnapshot = await db.collection("events").doc(eventId)
                .collection("invitations")
                .where("status", "==", "going")
                .get();

            const manaEarned = invitesSnapshot.size; // 1 Mana per attendee
            const hpEarned = 1; // 1 HP per successful hangout
            const coHostHpEarned = 1; // 1 HP for helping, 0 Mana

            // 3. THE PAYOUT & THE SEAL (Atomic Batch)
            // Using a batch guarantees that if the server crashes mid-process, 
            // you don't accidentally give points without sealing the event!
            const batch = db.batch();

            // Payout Main Host
            const hostRef = db.collection("users").doc(hostId);
            batch.update(hostRef, {
                hp: admin.firestore.FieldValue.increment(hpEarned),
                mana: admin.firestore.FieldValue.increment(manaEarned)
            });

            // Payout Co-Host (if they exist)
            if (coHostId) {
                const coHostRef = db.collection("users").doc(coHostId);
                batch.update(coHostRef, {
                    hp: admin.firestore.FieldValue.increment(coHostHpEarned)
                });
            }

            // Seal the Event
            const eventRef = db.collection("events").doc(eventId);
            batch.update(eventRef, {
                pointsAwarded: true, // THE SEAL
                isPast: true         // DATABASE INTEGRITY
            });

            await batch.commit();
            console.log(`Awarded ${hpEarned} HP and ${manaEarned} Mana to Host ${hostId}.`);
            if (coHostId) {
                console.log(`Awarded ${coHostHpEarned} HP to Co-Captain ${coHostId}.`);
            }

            // 4. THE NOTIFICATIONS
            // Notify Main Host
            const hostDoc = await hostRef.get();
            if (hostDoc.exists) {
                const hostInfo = hostDoc.data();
                const notificationSettings = hostInfo.notificationSettings || {};
                const hostTokens = getUserTokens(hostInfo); 

                if (notificationSettings.points !== false && hostTokens.length > 0) {
                    const hostPayload = {
                        notification: {
                            title: "Loot Drop! 📦",
                            body: `Congratulations! "${eventData.title}" earned you ${hpEarned} HP and ${manaEarned} Mana!`,
                        },
                        data: {
                            type: "points",
                            eventId: eventId
                        },
                        android: {
                            priority: "high",
                            notification: { channelId: "high_importance_channel" }
                        },
                        apns: {
                            payload: { aps: { sound: "default" } }
                        },
                        webpush: createWebPushConfig("Loot Drop! 📦", `Congratulations! "${eventData.title}" earned you ${hpEarned} HP and ${manaEarned} Mana!`, eventId, "points")
                    };

                    await sendMulticastToTokens(hostTokens, hostPayload);
                    console.log(`Push sent to host of ${eventId}.`);
                }
            }

            // Notify Co-Host
            if (coHostId) {
                const coHostDoc = await db.collection("users").doc(coHostId).get();
                if (coHostDoc.exists) {
                    const coHostInfo = coHostDoc.data();
                    const notificationSettings = coHostInfo.notificationSettings || {};
                    const coHostTokens = getUserTokens(coHostInfo); 

                    if (notificationSettings.points !== false && coHostTokens.length > 0) {
                        const coHostPayload = {
                            notification: {
                                title: "Loot Drop! 📦",
                                body: `Thanks for the assist! "${eventData.title}" earned you ${coHostHpEarned} HP!`,
                            },
                            data: {
                                type: "points",
                                eventId: eventId
                            },
                            android: {
                                priority: "high",
                                notification: { channelId: "high_importance_channel" }
                            },
                            apns: {
                                payload: { aps: { sound: "default" } }
                            },
                            webpush: createWebPushConfig("Loot Drop! 📦", `Thanks for the assist! "${eventData.title}" earned you ${coHostHpEarned} HP!`, eventId, "points")
                        };

                        await sendMulticastToTokens(coHostTokens, coHostPayload);
                        console.log(`Push sent to co-host of ${eventId}.`);
                    }
                }
            }
        }
    } catch (error) {
        console.error("Critical error in awardLootDrops:", error);
    }
});

/**
 * Callable Cloud Function: placesAutocomplete
 * Proxies Google Places Autocomplete API server-to-server to eradicate browser CORS limitations
 * and avoid exposing the Google Maps API key on the client.
 */
exports.placesAutocomplete = onCall(
    {
        cors: true,
        enforceAppCheck: false,
    },
    async (request) => {
        if (!request.auth) {
            throw new HttpsError(
                "unauthenticated",
                "Authentication is required to search locations."
            );
        }

        const input = request.data?.input;
        const sessionToken = request.data?.sessionToken || "";

        if (!input || typeof input !== "string" || input.trim().length === 0) {
            return {
                status: "OK",
                predictions: [],
            };
        }

        const apiKey = process.env.PLACES_API_KEY || request.data?.apiKey;
        if (!apiKey) {
            logger.error("PLACES_API_KEY is not configured on Cloud Functions.");
            throw new HttpsError(
                "failed-precondition",
                "Places service is temporarily unavailable."
            );
        }

        const encodedInput = encodeURIComponent(input.trim());
        const sessionParam = sessionToken ? `&sessiontoken=${encodeURIComponent(sessionToken)}` : "";
        const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodedInput}&key=${apiKey}${sessionParam}`;

        try {
            const response = await fetch(url);
            if (!response.ok) {
                logger.error(`Google Places API HTTP error: ${response.status} ${response.statusText}`);
                throw new HttpsError("internal", "Failed to contact Google Places service.");
            }

            const data = await response.json();
            return {
                status: data.status || "OK",
                predictions: data.predictions || [],
                errorMessage: data.error_message || null,
            };
        } catch (error) {
            if (error instanceof HttpsError) throw error;
            logger.error("Exception in placesAutocomplete proxy:", error);
            throw new HttpsError("internal", "Network error communicating with Google Places.");
        }
    }
);
