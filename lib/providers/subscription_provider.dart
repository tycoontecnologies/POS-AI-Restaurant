import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/models/user.dart';

enum SubscriptionAccessLevel { full, basic, locked }

class SubscriptionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int paymentWindowStartDay = 25;

  Future<void> updateSubscription({required String planType}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final vendorRef = _firestore.collection('vendors').doc(user.uid);

    if (planType == 'perTransaction') {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(vendorRef);
        final data = snap.data() ?? <String, dynamic>{};
        final currentAmount = (data['transactionUsageAmount'] is num)
            ? (data['transactionUsageAmount'] as num).toDouble()
            : 0.0;
        final currentReceipts = (data['unbilledReceiptCount'] is num)
            ? (data['unbilledReceiptCount'] as num).toInt()
            : 0;
        final now = DateTime.now();
        final nextDue = _lastDayOfMonth(DateTime(now.year, now.month + 1, 1));
        tx.set(vendorRef, {
          'subscriptionType': 'monthly',
          'billingPlanId': 'perTransaction',
          'transactionRate': 1,
          'hasActiveSubscription': true,
          'billingStatus': 'paid',
          'accessMode': 'full',
          'lastPaymentAt': FieldValue.serverTimestamp(),
          'lastUsagePaymentAt': FieldValue.serverTimestamp(),
          'lastUsagePaymentAmount': currentAmount,
          'lastUsagePaymentReceipts': currentReceipts,
          'transactionPaidTotal': FieldValue.increment(currentAmount),
          'transactionPaidReceiptTotal': FieldValue.increment(currentReceipts),
          'transactionUsageAmount': 0,
          'unbilledReceiptCount': 0,
          'nextPaymentDueAt': Timestamp.fromDate(nextDue),
          'paymentWindowStartDay': paymentWindowStartDay,
        }, SetOptions(merge: true));
      });
      notifyListeners();
      return;
    }

    final subscriptionType = _parseSubscriptionType(planType);
    final endsAt = _calculateSubscriptionEndDate(planType);
    await vendorRef.set({
      'subscriptionType': subscriptionType.toString().split('.').last,
      'subscriptionEndsAt': Timestamp.fromDate(endsAt),
      'hasActiveSubscription': true,
      'billingPlanId': planType,
      'billingStatus': 'paid',
      'accessMode': 'full',
      'lastPaymentAt': FieldValue.serverTimestamp(),
      'nextPaymentDueAt': planType == 'monthly' ? Timestamp.fromDate(_lastDayOfMonth(DateTime(DateTime.now().year, DateTime.now().month + 1, 1))) : null,
      'paymentWindowStartDay': paymentWindowStartDay,
    }, SetOptions(merge: true));
    notifyListeners();
  }

  SubscriptionType _parseSubscriptionType(String planType) {
    switch (planType) {
      case 'monthly': return SubscriptionType.monthly;
      case 'yearly': return SubscriptionType.yearly;
      case 'fiveYears': return SubscriptionType.lifetime;
      default: return SubscriptionType.monthly;
    }
  }

  DateTime _calculateSubscriptionEndDate(String planType) {
    final now = DateTime.now();
    switch (planType) {
      case 'monthly': return DateTime(now.year, now.month + 1, now.day);
      case 'yearly': return DateTime(now.year + 1, now.month, now.day);
      case 'fiveYears': return DateTime(now.year + 5, now.month, now.day);
      default: return DateTime(now.year, now.month + 1, now.day);
    }
  }

  static DateTime _lastDayOfMonth(DateTime date) => DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  DateTime _paymentWindowStart(DateTime date) => DateTime(date.year, date.month, paymentWindowStartDay);

  bool isMonthlyPaymentWindow(DateTime now) => !now.isBefore(_paymentWindowStart(now)) && !now.isAfter(_lastDayOfMonth(now));

  Future<SubscriptionAccessLevel> getAccessLevel() async {
    final user = _auth.currentUser;
    if (user == null) return SubscriptionAccessLevel.locked;
    final doc = await _firestore.collection('vendors').doc(user.uid).get();
    if (!doc.exists) return SubscriptionAccessLevel.locked;
    final data = doc.data() ?? <String, dynamic>{};
    final now = DateTime.now();

    final override = (data['accessModeOverride'] ?? '').toString();
    if (override == 'full') return SubscriptionAccessLevel.full;
    if (override == 'basic') return SubscriptionAccessLevel.basic;
    if (override == 'locked') return SubscriptionAccessLevel.locked;

    final billingPlanId = (data['billingPlanId'] ?? '').toString();
    final billingStatus = (data['billingStatus'] ?? '').toString().toLowerCase();
    final explicitMode = (data['accessMode'] ?? '').toString();
    final dueRaw = data['nextPaymentDueAt'];
    final dueAt = dueRaw is Timestamp ? dueRaw.toDate() : null;

    if (billingPlanId == 'perTransaction') {
      if (dueAt != null && now.isAfter(dueAt) && billingStatus != 'paid') {
        return SubscriptionAccessLevel.basic;
      }
      if (explicitMode == 'basic') return SubscriptionAccessLevel.basic;
      if (billingStatus == 'active' || billingStatus == 'paid') return SubscriptionAccessLevel.full;
    }

    if (billingPlanId == 'monthly') {
      if (dueAt != null && now.isAfter(dueAt) && billingStatus != 'paid') return SubscriptionAccessLevel.basic;
      if (explicitMode == 'basic') return SubscriptionAccessLevel.basic;
    }

    final userData = UserModel.fromMap(data, doc.id);
    if (userData.subscriptionType == SubscriptionType.trial) {
      if (userData.effectiveTrialEndsAt.isAfter(now)) return SubscriptionAccessLevel.full;
      if (billingStatus != 'paid' && billingStatus != 'active') return SubscriptionAccessLevel.locked;
    }

    if (userData.subscriptionEndsAt != null && !userData.subscriptionEndsAt!.isAfter(now)) {
      return billingPlanId == 'monthly' || billingPlanId == 'perTransaction'
          ? SubscriptionAccessLevel.basic
          : SubscriptionAccessLevel.locked;
    }

    if (userData.hasActiveSubscription || billingStatus == 'paid' || billingStatus == 'active') {
      return SubscriptionAccessLevel.full;
    }

    return SubscriptionAccessLevel.basic;
  }

  Future<bool> hasValidSubscription() async => (await getAccessLevel()) != SubscriptionAccessLevel.locked;
  Future<bool> isBasicMode() async => (await getAccessLevel()) == SubscriptionAccessLevel.basic;
  Future<bool> checkSubscriptionStatus() async => hasValidSubscription();

  Future<void> activatePerTransactionPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final due = _lastDayOfMonth(now);
    await _firestore.collection('vendors').doc(user.uid).set({
      'subscriptionType': 'monthly',
      'billingPlanId': 'perTransaction',
      'transactionRate': 1,
      'successfulReceiptCount': FieldValue.increment(0),
      'unbilledReceiptCount': FieldValue.increment(0),
      'transactionUsageAmount': FieldValue.increment(0),
      'billingStatus': 'active',
      'accessMode': 'full',
      'hasActiveSubscription': true,
      'packageActivatedAt': FieldValue.serverTimestamp(),
      'nextPaymentDueAt': Timestamp.fromDate(due),
      'paymentWindowStartDay': paymentWindowStartDay,
    }, SetOptions(merge: true));
    notifyListeners();
  }

  Future<void> markMonthlyPaymentPaid() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final nextDue = _lastDayOfMonth(nextMonth);
    await _firestore.collection('vendors').doc(user.uid).set({
      'billingStatus': 'paid',
      'accessMode': 'full',
      'lastPaymentAt': FieldValue.serverTimestamp(),
      'nextPaymentDueAt': Timestamp.fromDate(nextDue),
      'subscriptionEndsAt': Timestamp.fromDate(nextDue),
    }, SetOptions(merge: true));
    notifyListeners();
  }
}
