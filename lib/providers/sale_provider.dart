import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale.dart';
import '../services/sale_service.dart';

class SaleProvider with ChangeNotifier {
  final SaleService _saleService = SaleService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Sale> _sales = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _salesSubscription;
  String? _listeningVendorId;

  List<Sale> get sales => _sales;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> createSale(String vendorId, Sale sale) async {
    try {
      _error = null;
      await _saleService.createSale(vendorId, sale);
      if (_listeningVendorId != vendorId) {
        _sales.insert(0, sale);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchSales(String vendorId) async {
    if (_listeningVendorId == vendorId && _salesSubscription != null) return;
    await _salesSubscription?.cancel();
    _listeningVendorId = vendorId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _salesSubscription = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _sales = snapshot.docs.map((doc) => Sale.fromMap(doc.data())).toList();
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object error) {
      _isLoading = false;
      _error = error.toString();
      notifyListeners();
    });
  }

  Future<void> updateSale(String vendorId, Sale sale) async {
    try {
      await _saleService.updateSale(vendorId, sale);
      if (_listeningVendorId != vendorId) {
        final index = _sales.indexWhere((s) => s.id == sale.id);
        if (index != -1) _sales[index] = sale;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSale(String vendorId, String saleId) async {
    try {
      await _saleService.deleteSale(vendorId, saleId);
      if (_listeningVendorId != vendorId) {
        _sales.removeWhere((s) => s.id == saleId);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearSales() {
    _sales.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    super.dispose();
  }
}
