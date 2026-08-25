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

  /// Marks a notification read. Floating notification rails filter on readBy,
  /// therefore this immediately removes it from the live/unread rail while it
  /// remains available in history as a read notification.
  Future<void> markRead({
    required String restaurantId,
    required String notificationId,
    required String authUid,
  }) async {
    await _firestore.collection('vendors').doc(restaurantId).collection('notifications').doc(notificationId).set({
      'readBy': FieldValue.arrayUnion([authUid]),
      'readAt.$authUid': FieldValue.serverTimestamp(),
      'lastAcknowledgedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Dismiss hides a notification from the live rail and acknowledges it as
  /// read, but does not remove it from historical audit records.
  Future<void> dismiss({
    required String restaurantId,
    required String notificationId,
    required String authUid,
  }) async {
    await _firestore.collection('vendors').doc(restaurantId).collection('notifications').doc(notificationId).set({
      'readBy': FieldValue.arrayUnion([authUid]),
      'dismissedBy': FieldValue.arrayUnion([authUid]),
      'readAt.$authUid': FieldValue.serverTimestamp(),
      'dismissedAt.$authUid': FieldValue.serverTimestamp(),
      'lastAcknowledgedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAllRead({
    required String restaurantId,
    required String authUid,
  }) async {
    final snapshot = await _firestore.collection('vendors').doc(restaurantId).collection('notifications').get();
    await _applyInChunks(snapshot.docs, (doc, batch) {
      batch.set(doc.reference, {
        'readBy': FieldValue.arrayUnion([authUid]),
        'readAt.$authUid': FieldValue.serverTimestamp(),
        'lastAcknowledgedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
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
    await _applyInChunks(snapshot.docs, (doc, batch) {
      batch.set(doc.reference, {
        'clearedBy': FieldValue.arrayUnion([authUid]),
        'readBy': FieldValue.arrayUnion([authUid]),
        'dismissedBy': FieldValue.arrayUnion([authUid]),
        'lastClearedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _applyInChunks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    void Function(QueryDocumentSnapshot<Map<String, dynamic>>, WriteBatch) apply,
  ) async {
    const chunkSize = 400;
    for (var offset = 0; offset < docs.length; offset += chunkSize) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(offset).take(chunkSize)) {
        apply(doc, batch);
      }
      await batch.commit();
    }
  }
}
