import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/billing_plan.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> assignPlan({
    required String vendorId,
    required BillingPlan plan,
  }) async {
    final now = DateTime.now();
    DateTime? endsAt;
    switch (plan.type) {
      case BillingPlanType.monthly:
        endsAt = DateTime(now.year, now.month + 1, now.day, now.hour, now.minute);
        break;
      case BillingPlanType.yearly:
        endsAt = DateTime(now.year + 1, now.month, now.day, now.hour, now.minute);
        break;
      case BillingPlanType.fiveYears:
        endsAt = DateTime(now.year + 5, now.month, now.day, now.hour, now.minute);
        break;
      case BillingPlanType.perTransaction:
        endsAt = null;
        break;
    }

    final ref = _firestore.collection('vendors').doc(vendorId);
    await ref.set({
      'billingPlanId': plan.id,
      'billingPlanName': plan.title,
      'billingPrice': plan.price,
      'billingPeriod': plan.period,
      'billingStatus': 'selected',
      'billingSelectedAt': FieldValue.serverTimestamp(),
      'subscriptionEndsAt': endsAt == null ? null : Timestamp.fromDate(endsAt),
      'billableReceiptCount': 0,
      'cancelledReceiptCount': 0,
      'transactionCharges': 0,
    }, SetOptions(merge: true));

    await ref.collection('subscriptionHistory').add({
      'planId': plan.id,
      'planName': plan.title,
      'price': plan.price,
      'period': plan.period,
      'status': 'selected',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSubscription(String vendorId) =>
      _firestore.collection('vendors').doc(vendorId).snapshots();
}
