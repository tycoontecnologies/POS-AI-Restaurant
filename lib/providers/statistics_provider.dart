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
    'storeOuts': 0,
  };

  bool _isLoading = false;
  bool _isLoaded = false;

  Map<String, int> get statistics => _statistics;
  bool get isLoading => _isLoading;

  Future<void> loadStatistics({bool forceRefresh = false}) async {
    if (_isLoaded && !forceRefresh) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final futures = [
        _getCount('staff'),
        _getCount('products'),
        _getCount('categories'),
        _getCount('sales'),
        _getCount('suppliers'),
        _getCount('purchases'),
      ];

      final results = await Future.wait(futures);

      _statistics = {
        'staff': results[0],
        'products': results[1],
        'drafts': 0,
        'categories': results[2],
        'sales': results[3],
        'salesReturn': 0,
        'suppliers': results[4],
        'purchases': results[5],
        'purchaseReturn': 0,
        'storeOuts': 0,
      };

      _isLoaded = true;
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

      final snapshot = await _firestore
          .collection('vendors')
          .doc(user.uid)
          .collection(collection)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  void clearCache() {
    _isLoaded = false;
  }
}