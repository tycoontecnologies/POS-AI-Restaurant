import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/models/user.dart';

class SubscriptionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> updateSubscription({required String planType}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final subscriptionType = _parseSubscriptionType(planType);
    final endsAt = _calculateSubscriptionEndDate(planType);

    await _firestore.collection('vendors').doc(user.uid).update({
      'subscriptionType': subscriptionType.toString().split('.').last,
      'subscriptionEndsAt': Timestamp.fromDate(endsAt),
      'hasActiveSubscription': true,
    });

    notifyListeners();
  }

  SubscriptionType _parseSubscriptionType(String planType) {
    switch (planType) {
      case 'monthly':
        return SubscriptionType.monthly;
      case 'yearly':
        return SubscriptionType.yearly;
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
      case 'lifetime':
        return DateTime(
          now.year + 100,
          now.month,
          now.day,
        ); 
      default:
        return DateTime(now.year, now.month + 1, now.day);
    }
  }

  // Add this method to check if subscription/trial has expired
  Future<bool> hasValidSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('vendors').doc(user.uid).get();
    if (userDoc.exists) {
      final userData = UserModel.fromMap(userDoc.data()!, userDoc.id);
      final now = DateTime.now();

      if (userData.subscriptionType == SubscriptionType.trial) {
        return userData.trialEndsAt.isAfter(now);
      }

      // Check if paid subscription has ended
      if (userData.subscriptionEndsAt != null) {
        return userData.subscriptionEndsAt!.isAfter(now);
      }

      return userData.hasActiveSubscription;
    }
    return false;
  }

  Future<bool> checkSubscriptionStatus() async {
    return await hasValidSubscription();
  }
}
