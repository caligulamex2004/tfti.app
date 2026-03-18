import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String hostId;
  final String title;
  final String location;
  final DateTime time;

  // --- NEW FIELDS ---
  final String details;
  final List<String> visibleTo;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final Map<String, dynamic>? latestCriticalChange;
  final DateTime? lastMessageAt;
  final String? lastMessageSnippet;

  Event({
    required this.id,
    required this.hostId,
    required this.title,
    required this.location,
    required this.time,
    this.details = '',
    this.visibleTo = const [],
    this.createdAt,
    this.lastUpdatedAt,
    this.latestCriticalChange,
    this.lastMessageAt,
    this.lastMessageSnippet,
  });

  // Convert our Object -> JSON for Firestore
  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'title': title,
      'location': location,
      'time': Timestamp.fromDate(time),
      'details': details,
      'visibleTo': visibleTo,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (lastUpdatedAt != null)
        'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt!),
      if (latestCriticalChange != null)
        'latestCriticalChange': latestCriticalChange,
      if (lastMessageAt != null)
        'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      if (lastMessageSnippet != null) 'lastMessageSnippet': lastMessageSnippet,
    };
  }

  // Convert JSON from Firestore -> our Object
  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return Event(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      title: data['title'] ?? '',
      location: data['location'] ?? '',
      // Safely parse the timestamp
      time: data['time'] != null
          ? (data['time'] as Timestamp).toDate()
          : DateTime.now(),

      // Safely parse the new fields
      details: data['details'] ?? data['description'] ?? '',
      visibleTo: List<String>.from(data['visibleTo'] ?? []),
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : null,
      lastUpdatedAt: data['lastUpdatedAt'] != null
          ? (data['lastUpdatedAt'] as Timestamp).toDate()
          : null,
      latestCriticalChange:
          data['latestCriticalChange'] as Map<String, dynamic>?,
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      lastMessageSnippet: data['lastMessageSnippet'] as String?,
    );
  }
}
