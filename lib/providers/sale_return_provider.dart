import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/sale_return.dart';
import '../services/sale_return_service.dart';

class SaleReturnProvider with ChangeNotifier {
  final SaleReturnService _saleReturnService = SaleReturnService();
  List<SaleReturn> _saleReturns = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String? _error;

  List<SaleReturn> get saleReturns => _saleReturns;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> createSaleReturn(String vendorId, SaleReturn saleReturn) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _saleReturnService.createSaleReturn(vendorId, saleReturn);

      // Refresh the list to include the new sale return
      await _refreshSaleReturns(vendorId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchSaleReturns(
    String vendorId, {
    bool loadMore = false,
  }) async {
    try {
      if (!loadMore) {
        _isLoading = true;
        _lastDocument = null;
        _hasMore = true;
        _error = null;
        notifyListeners();
      }

      final saleReturns = await _saleReturnService.getSaleReturns(
        vendorId,
        limit: 20,
        lastDocument: _lastDocument,
      );

      if (loadMore) {
        _saleReturns.addAll(saleReturns);
      } else {
        _saleReturns = saleReturns;
      }

      // Update pagination state
      _hasMore = saleReturns.length == 20;
      if (saleReturns.isNotEmpty) {
        _lastDocument = await _getLastDocument(vendorId, saleReturns.last);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _refreshSaleReturns(String vendorId) async {
    _lastDocument = null;
    _hasMore = true;
    _error = null;
    await fetchSaleReturns(vendorId);
  }

  Future<DocumentSnapshot> _getLastDocument(
    String vendorId,
    SaleReturn lastSaleReturn,
  ) async {
    return await _saleReturnService.getSaleReturnDocument(
      vendorId,
      lastSaleReturn.id,
    );
  }

  Future<void> updateSaleReturn(String vendorId, SaleReturn saleReturn) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _saleReturnService.updateSaleReturn(vendorId, saleReturn);

      // Update local list
      final index = _saleReturns.indexWhere((sr) => sr.id == saleReturn.id);
      if (index != -1) {
        _saleReturns[index] = saleReturn;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSaleReturn(String vendorId, String saleReturnId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _saleReturnService.deleteSaleReturn(vendorId, saleReturnId);

      // Remove from local list
      _saleReturns.removeWhere((sr) => sr.id == saleReturnId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void clearSaleReturns() {
    _saleReturns.clear();
    _lastDocument = null;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }
}
