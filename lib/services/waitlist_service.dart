import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WaitlistService {
  final FirebaseFirestore? _firestore;

  WaitlistService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  /// Submits an email address to the mobile app waitlist.
  /// [platform] should be one of 'ios', 'android', or 'both'.
  Future<void> joinWaitlist({
    required String email,
    String platform = 'both',
    String source = 'web_login',
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    
    // Basic client-side email format check
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(cleanEmail)) {
      throw ArgumentError('Please enter a valid email address.');
    }

    if (!['ios', 'android', 'both'].contains(platform)) {
      platform = 'both';
    }

    // In web, defaultTargetPlatform gives the OS running the browser
    final targetOS = kIsWeb ? defaultTargetPlatform.name : 'unknown';

    await _db.collection('mobile_waitlist').add({
      'email': cleanEmail,
      'platform': platform,
      'createdAt': FieldValue.serverTimestamp(),
      'source': source,
      'userAgent': 'web_$targetOS',
    });
  }
}
