import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pos/models/user.dart';

class SessionAuditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _sessionId;

  String _source() {
    if (kIsWeb) return 'Web Browser';
    return defaultTargetPlatform.name;
  }

  Future<void> startSession(UserModel user) async {
    final ref = _firestore
        .collection('vendors')
        .doc(user.id)
        .collection('auditSessions')
        .doc();

    _sessionId = ref.id;
    await ref.set({
      'sessionId': ref.id,
      'authUid': user.authUid,
      'userName': user.name,
      'email': user.email,
      'role': user.role.name,
      'department': user.department,
      'restaurantId': user.id,
      'restaurantName': user.restaurantName,
      'branchId': user.branchId,
      'branchName': user.branchName,
      'restaurantLocation': user.location,
      'source': _source(),
      'loginAt': FieldValue.serverTimestamp(),
      'logoutAt': null,
      'durationMinutes': null,
      'active': true,
    });

    await _firestore.collection('vendors').doc(user.authUid).set({
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastLoginSource': _source(),
      'lastBranchId': user.branchId,
    }, SetOptions(merge: true));
  }

  Future<void> endSession(UserModel user) async {
    DocumentReference<Map<String, dynamic>>? ref;
    if (_sessionId != null) {
      ref = _firestore.collection('vendors').doc(user.id).collection('auditSessions').doc(_sessionId);
    } else {
      final active = await _firestore
          .collection('vendors')
          .doc(user.id)
          .collection('auditSessions')
          .where('authUid', isEqualTo: user.authUid)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      if (active.docs.isNotEmpty) ref = active.docs.first.reference;
    }
    if (ref == null) return;

    final snap = await ref.get();
    final loginAt = snap.data()?['loginAt'];
    int? minutes;
    if (loginAt is Timestamp) {
      minutes = DateTime.now().difference(loginAt.toDate()).inMinutes;
    }

    await ref.set({
      'logoutAt': FieldValue.serverTimestamp(),
      'durationMinutes': minutes,
      'active': false,
    }, SetOptions(merge: true));
    _sessionId = null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> todaySessions(String restaurantId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _firestore
        .collection('vendors')
        .doc(restaurantId)
        .collection('auditSessions')
        .where('loginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('loginAt', descending: true)
        .snapshots();
  }
}
