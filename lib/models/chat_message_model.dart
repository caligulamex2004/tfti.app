import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String eventId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final int? senderColor;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final List<String> mentionedUids;
  final Map<String, List<String>> reactions;
  final List<Map<String, dynamic>> readBy;
  final String type; // 'text', 'image', 'system'

  const ChatMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    this.senderColor,
    required this.text,
    this.imageUrl,
    required this.timestamp,
    this.mentionedUids = const [],
    this.reactions = const {},
    this.readBy = const [],
    this.type = 'text',
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get isSystem => type == 'system';
  bool isFromUser(String uid) => senderId == uid;

  factory ChatMessage.fromFirestore(DocumentSnapshot doc, {String? eventId}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final resolvedEventId = eventId ?? doc.reference.parent.parent?.id ?? '';
    return ChatMessage.fromMap(data, id: doc.id, eventId: resolvedEventId);
  }

  factory ChatMessage.fromMap(
    Map<String, dynamic> data, {
    String? id,
    String? eventId,
  }) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final rawReactions = data['reactions'];
    final Map<String, List<String>> parsedReactions = {};
    if (rawReactions is Map) {
      rawReactions.forEach((key, val) {
        if (val is List) {
          parsedReactions[key.toString()] = List<String>.from(val);
        }
      });
    }

    return ChatMessage(
      id: id ?? data['id'] ?? '',
      eventId: eventId ?? data['eventId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Guest',
      senderAvatarUrl: data['senderAvatarUrl'],
      senderColor: data['senderColor'] is int ? data['senderColor'] : null,
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: parseDate(data['timestamp'] ?? data['createdAt']),
      mentionedUids: data['mentionedUids'] is List
          ? List<String>.from(data['mentionedUids'])
          : const [],
      reactions: parsedReactions,
      readBy: data['readBy'] is List
          ? List<Map<String, dynamic>>.from(
              (data['readBy'] as List).whereType<Map<String, dynamic>>(),
            )
          : const [],
      type: data['type'] ?? 'text',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'senderColor': senderColor,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': Timestamp.fromDate(timestamp),
      'mentionedUids': mentionedUids,
      'reactions': reactions,
      'readBy': readBy,
      'type': type,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? eventId,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    int? senderColor,
    String? text,
    String? imageUrl,
    DateTime? timestamp,
    List<String>? mentionedUids,
    Map<String, List<String>>? reactions,
    List<Map<String, dynamic>>? readBy,
    String? type,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      senderColor: senderColor ?? this.senderColor,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      mentionedUids: mentionedUids ?? this.mentionedUids,
      reactions: reactions ?? this.reactions,
      readBy: readBy ?? this.readBy,
      type: type ?? this.type,
    );
  }
}
