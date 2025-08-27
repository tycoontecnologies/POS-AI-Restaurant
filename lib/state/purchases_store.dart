import 'package:flutter/foundation.dart';

class Purchase {
  Purchase({
    required this.id,
    required this.invoiceNo,
    required this.supplier,
    required this.total,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();

  final String id;
  final String invoiceNo;
  final String supplier;
  final double total;
  final DateTime createdOn;
}

class PurchasesStore extends ChangeNotifier {
  PurchasesStore._internal();
  static final PurchasesStore instance = PurchasesStore._internal();

  final List<Purchase> _items = [];

  List<Purchase> get items => List.unmodifiable(_items);

  void add(Purchase p) {
    _items.add(p);
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
