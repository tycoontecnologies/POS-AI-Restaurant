import 'package:flutter/foundation.dart';
import '../models/discount.dart';
import '../services/discount_service.dart';

class DiscountProvider with ChangeNotifier {
  final DiscountService _discountService = DiscountService();
  List<Discount> _discounts = [];
  bool _isLoading = false;
  String? _error;

  List<Discount> get discounts => _discounts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDiscounts(String vendorId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _discounts = await _discountService.getDiscounts(vendorId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load discounts: $e';
      _discounts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<Discount>> getDiscountsStream(String vendorId) {
    return _discountService.getDiscountsStream(vendorId);
  }

  Future<void> addDiscount(Discount discount) async {
    try {
      await _discountService.addDiscount(discount);
      await loadDiscounts(discount.vendorId);
      _error = null;
    } catch (e) {
      _error = 'Failed to add discount: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateDiscount(Discount discount) async {
    try {
      await _discountService.updateDiscount(discount);
      await loadDiscounts(discount.vendorId);
      _error = null;
    } catch (e) {
      _error = 'Failed to update discount: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteDiscount(String vendorId, String discountId) async {
    try {
      await _discountService.deleteDiscount(vendorId, discountId);
      await loadDiscounts(vendorId);
      _error = null;
    } catch (e) {
      _error = 'Failed to delete discount: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> incrementUsageCount(String vendorId, String discountId) async {
    try {
      await _discountService.incrementUsageCount(vendorId, discountId);
      await loadDiscounts(vendorId);
      _error = null;
    } catch (e) {
      _error = 'Failed to increment usage count: $e';
      notifyListeners();
      rethrow;
    }
  }

  Discount? getDiscountById(String discountId) {
    return _discounts.firstWhere((discount) => discount.id == discountId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}