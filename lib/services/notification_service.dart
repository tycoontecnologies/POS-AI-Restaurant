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
    await _firestore
        .collection('vendors')
        .doc(actor.id)
        .collection('notifications')
        .add({
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
      'metadata': metadata,
    });
  }

  Future<void> markRead({
    required String restaurantId,
    required String notificationId,
    required String authUid,
  }) async {
    await _firestore
        .collection('vendors')
        .doc(restaurantId)
        .collection('notifications')
        .doc(notificationId)
        .set({
      'readBy': FieldValue.arrayUnion([authUid]),
    }, SetOptions(merge: true));
  }
}
