import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale_return.dart';

class SaleReturnService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createSaleReturn(
    String vendorId,
    SaleReturn saleReturn,
  ) async {
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final saleReturnsRef = vendorRef.collection('sale_returns').doc();

      // Create a new sale return with auto-generated ID
      final newSaleReturn = SaleReturn(
        id: saleReturnsRef.id,
        vendorId: vendorId,
        originalSaleId: saleReturn.originalSaleId,
        items: saleReturn.items,
        totalRefund: saleReturn.totalRefund,
        reason: saleReturn.reason,
        createdAt: saleReturn.createdAt,
      );

      await saleReturnsRef.set(newSaleReturn.toMap());
      return saleReturnsRef.id;
    } catch (e) {
      throw Exception('Failed to create sale return: $e');
    }
  }

  Future<List<SaleReturn>> getSaleReturns(
    String vendorId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('sale_returns')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => SaleReturn.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch sale returns: $e');
    }
  }

  Future<SaleReturn?> getSaleReturn(
    String vendorId,
    String saleReturnId,
  ) async {
    try {
      final doc = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('sale_returns')
          .doc(saleReturnId)
          .get();

      return doc.exists ? SaleReturn.fromMap(doc.data()!) : null;
    } catch (e) {
      throw Exception('Failed to fetch sale return: $e');
    }
  }

  Future<void> updateSaleReturn(String vendorId, SaleReturn saleReturn) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('sale_returns')
          .doc(saleReturn.id)
          .update(saleReturn.toMap());
    } catch (e) {
      throw Exception('Failed to update sale return: $e');
    }
  }

  Future<void> deleteSaleReturn(String vendorId, String saleReturnId) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('sale_returns')
          .doc(saleReturnId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete sale return: $e');
    }
  }

  Future<int> getTotalSaleReturnsCount(String vendorId) async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('sale_returns')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get sale returns count: $e');
    }
  }

  Future<DocumentSnapshot> getSaleReturnDocument(
    String vendorId,
    String saleReturnId,
  ) async {
    return await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('sale_returns')
        .doc(saleReturnId)
        .get();
  }
}
