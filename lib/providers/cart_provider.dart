// cart_provider.dart
import 'package:flutter/foundation.dart';
import 'package:pos/models/product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});
  
  double get totalPrice => product.salePrice * quantity;
}

class CartProvider with ChangeNotifier {
  final List<CartItem> _cartItems = [];

  List<CartItem> get cartItems => _cartItems;

  void addToCart(Product product, {int quantity = 1}) {
    final existingIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );
    
    int requestedQuantity = quantity;
    if (existingIndex >= 0) {
      requestedQuantity += _cartItems[existingIndex].quantity;
    }
    
    // Check if requested quantity exceeds available stock
    if (requestedQuantity > product.quantity) {
      throw Exception('Insufficient stock. Only ${product.quantity} available.');
    }
    
    if (existingIndex >= 0) {
      _cartItems[existingIndex].quantity += quantity;
    } else {
      _cartItems.add(CartItem(product: product, quantity: quantity));
    }
    
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    _cartItems.remove(item);
    notifyListeners();
  }

  void updateQuantity(CartItem item, int quantity) {
    // Check if requested quantity exceeds available stock
    if (quantity > item.product.quantity) {
      throw Exception('Insufficient stock. Only ${item.product.quantity} available.');
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
    notifyListeners();
  }

  double get total => _cartItems.fold(
    0,
    (sum, item) => sum + (item.product.salePrice * item.quantity),
  );

  int get totalItems => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  
  bool get isCartEmpty => _cartItems.isEmpty;
  
  // Helper method to check if a product can be added to cart
  bool canAddToCart(Product product, {int quantity = 1}) {
    final existingIndex = _cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );
    
    int requestedQuantity = quantity;
    if (existingIndex >= 0) {
      requestedQuantity += _cartItems[existingIndex].quantity;
    }
    
    return requestedQuantity <= product.quantity;
  }
}