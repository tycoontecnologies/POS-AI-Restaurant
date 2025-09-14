import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatisticsProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, int> _statistics = {
    'staff': 0,
    'products': 0,
    'drafts': 0,
    'categories': 0,
    'sales': 0,
    'salesReturn': 0,
    'suppliers': 0,
    'purchases': 0,
    'purchaseReturn': 0,
    'storeOuts': 0, // Add storeOuts
  };

  Map<String, int> get statistics => _statistics;
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  Future<void> loadStatistics() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Listen to all collections simultaneously
      final futures = [
        _getCount('staff'),
        _getCount('products'),
        _getCount('drafts'),
        _getCount('categories'),
        _getCount('sales'),
        _getCount('sales_return'),
        _getCount('suppliers'),
        _getCount('purchases'),
        _getCount('purchase_return'),
        _getCount('store_outs'), // Add store_outs count
      ];

      final results = await Future.wait(futures);

      _statistics = {
        'staff': results[0],
        'products': results[1],
        'drafts': results[2],
        'categories': results[3],
        'sales': results[4],
        'salesReturn': results[5],
        'suppliers': results[6],
        'purchases': results[7],
        'purchaseReturn': results[8],
        'storeOuts': results[9], // Add storeOuts
      };
    } catch (e) {
      log('Error loading statistics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> _getCount(String collection) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final collectionPath = 'vendors/${user.uid}/$collection';

      Query query = _firestore.collection(collectionPath);

      // For store_outs, drafts, purchases, and sales, we might not have an 'active' field
      if (collection != 'store_outs' &&
          collection != 'drafts' &&
          collection != 'purchases' &&
          collection != 'sales') {
        query = query.where('active', isEqualTo: true);
      }

      final snapshot = await query.count().get();
      final count = snapshot.count ?? 0;

      return count;
    } catch (e) {
      return 0;
    }
  }

  // Stream for real-time updates
  Stream<Map<String, int>> get statisticsStream {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(_statistics);

    return _firestore
        .collection('vendors/${user.uid}')
        .snapshots()
        .asyncMap((_) => _updateAllStatistics());
  }

  Future<Map<String, int>> _updateAllStatistics() async {
    await loadStatistics();
    return _statistics;
  }
}
