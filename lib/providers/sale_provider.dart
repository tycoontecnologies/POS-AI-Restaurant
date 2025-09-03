import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../services/sale_service.dart';

class SaleProvider with ChangeNotifier {
  final SaleService _saleService = SaleService();
  List<Sale> _sales = [];
  bool _isLoading = false;

  List<Sale> get sales => _sales;
  bool get isLoading => _isLoading;

  Future<void> createSale(String vendorId, Sale sale) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _saleService.createSale(vendorId, sale);
      
      // Add to local list
      _sales.insert(0, sale);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchSales(String vendorId) async {
    try {
      _isLoading = true;
      notifyListeners();

      _sales = await _saleService.getSales(vendorId);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateSale(String vendorId, Sale sale) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _saleService.updateSale(vendorId, sale);
      
      // Update local list
      final index = _sales.indexWhere((s) => s.id == sale.id);
      if (index != -1) {
        _sales[index] = sale;
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSale(String vendorId, String saleId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _saleService.deleteSale(vendorId, saleId);
      
      // Remove from local list
      _sales.removeWhere((s) => s.id == saleId);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void clearSales() {
    _sales.clear();
    notifyListeners();
  }
}