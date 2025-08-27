import 'package:flutter/foundation.dart';

class StoreOutLineItem {
  StoreOutLineItem({
    required this.product,
    required this.unit,
    required this.price,
    required this.quantity,
  });

  final String product;
  final String unit; // e.g., piece, kg
  final double price; // unit price
  final int quantity;

  double get total => price * quantity;
}

class StoreOut {
  StoreOut({required this.id, required this.lines, DateTime? createdOn})
    : createdOn = createdOn ?? DateTime.now();

  final String id;
  final List<StoreOutLineItem> lines;
  final DateTime createdOn;

  double get total => lines.fold(0, (sum, l) => sum + l.total);
}

class StoreOutStore extends ChangeNotifier {
  StoreOutStore._internal();
  static final StoreOutStore instance = StoreOutStore._internal();

  final List<StoreOut> _items = [];

  List<StoreOut> get items => List.unmodifiable(_items);

  void add(StoreOut s) {
    _items.add(s);
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
