import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/draft.dart';

class DraftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Query getDraftsQuery(String vendorId, {int limit = 10, DocumentSnapshot? lastDocument}) {
    Query query = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('drafts')
        .orderBy('date', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query;
  }

  Stream<List<Draft>> streamDrafts(String vendorId, {int limit = 10}) {
    return getDraftsQuery(vendorId, limit: limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Draft.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<List<Draft>> getDrafts(String vendorId, {int limit = 10, DocumentSnapshot? lastDocument}) async {
    final query = getDraftsQuery(vendorId, limit: limit, lastDocument: lastDocument);
    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => Draft.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<Draft?> getDraft(String vendorId, String draftId) async {
    final doc = await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('drafts')
        .doc(draftId)
        .get();

    if (doc.exists) {
      return Draft.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<String> createDraft(String vendorId, Draft draft) async {
    final docRef = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('drafts')
        .doc();

    final draftWithId = Draft(
      id: docRef.id,
      vendorId: vendorId,
      type: draft.type,
      items: draft.items,
      total: draft.total,
      date: draft.date,
      status: draft.status,
      cartItems: draft.cartItems,
    );

    await docRef.set(draftWithId.toMap());
    return docRef.id;
  }

  Future<void> updateDraft(String vendorId, Draft draft) async {
    await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('drafts')
        .doc(draft.id)
        .update(draft.toMap());
  }

  Future<void> deleteDraft(String vendorId, String draftId) async {
    await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('drafts')
        .doc(draftId)
        .delete();
  }

  Future<List<Draft>> searchDrafts(String vendorId, String query) async {
    final snapshot = await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('drafts')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Draft.fromMap(doc.data(), doc.id))
        .where((draft) =>
            draft.id.toLowerCase().contains(query.toLowerCase()) ||
            draft.type.toLowerCase().contains(query.toLowerCase()) ||
            draft.status.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}