import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String type; // 'event' or 'vibe_check'
  final String hostId;
  final String? coHostId;

  final String title;
  final String location;
  final String details;
  final String? bannerUrl;

  final DateTime time;
  final DateTime? endTime;
  final bool isPast;

  // Tactical Settings
  final bool isImportantDetails;
  final int rsvpDeadline;
  final int keepAliveDays;
  final bool pointsAwarded;

  // Audience
  final bool inviteAll;
  final List<String> invitedCircles;
  final bool? coHostInviteAll;
  final List<String>? coHostInvitedCircles;
  final List<String> visibleTo;

  // Seasons
  final String? seasonId;
  final int? seasonInstance;
  final int? seasonTotal;

  // Vibe Checks
  final List<Map<String, dynamic>>? pollOptions;
  final String? lockedOptionId;
  final bool? isTieBreakerNeeded;

  // Meta & Chat
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final Map<String, dynamic>? latestCriticalChange;
  final DateTime? lastMessageAt;
  final String? lastMessageSnippet;
  final List<String>? lastMessageMentions;

  Event({
    required this.id,
    this.type = 'event',
    required this.hostId,
    this.coHostId,
    required this.title,
    required this.location,
    this.details = '',
    this.bannerUrl,
    required this.time,
    this.endTime,
    this.isPast = false,
    this.isImportantDetails = false,
    this.rsvpDeadline = 0,
    this.keepAliveDays = 0,
    this.pointsAwarded = false,
    this.inviteAll = false,
    this.invitedCircles = const [],
    this.coHostInviteAll,
    this.coHostInvitedCircles,
    this.visibleTo = const [],
    this.seasonId,
    this.seasonInstance,
    this.seasonTotal,
    this.pollOptions,
    this.lockedOptionId,
    this.isTieBreakerNeeded,
    this.createdAt,
    this.lastUpdatedAt,
    this.latestCriticalChange,
    this.lastMessageAt,
    this.lastMessageSnippet,
    this.lastMessageMentions,
  });

  bool get isVibeCheck => type == 'vibe_check';
  bool get isHangout => type != 'vibe_check';
  bool isHost(String uid) => hostId == uid;
  bool isCoHost(String? uid) => uid != null && coHostId == uid;

  DateTime get calculatedEndTime {
    if (endTime != null) return endTime!;
    final int durationMinutes = keepAliveDays > 0 ? (keepAliveDays * 24 * 60) : 240;
    return time.add(Duration(minutes: durationMinutes));
  }

  DateTime get rsvpDeadlineTime => time.add(Duration(minutes: rsvpDeadline));

  bool isCurrentlyPast([DateTime? currentTime]) {
    final now = currentTime ?? DateTime.now();
    return isPast || now.isAfter(calculatedEndTime);
  }

  // Convert JSON from Firestore -> our Object
  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Event.fromMap(data, id: doc.id);
  }

  factory Event.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Event(
      id: id ?? data['id'] ?? '',
      type: data['type'] ?? 'event',
      hostId: data['hostId'] ?? '',
      coHostId: data['coHostId'],
      title: data['title'] ?? '',
      location: data['location'] ?? '',
      details: data['details'] ?? data['description'] ?? '',
      bannerUrl: data['bannerUrl'],

      // Safely parse timestamps
      time: parseDate(data['time'], DateTime.now()),
      endTime: parseNullableDate(data['endTime']),
      isPast: data['isPast'] == true,

      isImportantDetails: data['isImportantDetails'] == true,
      rsvpDeadline: data['rsvpDeadline'] ?? 0,
      keepAliveDays: data['keepAliveDays'] ?? 0,
      pointsAwarded: data['pointsAwarded'] == true,

      inviteAll: data['inviteAll'] == true,
      invitedCircles: List<String>.from(data['invitedCircles'] ?? []),
      coHostInviteAll: data['coHostInviteAll'],
      coHostInvitedCircles: data['coHostInvitedCircles'] != null
          ? List<String>.from(data['coHostInvitedCircles'])
          : null,
      visibleTo: List<String>.from(data['visibleTo'] ?? []),

      seasonId: data['seasonId'],
      seasonInstance: data['seasonInstance'],
      seasonTotal: data['seasonTotal'],

      pollOptions: data['pollOptions'] != null
          ? List<Map<String, dynamic>>.from(data['pollOptions'])
          : null,
      lockedOptionId: data['lockedOptionId'],
      isTieBreakerNeeded: data['isTieBreakerNeeded'],

      createdAt: parseNullableDate(data['created_at'] ?? data['createdAt']),
      lastUpdatedAt: parseNullableDate(data['lastUpdatedAt']),
      latestCriticalChange:
          data['latestCriticalChange'] as Map<String, dynamic>?,

      lastMessageAt: parseNullableDate(data['lastMessageAt']),
      lastMessageSnippet: data['lastMessageSnippet'] as String?,
      lastMessageMentions: data['lastMessageMentions'] != null
          ? List<String>.from(data['lastMessageMentions'])
          : null,
    );
  }

  // Convert our Object -> JSON for Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'hostId': hostId,
      if (coHostId != null) 'coHostId': coHostId,
      'title': title,
      'location': location,
      'details': details,
      if (bannerUrl != null) 'bannerUrl': bannerUrl,

      'time': Timestamp.fromDate(time),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'isPast': isPast,

      'isImportantDetails': isImportantDetails,
      'rsvpDeadline': rsvpDeadline,
      'keepAliveDays': keepAliveDays,
      'pointsAwarded': pointsAwarded,

      'inviteAll': inviteAll,
      'invitedCircles': invitedCircles,
      if (coHostInviteAll != null) 'coHostInviteAll': coHostInviteAll,
      if (coHostInvitedCircles != null)
        'coHostInvitedCircles': coHostInvitedCircles,
      'visibleTo': visibleTo,

      if (seasonId != null) 'seasonId': seasonId,
      if (seasonInstance != null) 'seasonInstance': seasonInstance,
      if (seasonTotal != null) 'seasonTotal': seasonTotal,

      if (pollOptions != null) 'pollOptions': pollOptions,
      if (lockedOptionId != null) 'lockedOptionId': lockedOptionId,
      if (isTieBreakerNeeded != null) 'isTieBreakerNeeded': isTieBreakerNeeded,

      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (lastUpdatedAt != null)
        'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt!),
      if (latestCriticalChange != null)
        'latestCriticalChange': latestCriticalChange,

      if (lastMessageAt != null)
        'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      if (lastMessageSnippet != null) 'lastMessageSnippet': lastMessageSnippet,
      if (lastMessageMentions != null)
        'lastMessageMentions': lastMessageMentions,
    };
  }

  // Best Practice: Allows creating a modified clone of the object
  Event copyWith({
    String? id,
    String? type,
    String? hostId,
    String? coHostId,
    String? title,
    String? location,
    String? details,
    String? bannerUrl,
    DateTime? time,
    DateTime? endTime,
    bool? isPast,
    bool? isImportantDetails,
    int? rsvpDeadline,
    int? keepAliveDays,
    bool? pointsAwarded,
    bool? inviteAll,
    List<String>? invitedCircles,
    bool? coHostInviteAll,
    List<String>? coHostInvitedCircles,
    List<String>? visibleTo,
    String? seasonId,
    int? seasonInstance,
    int? seasonTotal,
    List<Map<String, dynamic>>? pollOptions,
    String? lockedOptionId,
    bool? isTieBreakerNeeded,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    Map<String, dynamic>? latestCriticalChange,
    DateTime? lastMessageAt,
    String? lastMessageSnippet,
    List<String>? lastMessageMentions,
  }) {
    return Event(
      id: id ?? this.id,
      type: type ?? this.type,
      hostId: hostId ?? this.hostId,
      coHostId: coHostId ?? this.coHostId,
      title: title ?? this.title,
      location: location ?? this.location,
      details: details ?? this.details,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      isPast: isPast ?? this.isPast,
      isImportantDetails: isImportantDetails ?? this.isImportantDetails,
      rsvpDeadline: rsvpDeadline ?? this.rsvpDeadline,
      keepAliveDays: keepAliveDays ?? this.keepAliveDays,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      inviteAll: inviteAll ?? this.inviteAll,
      invitedCircles: invitedCircles ?? this.invitedCircles,
      coHostInviteAll: coHostInviteAll ?? this.coHostInviteAll,
      coHostInvitedCircles: coHostInvitedCircles ?? this.coHostInvitedCircles,
      visibleTo: visibleTo ?? this.visibleTo,
      seasonId: seasonId ?? this.seasonId,
      seasonInstance: seasonInstance ?? this.seasonInstance,
      seasonTotal: seasonTotal ?? this.seasonTotal,
      pollOptions: pollOptions ?? this.pollOptions,
      lockedOptionId: lockedOptionId ?? this.lockedOptionId,
      isTieBreakerNeeded: isTieBreakerNeeded ?? this.isTieBreakerNeeded,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      latestCriticalChange: latestCriticalChange ?? this.latestCriticalChange,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSnippet: lastMessageSnippet ?? this.lastMessageSnippet,
      lastMessageMentions: lastMessageMentions ?? this.lastMessageMentions,
    );
  }
}
