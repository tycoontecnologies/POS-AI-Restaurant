import 'package:flutter/foundation.dart';
import 'package:pos/models/supplier.dart';
import 'package:pos/services/supplier_service.dart';

class SupplierProvider with ChangeNotifier {
  final SupplierService _supplierService = SupplierService();
  List<Supplier> _suppliers = [];
  List<Supplier> _filteredSuppliers = [];
  bool _isLoading = true;

  List<Supplier> get suppliers => _suppliers;
  List<Supplier> get filteredSuppliers => _filteredSuppliers;
  bool get isLoading => _isLoading;

  // Load suppliers from Firebase
  Stream<List<Supplier>> getSuppliersStream() {
    return _supplierService.getSuppliersStream();
  }

  // Filter suppliers
  void filterSuppliers(String query) {
    if (query.isEmpty) {
      _filteredSuppliers = List.from(_suppliers);
    } else {
      _filteredSuppliers = _suppliers.where((supplier) {
        return supplier.name.toLowerCase().contains(query.toLowerCase()) ||
            supplier.phone.toLowerCase().contains(query.toLowerCase()) ||
            supplier.address.toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  // Set suppliers (called from stream)
  void setSuppliers(List<Supplier> suppliers) {
    _suppliers = suppliers;
    _filteredSuppliers = List.from(_suppliers);
    _isLoading = false;
    notifyListeners();
  }

  // Add supplier
  Future<void> addSupplier(Supplier supplier) async {
    await _supplierService.addSupplier(supplier);
  }

  // Update supplier
  Future<void> updateSupplier(Supplier supplier) async {
    await _supplierService.updateSupplier(supplier);
  }

  // Delete supplier
  Future<void> deleteSupplier(String supplierId) async {
    await _supplierService.deleteSupplier(supplierId);
  }
  // Add these methods to the SupplierProvider class

  // Update amount to receive
  Future<void> updateAmountToReceive(String supplierId, double amount) async {
    await _supplierService.updateAmountToReceive(supplierId, amount);

    // Update local state
    final index = _suppliers.indexWhere((s) => s.id == supplierId);
    if (index != -1) {
      _suppliers[index] = _suppliers[index].copyWith(
        amountToReceive: _suppliers[index].amountToReceive + amount,
      );
      _filteredSuppliers = List.from(_suppliers);
      notifyListeners();
    }
  }

  // Update amount to pay
  Future<void> updateAmountToPay(String supplierId, double amount) async {
    await _supplierService.updateAmountToPay(supplierId, amount);

    // Update local state
    final index = _suppliers.indexWhere((s) => s.id == supplierId);
    if (index != -1) {
      _suppliers[index] = _suppliers[index].copyWith(
        amountToPay: _suppliers[index].amountToPay + amount,
      );
      _filteredSuppliers = List.from(_suppliers);
      notifyListeners();
    }
  }

  // Reset amounts
  Future<void> resetSupplierAmounts(String supplierId) async {
    await _supplierService.resetSupplierAmounts(supplierId);

    // Update local state
    final index = _suppliers.indexWhere((s) => s.id == supplierId);
    if (index != -1) {
      _suppliers[index] = _suppliers[index].copyWith(
        amountToReceive: 0.0,
        amountToPay: 0.0,
      );
      _filteredSuppliers = List.from(_suppliers);
      notifyListeners();
    }
  }
}
