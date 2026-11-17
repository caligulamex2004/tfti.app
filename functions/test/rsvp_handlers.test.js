const test = require("node:test");
const assert = require("node:assert/strict");
const {
    RSVP_COOLDOWN_MS,
    handleInvitationRsvpChange,
} = require("../rsvp_handlers");

function createFakeFirestore({
    eventData = {},
    roles = [],
    users = {},
    inviteUpdates = [],
} = {}) {
    const deletedSentinel = Symbol("FieldValue.delete");
    const serverTsSentinel = Symbol("FieldValue.serverTimestamp");

    const FieldValue = {
        delete: () => deletedSentinel,
        serverTimestamp: () => serverTsSentinel,
    };

    const roleDocs = roles.map((r) => ({
        id: r.id,
        data: () => ({...r}),
        ref: {id: r.id, _role: r},
    }));

    const batchOps = [];

    const db = {
        batch() {
            const ops = [];
            return {
                update(ref, data) {
                    ops.push({ref, data});
                },
                async commit() {
                    for (const op of ops) {
                        batchOps.push(op);
                        if (op.ref._role) {
                            for (const [k, v] of Object.entries(op.data)) {
                                if (v === deletedSentinel) {
                                    delete op.ref._role[k];
                                } else {
                                    op.ref._role[k] = v;
                                }
                            }
                        }
                    }
                },
            };
        },
        collection(name) {
            if (name === "events") {
                return {
                    doc(eventId) {
                        return {
                            async get() {
                                if (!eventData || eventData._missing) {
                                    return {exists: false};
                                }
                                return {exists: true, data: () => eventData};
                            },
                            collection(sub) {
                                if (sub === "roles") {
                                    return {
                                        where(field, op, val) {
                                            assert.equal(field, "claimedByUid");
                                            assert.equal(op, "==");
                                            return {
                                                async get() {
                                                    const matched = roleDocs.filter(
                                                        (d) => d.data().claimedByUid === val
                                                    );
                                                    return {
                                                        empty: matched.length === 0,
                                                        size: matched.length,
                                                        docs: matched,
                                                    };
                                                },
                                            };
                                        },
                                    };
                                }
                                if (sub === "invitations") {
                                    return {
                                        doc(uid) {
                                            return {
                                                async update(data) {
                                                    inviteUpdates.push({uid, data});
                                                },
                                            };
                                        },
                                    };
                                }
                                throw new Error(`Unexpected subcollection: ${sub}`);
                            },
                        };
                    },
                };
            }
            if (name === "users") {
                return {
                    doc(uid) {
                        return {
                            async get() {
                                const u = users[uid];
                                if (!u) return {exists: false};
                                return {exists: true, data: () => u};
                            },
                        };
                    },
                };
            }
            throw new Error(`Unexpected collection: ${name}`);
        },
    };

    return {db, FieldValue, roleDocs, batchOps, inviteUpdates, serverTsSentinel};
}

function defaultHelpers(sentPayloads) {
    return {
        getUserTokens: (u) => (Array.isArray(u?.fcmTokens) ? u.fcmTokens : []),
        createWebPushConfig: (title, body, eventId, type) => ({
            notification: {title, body},
            fcmOptions: {link: `https://tfti-app.web.app/?eventId=${eventId}&type=${type}`},
        }),
        sendMulticastToTokens: async (tokens, payload) => {
            sentPayloads.push({tokens, payload});
        },
        logger: {log: () => {}, error: () => {}},
    };
}

