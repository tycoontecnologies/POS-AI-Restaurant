import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/models/user.dart';

/// Access level used by the router/UI.
/// full  = normal subscribed POS
/// basic = payment overdue; only essential/basic features should remain available
/// locked = no authenticated/subscription access
nenum SubscriptionAccessLevel { full, basic, locked }

class SubscriptionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int paymentWindowStartDay = 25;

  Future<void> updateSubscription({required String planType}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final subscriptionType = _parseSubscriptionType(planType);
    final endsAt = _calculateSubscriptionEndDate(planType);

    await _firestore.collection('vendors').doc(user.uid).set({
      'subscriptionType': subscriptionType.toString().split('.').last,
      'subscriptionEndsAt': Timestamp.fromDate(endsAt),
      'hasActiveSubscription': true,
      'billingStatus': 'paid',
      'accessMode': 'full',
      'lastPaymentAt': FieldValue.serverTimestamp(),
      'paymentWindowStartDay': paymentWindowStartDay,
    }, SetOptions(merge: true));

    notifyListeners();
  }

  SubscriptionType _parseSubscriptionType(String planType) {
    switch (planType) {
      case 'monthly':
        return SubscriptionType.monthly;
      case 'yearly':
        return SubscriptionType.yearly;
      case 'fiveYears':
      case 'lifetime':
        return SubscriptionType.lifetime;
      default:
        return SubscriptionType.monthly;
    }
  }

  DateTime _calculateSubscriptionEndDate(String planType) {
    final now = DateTime.now();
    switch (planType) {
      case 'monthly':
        return DateTime(now.year, now.month + 1, now.day);
      case 'yearly':
        return DateTime(now.year + 1, now.month, now.day);
      case 'fiveYears':
        return DateTime(now.year + 5, now.month, now.day);
      case 'lifetime':
        return DateTime(now.year + 100, now.month, now.day);
      default:
        return DateTime(now.year, now.month + 1, now.day);
    }
  }

  DateTime _lastDayOfMonth(DateTime date) => DateTime(date.year, date.month + 1, 0, 23, 59, 59);

  DateTime _paymentWindowStart(DateTime date) => DateTime(date.year, date.month, paymentWindowStartDay);

  /// Monthly customers can pay from the 25th through the final day of the month.
  bool isMonthlyPaymentWindow(DateTime now) =>
      !now.isBefore(_paymentWindowStart(now)) && !now.isAfter(_lastDayOfMonth(now));

  Future<SubscriptionAccessLevel> getAccessLevel() async {
    final user = _auth.currentUser;
    if (user == null) return SubscriptionAccessLevel.locked;

    final doc = await _firestore.collection('vendors').doc(user.uid).get();
    if (!doc.exists) return SubscriptionAccessLevel.locked;
    final data = doc.data() ?? <String, dynamic>{};
    final now = DateTime.now();

    // Explicit Super Admin override always wins.
    final override = (data['accessModeOverride'] ?? '').toString();
    if (override == 'full') return SubscriptionAccessLevel.full;
    if (override == 'basic') return SubscriptionAccessLevel.basic;
    if (override == 'locked') return SubscriptionAccessLevel.locked;

    final billingPlanId = (data['billingPlanId'] ?? '').toString();
    final billingStatus = (data['billingStatus'] ?? '').toString().toLowerCase();

    // Monthly plan: payment is due by the last calendar day. From the first day
    // of the next month an unpaid account is downgraded to Basic Mode.
    if (billingPlanId == 'monthly') {
      final dueRaw = data['nextPaymentDueAt'];
      final dueAt = dueRaw is Timestamp ? dueRaw.toDate() : null;
      if (dueAt != null && now.isAfter(dueAt) && billingStatus != 'paid') {
        return SubscriptionAccessLevel.basic;
      }
      if ((data['accessMode'] ?? '').toString() == 'basic') {
        return SubscriptionAccessLevel.basic;
      }
    }

    final userData = UserModel.fromMap(data, doc.id);
    if (userData.subscriptionType == SubscriptionType.trial) {
      return userData.trialEndsAt.isAfter(now)
          ? SubscriptionAccessLevel.full
          : SubscriptionAccessLevel.basic;
    }
    if (userData.subscriptionEndsAt != null && !userData.subscriptionEndsAt!.isAfter(now)) {
      return SubscriptionAccessLevel.basic;
    }
    return userData.hasActiveSubscription || billingPlanId == 'perTransaction'
        ? SubscriptionAccessLevel.full
        : SubscriptionAccessLevel.basic;
  }

  Future<bool> hasValidSubscription() async =>
      (await getAccessLevel()) != SubscriptionAccessLevel.locked;

  Future<bool> isBasicMode() async =>
      (await getAccessLevel()) == SubscriptionAccessLevel.basic;

  Future<bool> checkSubscriptionStatus() async => hasValidSubscription();

  /// Call after a successful monthly payment. It opens the next billing cycle
  /// and restores full access immediately.
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
