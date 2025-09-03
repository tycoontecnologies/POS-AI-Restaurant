// purchase_return_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/purchase_return.dart';
import '../services/purchase_return_service.dart';

class PurchaseReturnProvider with ChangeNotifier {
  final PurchaseReturnService _purchaseReturnService = PurchaseReturnService();
  List<PurchaseReturn> _purchaseReturns = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  List<PurchaseReturn> get purchaseReturns => _purchaseReturns;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> createPurchaseReturn(String vendorId, PurchaseReturn purchaseReturn) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _purchaseReturnService.createPurchaseReturn(vendorId, purchaseReturn);
      
      // Refresh the list to include the new purchase return
      await _refreshPurchaseReturns(vendorId);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchPurchaseReturns(String vendorId, {bool loadMore = false}) async {
    try {
      if (!loadMore) {
        _isLoading = true;
        _lastDocument = null;
        _hasMore = true;
        notifyListeners();
      }

      final purchaseReturns = await _purchaseReturnService.getPurchaseReturns(
        vendorId,
        limit: 20,
        lastDocument: _lastDocument,
      );

      if (loadMore) {
        _purchaseReturns.addAll(purchaseReturns);
      } else {
        _purchaseReturns = purchaseReturns;
      }

      // Update pagination state
      _hasMore = purchaseReturns.length == 20;
      if (purchaseReturns.isNotEmpty) {
        _lastDocument = await _getLastDocument(vendorId, purchaseReturns.last);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _refreshPurchaseReturns(String vendorId) async {
    _lastDocument = null;
    _hasMore = true;
    await fetchPurchaseReturns(vendorId);
  }

  Future<DocumentSnapshot> _getLastDocument(String vendorId, PurchaseReturn lastPurchaseReturn) async {
    return await _purchaseReturnService.getPurchaseReturnDocument(vendorId, lastPurchaseReturn.id);
  }

  Future<void> updatePurchaseReturn(String vendorId, PurchaseReturn purchaseReturn) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _purchaseReturnService.updatePurchaseReturn(vendorId, purchaseReturn);
      
      // Update local list
      final index = _purchaseReturns.indexWhere((pr) => pr.id == purchaseReturn.id);
      if (index != -1) {
        _purchaseReturns[index] = purchaseReturn;
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deletePurchaseReturn(String vendorId, String purchaseReturnId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _purchaseReturnService.deletePurchaseReturn(vendorId, purchaseReturnId);
      
      // Remove from local list
      _purchaseReturns.removeWhere((pr) => pr.id == purchaseReturnId);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void clearPurchaseReturns() {
    _purchaseReturns.clear();
    _lastDocument = null;
    _hasMore = true;
    notifyListeners();
  }
}