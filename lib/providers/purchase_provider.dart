import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/purchase.dart';
import 'package:pos/services/purchase_service.dart';

class PurchaseProvider with ChangeNotifier {
  final PurchaseService _purchaseService = PurchaseService();
  List<Purchase> _purchases = [];
  List<Purchase> _filteredPurchases = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String _searchQuery = '';
  String? _error;
  String? get error => _error;

  List<Purchase> get purchases => _filteredPurchases;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;

  Future<void> loadPurchases({bool loadMore = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    if (!loadMore) {
      _purchases.clear();
      _lastDocument = null;
      _hasMore = true;
    }

    try {
      final stream = _purchaseService
          .getPurchasesStream(limit: 20, lastDocument: _lastDocument)
          .first;

      final newPurchases = await stream;

      if (newPurchases.isNotEmpty) {
        _lastDocument = await _getLastDocument();
        if (loadMore) {
          _purchases.addAll(newPurchases);
        } else {
          _purchases = newPurchases;
        }
        _filterPurchases();
      } else {
        _hasMore = false;
      }
    } catch (e) {
      print('Error loading purchases: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadInitialPurchases() async {
    await loadPurchases(loadMore: false);
  }

  Future<void> loadMorePurchases() async {
    await loadPurchases(loadMore: true);
  }

  void searchPurchases(String query) {
    setSearchQuery(query);
  }

  Future<DocumentSnapshot?> _getLastDocument() async {
    if (_purchases.isEmpty) return null;

    final lastPurchase = _purchases.last;
    final vendorId = _purchaseService.getCurrentVendorId();
    return await FirebaseFirestore.instance
        .collection('vendors/$vendorId/purchases')
        .doc(lastPurchase.id)
        .get();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _filterPurchases();
    notifyListeners();
  }

  void _filterPurchases() {
    if (_searchQuery.isEmpty) {
      _filteredPurchases = List.from(_purchases);
    } else {
      _filteredPurchases = _purchases
          .where(
            (purchase) =>
                purchase.id.toLowerCase().contains(_searchQuery) ||
                purchase.supplierName.toLowerCase().contains(_searchQuery) ||
                purchase.status.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }
  }

  Future<Purchase> addPurchase(Purchase purchase) async {
    final newPurchase = await _purchaseService.addPurchase(purchase);
    _purchases.insert(0, newPurchase);
    _filterPurchases();
    notifyListeners();
    return newPurchase;
  }

  Future<void> updatePurchase(Purchase purchase) async {
    await _purchaseService.updatePurchase(purchase);
    final index = _purchases.indexWhere((p) => p.id == purchase.id);
    if (index != -1) {
      _purchases[index] = purchase;
      _filterPurchases();
      notifyListeners();
    }
  }

  Future<void> deletePurchase(String purchaseId) async {
    await _purchaseService.deletePurchase(purchaseId);
    _purchases.removeWhere((p) => p.id == purchaseId);
    _filterPurchases();
    notifyListeners();
  }

  void clear() {
    _purchases.clear();
    _filteredPurchases.clear();
    _lastDocument = null;
    _hasMore = true;
    _searchQuery = '';
    notifyListeners();
  }
}
