import 'package:cloud_firestore/cloud_firestore.dart';

class Invitation {
  final String uid;
  final String eventId;
  final String status; // 'going', 'declined', 'pending'
  final bool isHidden;
  final bool isMuted;
  final DateTime? respondedAt;
  final DateTime? lastReadChat;
  final DateTime? lastViewedAt;

  const Invitation({
    required this.uid,
    required this.eventId,
    this.status = 'pending',
    this.isHidden = false,
    this.isMuted = false,
    this.respondedAt,
    this.lastReadChat,
    this.lastViewedAt,
  });

  bool get isGoing => status == 'going';
  bool get isDeclined => status == 'declined';
  bool get isPending => status == 'pending';

  factory Invitation.fromFirestore(DocumentSnapshot doc, {String? eventId}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final resolvedEventId = eventId ?? doc.reference.parent.parent?.id ?? '';
    return Invitation.fromMap(data, uid: doc.id, eventId: resolvedEventId);
  }

  factory Invitation.fromMap(
    Map<String, dynamic> data, {
    String? uid,
    String? eventId,
  }) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Invitation(
      uid: uid ?? data['uid'] ?? '',
      eventId: eventId ?? data['eventId'] ?? '',
      status: data['status'] ?? 'pending',
      isHidden: data['isHidden'] == true,
      isMuted: data['isMuted'] == true,
      respondedAt: parseDate(data['respondedAt']),
      lastReadChat: parseDate(data['lastReadChat']),
      lastViewedAt: parseDate(data['lastViewedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'status': status,
      'isHidden': isHidden,
      'isMuted': isMuted,
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      if (lastReadChat != null) 'lastReadChat': Timestamp.fromDate(lastReadChat!),
      if (lastViewedAt != null) 'lastViewedAt': Timestamp.fromDate(lastViewedAt!),
    };
  }

  Invitation copyWith({
    String? uid,
    String? eventId,
    String? status,
    bool? isHidden,
    bool? isMuted,
    DateTime? respondedAt,
    DateTime? lastReadChat,
    DateTime? lastViewedAt,
  }) {
    return Invitation(
      uid: uid ?? this.uid,
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
      isHidden: isHidden ?? this.isHidden,
      isMuted: isMuted ?? this.isMuted,
      respondedAt: respondedAt ?? this.respondedAt,
      lastReadChat: lastReadChat ?? this.lastReadChat,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
    );
  }
}
