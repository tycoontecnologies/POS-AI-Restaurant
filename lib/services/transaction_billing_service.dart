import 'package:cloud_firestore/cloud_firestore.dart';

/// Authoritative metering for the Rs 1 / successful receipt package.
///
/// A sale is counted once when it becomes a successful receipt. The ledger
/// document id is the sale id, which makes the operation idempotent. If that
/// sale is later cancelled/deleted before settlement, the billable counters
/// are reversed. Paid ledger rows are never silently reversed; they remain as
/// audit history and can be handled through a formal adjustment/refund flow.
class TransactionBillingService {
  final FirebaseFirestore _firestore;

  TransactionBillingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> recordSuccessfulReceipt({
    required String vendorId,
    required String saleId,
    required double saleTotal,
    String? paymentMethod,
    DateTime? completedAt,
  }) async {
    final vendorRef = _firestore.collection('vendors').doc(vendorId);
    final usageRef = vendorRef.collection('billingUsage').doc(saleId);

    await _firestore.runTransaction((tx) async {
      final vendorSnap = await tx.get(vendorRef);
      final vendor = vendorSnap.data() ?? <String, dynamic>{};
      if ((vendor['billingPlanId'] ?? '').toString() != 'perTransaction') return;

      final existing = await tx.get(usageRef);
      if (existing.exists) return; // idempotent: never count the same receipt twice

      final rate = vendor['transactionRate'] is num
          ? (vendor['transactionRate'] as num).toDouble()
          : 1.0;

      tx.set(usageRef, {
        'saleId': saleId,
        'status': 'billable',
        'rate': rate,
        'amount': rate,
        'saleTotal': saleTotal,
        'paymentMethod': paymentMethod,
        'completedAt': Timestamp.fromDate(completedAt ?? DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
      });

      tx.set(vendorRef, {
        'successfulReceiptCount': FieldValue.increment(1),
        'unbilledReceiptCount': FieldValue.increment(1),
        'transactionUsageAmount': FieldValue.increment(rate),
        'billingStatus': 'active',
        'hasActiveSubscription': true,
        'accessMode': 'full',
        'lastSuccessfulReceiptAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> reverseCancelledReceipt({
    required String vendorId,
    required String saleId,
    String reason = 'cancelled',
  }) async {
    final vendorRef = _firestore.collection('vendors').doc(vendorId);
    final usageRef = vendorRef.collection('billingUsage').doc(saleId);

    await _firestore.runTransaction((tx) async {
      final usageSnap = await tx.get(usageRef);
      if (!usageSnap.exists) return;
      final usage = usageSnap.data() ?? <String, dynamic>{};
      if ((usage['status'] ?? '').toString() != 'billable') return;

      final amount = usage['amount'] is num
          ? (usage['amount'] as num).toDouble()
          : 1.0;

      tx.set(usageRef, {
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(vendorRef, {
        'successfulReceiptCount': FieldValue.increment(-1),
        'unbilledReceiptCount': FieldValue.increment(-1),
        'transactionUsageAmount': FieldValue.increment(-amount),
        'lastUsageAdjustmentAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<Map<String, dynamic>> getUsageSummary(String vendorId) async {
    final vendor = await _firestore.collection('vendors').doc(vendorId).get();
    final data = vendor.data() ?? <String, dynamic>{};
    final rate = data['transactionRate'] is num
        ? (data['transactionRate'] as num).toDouble()
        : 1.0;
    final receipts = data['unbilledReceiptCount'] is num
        ? (data['unbilledReceiptCount'] as num).toInt()
        : 0;
    final due = data['transactionUsageAmount'] is num
        ? (data['transactionUsageAmount'] as num).toDouble()
        : receipts * rate;
    return {
      'plan': (data['billingPlanId'] ?? '').toString(),
      'rate': rate,
      'lifetimeReceipts': data['successfulReceiptCount'] is num
          ? (data['successfulReceiptCount'] as num).toInt()
          : 0,
      'unbilledReceipts': receipts,
      'amountDue': due < 0 ? 0.0 : due,
      'paidTotal': data['transactionPaidTotal'] is num
          ? (data['transactionPaidTotal'] as num).toDouble()
          : 0.0,
    };
  }
}
