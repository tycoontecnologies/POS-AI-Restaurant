// cart_provider.dart
import 'package:flutter/foundation.dart';
import 'package:pos/models/product.dart';
import 'package:pos/models/table.dart';
import 'package:collection/collection.dart'; 

class CartItem {
  final Product product;
  final ProductVariant? variant;
  int quantity;

  CartItem({
    required this.product, 
    this.variant,
    required this.quantity,
  });
  
  double get totalPrice {
    final price = variant?.getPrice(product.salePrice) ?? product.salePrice;
    return price * quantity;
  }

  String get uniqueId {
    return variant != null 
        ? '${product.id}_${variant!.id}'
        : product.id;
  }

  String get displayName {
    return variant != null 
        ? '${product.name} (${variant!.name})'
        : product.name;
  }

  int get availableStock {
    return variant?.quantity ?? product.quantity;
  }

  double get unitPrice {
    return variant?.getPrice(product.salePrice) ?? product.salePrice;
  }
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _cartItems = [];
  RestaurantTable? _selectedTable;
  int _tableNumber = 0; 

  List<CartItem> get cartItems => _cartItems;
  RestaurantTable? get selectedTable => _selectedTable;
  int get tableNumber => _selectedTable?.tableNumber ?? _tableNumber; 

  void addToCart(Product product, {ProductVariant? variant, int quantity = 1}) {
    final uniqueId = variant != null 
        ? '${product.id}_${variant.id}'
        : product.id;
        
    final existingIndex = _cartItems.indexWhere(
      (item) => item.uniqueId == uniqueId,
    );
    
    int requestedQuantity = quantity;
    if (existingIndex >= 0) {
      requestedQuantity += _cartItems[existingIndex].quantity;
    }
    
    final availableStock = variant?.quantity ?? product.quantity;
    if (requestedQuantity > availableStock) {
      throw Exception('Insufficient stock. Only $availableStock available.');
    }
    
    if (existingIndex >= 0) {
      _cartItems[existingIndex].quantity += quantity;
    } else {
      _cartItems.add(CartItem(
        product: product, 
        variant: variant,
        quantity: quantity,
      ));
    }
    
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    _cartItems.remove(item);
    notifyListeners();
  }

  void updateQuantity(CartItem item, int quantity) {
    final availableStock = item.availableStock;
    
    if (quantity > availableStock) {
      throw Exception('Insufficient stock. Only $availableStock available.');
    }
    
    if (quantity <= 0) {
      _cartItems.remove(item);
    } else {
      item.quantity = quantity;
    }
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _selectedTable = null;
    _tableNumber = 0; // Reset table number when clearing cart
    notifyListeners();
  }

  void setSelectedTable(RestaurantTable table) {
    _selectedTable = table;
    _tableNumber = table.tableNumber; // Update table number when setting selected table
    notifyListeners();
  }

  void clearSelectedTable() {
    _selectedTable = null;
    _tableNumber = 0; // Reset table number when clearing selected table
    notifyListeners();
  }

  double get total => _cartItems.fold(
    0,
    (sum, item) => sum + item.totalPrice,
  );

  int get totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  
  bool get isCartEmpty => _cartItems.isEmpty;
  
  bool canAddToCart(Product product, {ProductVariant? variant, int quantity = 1}) {
    final uniqueId = variant != null 
        ? '${product.id}_${variant.id}'
        : product.id;
        
    final existingIndex = _cartItems.indexWhere(
      (item) => item.uniqueId == uniqueId,
    );
    
    int requestedQuantity = quantity;
    if (existingIndex >= 0) {
      requestedQuantity += _cartItems[existingIndex].quantity;
    }
    
    final availableStock = variant?.quantity ?? product.quantity;
    return requestedQuantity <= availableStock;
  }

  CartItem? getCartItem(String uniqueId) {
    try {
      return _cartItems.firstWhere((item) => item.uniqueId == uniqueId);
    } catch (e) {
      return null;
    }
  }

  bool isInCart(Product product, {ProductVariant? variant}) {
    final uniqueId = variant != null 
        ? '${product.id}_${variant.id}'
        : product.id;
    return _cartItems.any((item) => item.uniqueId == uniqueId);
  }

  int getQuantityInCart(Product product, {ProductVariant? variant}) {
    final uniqueId = variant != null 
        ? '${product.id}_${variant.id}'
        : product.id;
    final item = _cartItems.where((item) => item.uniqueId == uniqueId).firstOrNull;
    return item?.quantity ?? 0;
  }
}
