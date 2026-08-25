import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/user.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> publish({
    required UserModel actor,
    required String type,
    required String title,
    required String message,
    String severity = 'info',
    String? targetAuthUid,
    List<String> targetRoles = const [],
    Map<String, dynamic> metadata = const {},
  }) async {
    await _firestore.collection('vendors').doc(actor.id).collection('notifications').add({
      'type': type,
      'title': title,
      'message': message,
      'severity': severity,
      'actorAuthUid': actor.authUid,
      'actorName': actor.name,
      'actorRole': actor.role.name,
      'targetAuthUid': targetAuthUid,
      'targetRoles': targetRoles,
      'branchId': actor.branchId,
      'branchName': actor.branchName,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': <String>[],
      'dismissedBy': <String>[],
      'clearedBy': <String>[],
      'metadata': metadata,
    });
  }

  /// Acknowledge a notification. It remains in history as read, while the
  /// floating new-notification rail closes immediately for this user.
  Future<void> markRead({
    required String restaurantId,
    required String notificationId,
    required String authUid,
  }) async {
    await _firestore.collection('vendors').doc(restaurantId).collection('notifications').doc(notificationId).set({
      'readBy': FieldValue.arrayUnion([authUid]),
      'dismissedBy': FieldValue.arrayUnion([authUid]),
      'lastAcknowledgedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> dismiss({
    required String restaurantId,
    required String notificationId,
    required String authUid,
  }) async {
    await markRead(restaurantId: restaurantId, notificationId: notificationId, authUid: authUid);
  }

  /// Clears notifications from one user's history view without deleting the
  /// audit record. start is inclusive and end is exclusive.
  Future<void> clearForUser({
    required String restaurantId,
    required String authUid,
    DateTime? start,
    DateTime? end,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('vendors').doc(restaurantId).collection('notifications');
    if (start != null) query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    if (end != null) query = query.where('createdAt', isLessThan: Timestamp.fromDate(end));

    final snapshot = await query.get();
    const chunkSize = 400;
    for (var offset = 0; offset < snapshot.docs.length; offset += chunkSize) {
      final batch = _firestore.batch();
      final slice = snapshot.docs.skip(offset).take(chunkSize);
      for (final doc in slice) {
        batch.set(doc.reference, {
          'clearedBy': FieldValue.arrayUnion([authUid]),
          'readBy': FieldValue.arrayUnion([authUid]),
          'dismissedBy': FieldValue.arrayUnion([authUid]),
          'lastClearedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }
}