test("releases claimed Squad Needs when transitioning from going to pending or declined", async () => {
    const roles = [
        {id: "r1", title: "Ice", claimedByUid: "guest1", claimedByName: "Alice", claimedAt: 123},
        {id: "r2", title: "Cups", claimedByUid: "guest1", claimedByName: "Alice", claimedAt: 456},
        {id: "r3", title: "Chips", claimedByUid: "guest2", claimedByName: "Bob", claimedAt: 789},
    ];
    const {db, FieldValue} = createFakeFirestore({
        eventData: {hostId: "host1", title: "BBQ", time: {toMillis: () => 2000000}},
        roles,
        users: {
            host1: {fcmTokens: ["t-host"]},
            guest1: {displayName: "Alice"},
        },
    });
    const sent = [];

    const res = await handleInvitationRsvpChange({
        db,
        FieldValue,
        eventId: "ev1",
        userId: "guest1",
        beforeData: {status: "going", respondedAt: 1000},
        afterData: {status: "pending", respondedAt: 2000},
        nowMs: 1000000,
        ...defaultHelpers(sent),
    });

    assert.equal(res.releasedCount, 2);
    assert.equal(roles[0].claimedByUid, undefined);
    assert.equal(roles[0].claimedByName, undefined);
    assert.equal(roles[1].claimedByUid, undefined);
    assert.equal(roles[2].claimedByUid, "guest2");
    assert.equal(sent.length, 0);
});

test("notifies both host and co-host when guest RSVPs going or declined before deadline", async () => {
    const inviteUpdates = [];
    const {db, FieldValue} = createFakeFirestore({
        eventData: {
            hostId: "host1",
            coHostId: "cohost1",
            title: "Game Night",
            time: {toMillis: () => 5000000},
            rsvpDeadline: 0,
        },
        users: {
            host1: {fcmTokens: ["t-host"]},
            cohost1: {fcmTokens: ["t-cohost"]},
            guest1: {displayName: "Alice"},
        },
        inviteUpdates,
    });
    const sent = [];

    const res1 = await handleInvitationRsvpChange({
        db,
        FieldValue,
        eventId: "ev1",
        userId: "guest1",
        beforeData: {status: "pending"},
        afterData: {status: "going", respondedAt: 2000},
        nowMs: 1000000,
        ...defaultHelpers(sent),
    });

    assert.deepEqual(res1.notifiedRecipients, ["host1", "cohost1"]);
    assert.equal(sent.length, 1);
    assert.deepEqual(sent[0].tokens, ["t-host", "t-cohost"]);
    assert.equal(sent[0].payload.notification.body, "Alice is going to Game Night");
    assert.equal(sent[0].payload.data.type, "rsvp_update");
    assert.equal(inviteUpdates[0].data.lastNotifiedRsvpStatus, "going");

    // Later (past 60s cooldown), guest1 declines
    const res2 = await handleInvitationRsvpChange({
        db,
        FieldValue,
        eventId: "ev1",
        userId: "guest1",
        beforeData: {
            status: "pending",
            respondedAt: 2000 + RSVP_COOLDOWN_MS,
            lastNotifiedRsvpStatus: "going",
            lastRsvpNotifiedAt: 2000,
        },
        afterData: {
            status: "declined",
            respondedAt: 2000 + RSVP_COOLDOWN_MS + 5000,
            lastNotifiedRsvpStatus: "going",
            lastRsvpNotifiedAt: 2000,
        },
        nowMs: 2000 + RSVP_COOLDOWN_MS + 5000,
        ...defaultHelpers(sent),
    });

    assert.deepEqual(res2.notifiedRecipients, ["host1", "cohost1"]);
    assert.equal(sent.length, 2);
    assert.equal(sent[1].payload.notification.body, "Alice can't make it to Game Night");
});

test("skips going -> pending -> going when effective status did not change", async () => {
    const {db, FieldValue} = createFakeFirestore({
        eventData: {hostId: "host1", title: "BBQ", time: {toMillis: () => 5000000}},
        users: {
            host1: {fcmTokens: ["t-host"]},
            guest1: {displayName: "Alice"},
        },
    });
    const sent = [];

    const res = await handleInvitationRsvpChange({
        db,
        FieldValue,
        eventId: "ev1",
        userId: "guest1",
        beforeData: {
            status: "pending",
            respondedAt: 2000,
            lastNotifiedRsvpStatus: "going",
            lastRsvpNotifiedAt: 1000,
        },
        afterData: {
            status: "going",
            respondedAt: 100000,
            lastNotifiedRsvpStatus: "going",
            lastRsvpNotifiedAt: 1000,
        },
        nowMs: 100000,
        ...defaultHelpers(sent),
    });

    assert.equal(res.skippedReason, "same_as_last_notified");
    assert.equal(sent.length, 0);
});

