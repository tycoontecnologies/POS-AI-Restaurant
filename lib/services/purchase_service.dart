import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/models/purchase.dart';

class PurchaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String getCurrentVendorId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  String _getVendorPurchasesPath(String vendorId) {
    return 'vendors/$vendorId/purchases';
  }

  Stream<List<Purchase>> getPurchasesStream({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    final vendorId = getCurrentVendorId();
    Query query = _firestore
        .collection(_getVendorPurchasesPath(vendorId))
        .orderBy('createdOn', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Purchase.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Purchase> addPurchase(Purchase purchase) async {
    final vendorId = getCurrentVendorId();
    final docRef = _firestore.collection(_getVendorPurchasesPath(vendorId)).doc();

    final purchaseWithId = purchase.copyWith(id: docRef.id);
    await docRef.set(purchaseWithId.toJson());
    
    return purchaseWithId;
  }

  Future<void> updatePurchase(Purchase purchase) async {
    final vendorId = getCurrentVendorId();
    await _firestore
        .collection(_getVendorPurchasesPath(vendorId))
        .doc(purchase.id)
        .update(purchase.toJson());
  }

  Future<void> deletePurchase(String purchaseId) async {
    final vendorId = getCurrentVendorId();
    await _firestore
        .collection(_getVendorPurchasesPath(vendorId))
        .doc(purchaseId)
        .delete();
  }

  Future<Purchase?> getPurchaseById(String purchaseId) async {
    final vendorId = getCurrentVendorId();
    final doc = await _firestore
        .collection(_getVendorPurchasesPath(vendorId))
        .doc(purchaseId)
        .get();
    
    if (doc.exists) {
      return Purchase.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}