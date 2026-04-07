const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

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
        try {
            await bucket.deleteFiles({
                prefix: `chat_images/${eventId}/`
            });
            logger.log(`Wiped storage images for event: ${eventId}`);
        } catch (error) {
            // Logs the error but doesn't stop the database cleanup
            logger.error(`Storage deletion failed for ${eventId}:`, error);
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

    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    // --- NEW: SHADOW BAN CHECK ---
    const blockedUids = userData?.blockedUids || [];
    if (hostId && blockedUids.includes(hostId)) {
        logger.log(`Shadow Ban Active: User ${userId} blocked Host ${hostId}. Silencing invite notification.`);
        return; // Silently kill the notification!
    }

    const wantsInvites = userData?.notificationSettings?.invites ?? true;
    if (!fcmToken || !wantsInvites) return;

    const message = {
        token: fcmToken,
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
        }
    };

    try {
        await admin.messaging().send(message);
    } catch (error) {
        logger.error("Error sending invite:", error);
    }
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
        
        if (userData?.fcmToken && wantsUpdates) {
            tokens.push(userData.fcmToken);
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

    const message = {
        tokens: tokens, 
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
        }
    };

    try {
        await admin.messaging().sendEachForMulticast(message);
        logger.log(`Update notification sent to ${tokens.length} guests.`);
    } catch (error) {
        logger.error("Error sending update notification:", error);
    }
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
        if (!userData?.fcmToken) continue;

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

        // Route the token based on global AND local preferences
        if (isMentioned && wantsMentions) {
            mentionedTokens.push(userData.fcmToken);
        } else if (wantsChat && !isChatMuted && !isMentioned) {
            standardTokens.push(userData.fcmToken);
        }
    }

    // 1. Send High-Priority Mention Notifications
    if (mentionedTokens.length > 0) {
        const mentionMessage = {
            tokens: mentionedTokens,
            notification: {
                title: `${senderName} mentioned you in ${eventTitle}`,
                body: text
            },
            data: { type: "chat_mention", eventId: eventId },
            android: {
                priority: "high", 
                notification: { channelId: "high_importance_channel" } 
            }
        };

        try {
            await admin.messaging().sendEachForMulticast(mentionMessage);
            logger.log(`Mention notification sent to ${mentionedTokens.length} users.`);
        } catch (error) {
            logger.error("Error sending mention notification:", error);
        }
    }

    // 2. Send Standard Chat Notifications
    if (standardTokens.length > 0) {
        const standardMessage = {
            tokens: standardTokens,
            notification: {
                title: eventTitle,
                body: `${senderName}: ${text}`
            },
            data: { type: "chat", eventId: eventId },
            android: {
                priority: "normal", 
                notification: { channelId: "chat_channel" } 
            }
        };

        try {
            await admin.messaging().sendEachForMulticast(standardMessage);
            logger.log(`Standard chat notification sent to ${standardTokens.length} users.`);
        } catch (error) {
            logger.error("Error sending standard chat notification:", error);
        }
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
            if (userData?.fcmToken && wantsReminders) {
                tokens.push(userData.fcmToken);
            }
        }

        if (tokens.length === 0) continue;

        const message = {
            tokens: tokens,
            notification: {
                title: "Better get going! 🏃",
                body: `${eventData.title} starts in less than an hour.`
            },
            data: { type: "event_reminder", eventId: eventId },
            android: {
                priority: "high",
                notification: { channelId: "high_importance_channel" }
            }
        };

        try {
            await admin.messaging().sendEachForMulticast(message);
            logger.log(`"Better Get Going" sent to ${tokens.length} users for event ${eventId}`);
        } catch (error) {
            logger.error(`Error sending Better Get Going for ${eventId}:`, error);
        }
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
            if (userData?.fcmToken && wantsReminders) {
                tokens.push(userData.fcmToken);
            }
        }

        if (tokens.length === 0) continue;

        const message = {
            tokens: tokens,
            notification: {
                title: "Happening Now! 🔥",
                body: `${eventData.title} is officially starting!`
            },
            data: { type: "event_start", eventId: eventId },
            android: {
                priority: "high",
                notification: { channelId: "high_importance_channel" }
            }
        };

        try {
            await admin.messaging().sendEachForMulticast(message);
            logger.log(`"Happening Now" sent to ${tokens.length} users for event ${eventId}`);
        } catch (error) {
            logger.error(`Error sending Happening Now for ${eventId}:`, error);
        }
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

            // 👇 NEW: Queue up a notification for the Captain
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
                
                if (hostData && hostData.fcmToken) {
                    const message = {
                        token: hostData.fcmToken,
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
                        }
                    };
                    await admin.messaging().send(message);
                    logger.log(`Tie-breaker notification sent to host ${notif.hostId} for event ${notif.eventId}`);
                }
            } catch (err) {
                logger.error(`Failed to send tie-breaker notification to ${notif.hostId}:`, err);
            }
        }
    }
});