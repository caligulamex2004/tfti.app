import 'package:cloud_firestore/cloud_firestore.dart';

class SquadRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final int? avatarColor;
  final String status; // 'pending'
  final String source; // 'username', 'phone'
  final DateTime? createdAt;
  final DateTime? addedAt;

  const SquadRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.avatarColor,
    this.status = 'pending',
    this.source = 'username',
    this.createdAt,
    this.addedAt,
  });

  /// The effective creation date, supporting both createdAt and addedAt for backwards compatibility
  DateTime? get effectiveDate => createdAt ?? addedAt;

  /// Check if this request is older than the timeout period (defaults to 14 days)
  bool isExpired({Duration timeout = const Duration(days: 14), DateTime? currentTime}) {
    final date = effectiveDate;
    if (date == null) return false;
    final now = currentTime ?? DateTime.now();
    return now.difference(date) > timeout;
  }

  factory SquadRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SquadRequest.fromMap(data, id: doc.id);
  }

  factory SquadRequest.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final parsedCreated = parseDate(data['createdAt'] ?? data['created_at']);
    final parsedAdded = parseDate(data['addedAt'] ?? data['added_at']);

    return SquadRequest(
      id: id ?? data['id'] ?? data['fromUid'] ?? '',
      fromUid: data['fromUid'] ?? '',
      toUid: data['toUid'] ?? '',
      displayName: data['displayName'] ?? '',
      username: data['username'] ?? '',
      avatarUrl: data['avatarUrl'],
      avatarColor: data['avatarColor'] is int ? data['avatarColor'] : null,
      status: data['status'] ?? 'pending',
      source: data['source'] ?? 'username',
      createdAt: parsedCreated ?? parsedAdded,
      addedAt: parsedAdded ?? parsedCreated,
    );
  }

  Map<String, dynamic> toMap() {
    final effectiveTimestamp = effectiveDate != null ? Timestamp.fromDate(effectiveDate!) : null;
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'displayName': displayName,
      'username': username,
      'avatarUrl': avatarUrl,
      'avatarColor': avatarColor,
      'status': status,
      'source': source,
      'createdAt': ?effectiveTimestamp,
      'addedAt': ?effectiveTimestamp,
    };
  }

  SquadRequest copyWith({
    String? id,
    String? fromUid,
    String? toUid,
    String? displayName,
    String? username,
    String? avatarUrl,
    int? avatarColor,
    String? status,
    String? source,
    DateTime? createdAt,
    DateTime? addedAt,
  }) {
    return SquadRequest(
      id: id ?? this.id,
      fromUid: fromUid ?? this.fromUid,
      toUid: toUid ?? this.toUid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarColor: avatarColor ?? this.avatarColor,
      status: status ?? this.status,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