test("enforces 60-second cooldown, skips Vibe Check auto-resolution, and skips post-deadline updates", async () => {
    const {db, FieldValue} = createFakeFirestore({
        eventData: {
            hostId: "host1",
            title: "BBQ",
            time: {toMillis: () => 500000},
            rsvpDeadline: -60, // deadline = 500000 - 3600000 -> already past for positive nowMs
        },
        users: {
            host1: {fcmTokens: ["t-host"]},
            guest1: {displayName: "Alice"},
        },
    });
    const sent = [];

    // 1. Cooldown active
    const cooldownRes = await handleInvitationRsvpChange({
        db,
        FieldValue,
        eventId: "ev1",
        userId: "guest1",
        beforeData: {status: "going", respondedAt: 1000, lastNotifiedRsvpStatus: "going", lastRsvpNotifiedAt: 10000},
        afterData: {status: "declined", respondedAt: 20000, lastNotifiedRsvpStatus: "going", lastRsvpNotifiedAt: 10000},
        nowMs: 20000,
        ...defaultHelpers(sent),
    });
    assert.equal(cooldownRes.skippedReason, "cooldown_active");

    // 2. Vibe check auto-resolution (no respondedAt change)
    const vibeRes = await handleInvitationRsvpChange({
        db,
        FieldValue,
        eventId: "ev1",
        userId: "guest1",
        beforeData: {status: "pending", respondedAt: 1000},
        afterData: {status: "going", respondedAt: 1000},
        nowMs: 100000,
        ...defaultHelpers(sent),
    });
    assert.equal(vibeRes.skippedReason, "no_responded_at_change");

    // 3. Past RSVP deadline
    const deadlineRes = await handleInvitationRsvpChange({
        db,
        FieldValue,
        eventId: "ev1",
        userId: "guest1",
        beforeData: {status: "pending"},
        afterData: {status: "going", respondedAt: 100000},
        nowMs: 100000,
        ...defaultHelpers(sent),
    });
    assert.equal(deadlineRes.skippedReason, "past_rsvp_deadline");
    assert.equal(sent.length, 0);
});

test("excludes self, blocked users, and recipients with notificationSettings.rsvp === false", async () => {
    const {db, FieldValue} = createFakeFirestore({
        eventData: {
            hostId: "host1",
            coHostId: "cohost1",
            title: "Tacos",
            time: {toMillis: () => 5000000},
        },
        users: {
            host1: {fcmTokens: ["t-host"], notificationSettings: {rsvp: false}},
            cohost1: {fcmTokens: ["t-cohost"], blockedUids: []},
        },
    });
    const sent = [];

    // Co-host responds -> host1 opted out -> no tokens sent; cohost1 is excluded as self
    const res1 = await handleInvitationRsvpChange({
        db,
        FieldValue,
        eventId: "ev1",
        userId: "cohost1",
        beforeData: {status: "pending"},
        afterData: {status: "going", respondedAt: 2000},
        nowMs: 1000000,
        ...defaultHelpers(sent),
    });
    assert.equal(res1.skippedReason, "no_eligible_tokens");
    assert.equal(sent.length, 0);

    // Host responds -> only cohost1 is eligible
    const res2 = await handleInvitationRsvpChange({
        db,
        FieldValue,
        eventId: "ev1",
        userId: "host1",
        beforeData: {status: "going"},
        afterData: {status: "declined", respondedAt: 3000},
        nowMs: 1000000,
        ...defaultHelpers(sent),
    });
    assert.deepEqual(res2.notifiedRecipients, ["cohost1"]);
    assert.deepEqual(sent[0].tokens, ["t-cohost"]);
});
