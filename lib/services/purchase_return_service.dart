// purchase_return_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/purchase_return.dart';

class PurchaseReturnService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _getVendorPurchaseReturnsPath(String vendorId) {
    return 'vendors/$vendorId/purchase_returns';
  }

  Future<String> createPurchaseReturn(
    String vendorId,
    PurchaseReturn purchaseReturn,
  ) async {
    try {
      final docRef = _firestore
          .collection(_getVendorPurchaseReturnsPath(vendorId))
          .doc();

      // Create a new purchase return with auto-generated ID
      final newPurchaseReturn = PurchaseReturn(
        id: docRef.id,
        vendorId: vendorId,
        originalPurchaseId: purchaseReturn.originalPurchaseId,
        supplierId: purchaseReturn.supplierId,
        supplierName: purchaseReturn.supplierName,
        items: purchaseReturn.items,
        totalRefund: purchaseReturn.totalRefund,
        reason: purchaseReturn.reason,
        createdAt: purchaseReturn.createdAt,
      );

      await docRef.set(newPurchaseReturn.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create purchase return: $e');
    }
  }

  Future<List<PurchaseReturn>> getPurchaseReturns(
    String vendorId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_getVendorPurchaseReturnsPath(vendorId))
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => PurchaseReturn.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch purchase returns: $e');
    }
  }

  Future<PurchaseReturn?> getPurchaseReturn(
    String vendorId,
    String purchaseReturnId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_getVendorPurchaseReturnsPath(vendorId))
          .doc(purchaseReturnId)
          .get();

      return doc.exists ? PurchaseReturn.fromMap(doc.data()!) : null;
    } catch (e) {
      throw Exception('Failed to fetch purchase return: $e');
    }
  }

  Future<void> updatePurchaseReturn(String vendorId, PurchaseReturn purchaseReturn) async {
    try {
      await _firestore
          .collection(_getVendorPurchaseReturnsPath(vendorId))
          .doc(purchaseReturn.id)
          .update(purchaseReturn.toMap());
    } catch (e) {
      throw Exception('Failed to update purchase return: $e');
    }
  }

  Future<void> deletePurchaseReturn(String vendorId, String purchaseReturnId) async {
    try {
      await _firestore
          .collection(_getVendorPurchaseReturnsPath(vendorId))
          .doc(purchaseReturnId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete purchase return: $e');
    }
  }

  Future<int> getTotalPurchaseReturnsCount(String vendorId) async {
    try {
      final snapshot = await _firestore
          .collection(_getVendorPurchaseReturnsPath(vendorId))
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get purchase returns count: $e');
    }
  }

  Future<DocumentSnapshot> getPurchaseReturnDocument(
    String vendorId,
    String purchaseReturnId,
  ) async {
    return await _firestore
        .collection(_getVendorPurchaseReturnsPath(vendorId))
        .doc(purchaseReturnId)
        .get();
  }
}