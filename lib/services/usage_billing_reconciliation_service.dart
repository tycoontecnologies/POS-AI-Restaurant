import 'package:cloud_firestore/cloud_firestore.dart';

/// Repairs and reconciles the Rs 1 / successful receipt billing ledger from
/// the authoritative completed sales collection.
///
/// One sale document == one billable receipt. Reprints do not create extra
/// charges because billingUsage is keyed by the sale/receipt id. If a sale is
/// later deleted, an unpaid ledger row is marked cancelled on reconciliation.
class UsageBillingReconciliationService {
  final FirebaseFirestore _db;
  UsageBillingReconciliationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> reconcile(String restaurantId) async {
    final vendorRef = _db.collection('vendors').doc(restaurantId);
    final vendorSnap = await vendorRef.get();
    if (!vendorSnap.exists) return;

    final vendor = vendorSnap.data() ?? <String, dynamic>{};
    final plan = (vendor['billingPlanId'] ?? '').toString();
    if (plan != 'perTransaction') return;

    final rate = vendor['transactionRate'] is num
        ? (vendor['transactionRate'] as num).toDouble()
        : 1.0;

    final salesSnap = await vendorRef.collection('sales').get();
    final usageSnap = await vendorRef.collection('billingUsage').get();
    final usageById = {for (final d in usageSnap.docs) d.id: d};
    final saleIds = <String>{};

    const batchLimit = 400;
    var batch = _db.batch();
    var pending = 0;

    Future<void> flush() async {
      if (pending == 0) return;
      await batch.commit();
      batch = _db.batch();
      pending = 0;
    }

    for (final saleDoc in salesSnap.docs) {
      final sale = saleDoc.data();
      final saleId = (sale['id'] ?? saleDoc.id).toString();
      if (saleId.isEmpty) continue;
      saleIds.add(saleId);
      if (usageById.containsKey(saleId)) continue;

      final createdRaw = sale['createdAt'];
      DateTime completedAt = DateTime.now();
      if (createdRaw is int) {
        completedAt = DateTime.fromMillisecondsSinceEpoch(createdRaw);
      } else if (createdRaw is num) {
        completedAt = DateTime.fromMillisecondsSinceEpoch(createdRaw.toInt());
      } else if (createdRaw is Timestamp) {
        completedAt = createdRaw.toDate();
      }

      final usageRef = vendorRef.collection('billingUsage').doc(saleId);
      batch.set(usageRef, {
        'receiptId': saleId,
        'saleId': saleId,
        'saleTotal': sale['total'] ?? 0,
        'paymentMethod': sale['paymentMethod'] ?? 'Cash',
        'rate': rate,
        'amount': rate,
        'billableAmount': rate,
        'status': 'billable',
        'completedAt': Timestamp.fromDate(completedAt),
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'sales_reconciliation',
      }, SetOptions(merge: true));
      pending++;
      if (pending >= batchLimit) await flush();
    }

    // A deleted completed sale must not remain billable. Paid rows are retained
    // as immutable historical billing records.
    for (final usageDoc in usageSnap.docs) {
      final data = usageDoc.data();
      final status = (data['status'] ?? 'billable').toString();
      if (status == 'billable' && !saleIds.contains(usageDoc.id)) {
        batch.set(usageDoc.reference, {
          'status': 'cancelled',
          'billableAmount': 0,
          'amount': 0,
          'cancelledAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        pending++;
        if (pending >= batchLimit) await flush();
      }
    }
    await flush();

    final fresh = await vendorRef.collection('billingUsage').get();
    var successful = 0;
    var unbilled = 0;
    var amountDue = 0.0;
    var paidReceipts = 0;
    var paidTotal = 0.0;

    for (final doc in fresh.docs) {
      final data = doc.data();
      final status = (data['status'] ?? 'billable').toString();
      final rawAmount = data['amount'] ?? data['billableAmount'] ?? data['rate'] ?? rate;
      final amount = rawAmount is num ? rawAmount.toDouble() : rate;
      if (status == 'billable') {
        successful++;
        unbilled++;
        amountDue += amount;
      } else if (status == 'paid') {
        successful++;
        paidReceipts++;
        paidTotal += amount;
      }
    }

    await vendorRef.set({
      'transactionRate': rate,
      'successfulReceiptCount': successful,
      'unbilledReceiptCount': unbilled,
      'transactionUsageAmount': amountDue,
      'transactionPaidReceiptTotal': paidReceipts,
      'transactionPaidTotal': paidTotal,
      'transactionUsageUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
