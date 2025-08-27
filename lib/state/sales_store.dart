import 'package:flutter/foundation.dart';

class SaleLineItem {
  SaleLineItem({
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  final String productName;
  final double unitPrice;
  final int quantity;

  double get lineTotal => unitPrice * quantity;
}

class Sale {
  Sale({
    required this.id,
    required this.invoiceNo,
    required this.customer,
    required this.lines,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();

  final String id;
  final String invoiceNo;
  final String customer;
  final List<SaleLineItem> lines;
  final DateTime createdOn;

  double get total => lines.fold(0, (sum, l) => sum + l.lineTotal);
}

class SalesStore extends ChangeNotifier {
  SalesStore._internal();
  static final SalesStore instance = SalesStore._internal();

  final List<Sale> _sales = [];
  final List<Sale> _drafts = [];

  List<Sale> get sales => List.unmodifiable(_sales);
  List<Sale> get drafts => List.unmodifiable(_drafts);

  void addSale(Sale sale) {
    _sales.add(sale);
    notifyListeners();
  }

  void removeSale(String id) {
    _sales.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void addDraft(Sale draft) {
    _drafts.add(draft);
    notifyListeners();
  }

  void removeDraft(String id) {
    _drafts.removeWhere((s) => s.id == id);
    notifyListeners();
  }
}
