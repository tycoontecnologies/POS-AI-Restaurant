import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale.dart';
import 'transaction_billing_service.dart';

class SaleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final TransactionBillingService _billing =
      TransactionBillingService(firestore: _firestore);

  Future<String> createSale(String vendorId, Sale sale) async {
    try {
      final vendorRef = _firestore.collection('vendors').doc(vendorId);
      final salesRef = vendorRef.collection('sales').doc(sale.id);

      // Write the completed sale first. Billing metering is idempotent by sale id,
      // so retries cannot double-charge the client.
      await salesRef.set(sale.toMap());
      await _billing.recordSuccessfulReceipt(
        vendorId: vendorId,
        saleId: sale.id,
        saleTotal: sale.total,
        paymentMethod: sale.paymentMethod,
        completedAt: sale.createdAt,
      );
      return sale.id;
    } catch (e) {
      throw Exception('Failed to create sale: $e');
    }
  }

  Future<List<Sale>> getSales(String vendorId) async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('sales')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Sale.fromMap(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to fetch sales: $e');
    }
  }

  Future<Sale?> getSale(String vendorId, String saleId) async {
    try {
      final doc = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('sales')
          .doc(saleId)
          .get();

      return doc.exists ? Sale.fromMap(doc.data()!) : null;
    } catch (e) {
      throw Exception('Failed to fetch sale: $e');
    }
  }

  Future<void> updateSale(String vendorId, Sale sale) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('sales')
          .doc(sale.id)
          .update(sale.toMap());
    } catch (e) {
      throw Exception('Failed to update sale: $e');
    }
  }

  /// Cancelling/deleting a completed sale reverses its Rs 1 charge only while
  /// the usage ledger row is still billable. Already-paid usage remains an
  /// auditable paid row instead of silently altering historic billing.
  Future<void> deleteSale(String vendorId, String saleId) async {
    try {
      await _billing.reverseCancelledReceipt(
        vendorId: vendorId,
        saleId: saleId,
        reason: 'sale_deleted_or_cancelled',
      );
      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('sales')
          .doc(saleId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete sale: $e');
    }
  }
}
