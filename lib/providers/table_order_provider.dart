// table_order_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/product.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/cart_provider.dart';

class TableOrderProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Map of tableId -> current order items
  final Map<String, List<CartItem>> _tableOrders = {};
  // Map of tableId -> order status/info
  final Map<String, Map<String, dynamic>> _tableOrderInfo = {};

  TableOrderProvider(this.authProvider);

  // Get current order for a specific table
  List<CartItem> getOrderForTable(String tableId) {
    return _tableOrders[tableId] ?? [];
  }

  // Get order info for a specific table
  Map<String, dynamic> getOrderInfo(String tableId) {
    return _tableOrderInfo[tableId] ?? {};
  }

  // Add item to table's order
  Future<void> addToTableOrder({
    required String tableId,
    required Product product,
    ProductVariant? variant,
    int quantity = 1,
  }) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null) return;

    // Initialize if needed
    if (!_tableOrders.containsKey(tableId)) {
      _tableOrders[tableId] = [];
      _tableOrderInfo[tableId] = {
        'tableId': tableId,
        'createdAt': DateTime.now(),
        'status': 'active',
        'itemsCount': 0,
        'total': 0.0,
      };
    }

    // Create cart item
    final cartItem = CartItem(
      product: product,
      variant: variant,
      quantity: quantity,
    );

    // Add to local cache
    _tableOrders[tableId]!.add(cartItem);

    // Update order info
    _tableOrderInfo[tableId]!['itemsCount'] = _tableOrders[tableId]!.length;
    _tableOrderInfo[tableId]!['total'] = _getTableTotal(tableId);
    _tableOrderInfo[tableId]!['updatedAt'] = DateTime.now();

    // Save to Firestore (persist between sessions)
    await _saveTableOrderToFirestore(vendorId, tableId);

    notifyListeners();
  }

  // Remove item from table's order
  Future<void> removeFromTableOrder({
    required String tableId,
    required int itemIndex,
  }) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null || !_tableOrders.containsKey(tableId)) return;

    if (itemIndex < _tableOrders[tableId]!.length) {
      _tableOrders[tableId]!.removeAt(itemIndex);

      // Update order info
      _tableOrderInfo[tableId]!['itemsCount'] = _tableOrders[tableId]!.length;
      _tableOrderInfo[tableId]!['total'] = _getTableTotal(tableId);
      _tableOrderInfo[tableId]!['updatedAt'] = DateTime.now();

      // Save to Firestore
      await _saveTableOrderToFirestore(vendorId, tableId);

      notifyListeners();
    }
  }

  // Update item quantity in table's order
  Future<void> updateTableOrderQuantity({
    required String tableId,
    required int itemIndex,
    required int quantity,
  }) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null || !_tableOrders.containsKey(tableId)) return;

    if (itemIndex < _tableOrders[tableId]!.length) {
      final item = _tableOrders[tableId]![itemIndex];

      // Check stock availability
      final availableStock = item.variant?.quantity ?? item.product.quantity;
      if (quantity > availableStock) {
        throw Exception('Insufficient stock. Only $availableStock available.');
      }

      if (quantity <= 0) {
        _tableOrders[tableId]!.removeAt(itemIndex);
      } else {
        item.quantity = quantity;
      }

      // Update order info
      _tableOrderInfo[tableId]!['itemsCount'] = _tableOrders[tableId]!.length;
      _tableOrderInfo[tableId]!['total'] = _getTableTotal(tableId);
      _tableOrderInfo[tableId]!['updatedAt'] = DateTime.now();

      // Save to Firestore
      await _saveTableOrderToFirestore(vendorId, tableId);

      notifyListeners();
    }
  }

  // Clear table's order (when checkout is completed)
  Future<void> clearTableOrder(String tableId) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null) return;

    // Clear local cache
    _tableOrders.remove(tableId);
    _tableOrderInfo.remove(tableId);

    // Clear from Firestore
    await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('tableOrders')
        .doc(tableId)
        .delete();

    notifyListeners();
  }

  // Load table order from Firestore (when opening table screen)
  Future<void> loadTableOrder(String tableId) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null) return;

    try {
      final doc = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('tableOrders')
          .doc(tableId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _tableOrderInfo[tableId] = Map<String, dynamic>.from(data);

        // Convert stored items back to CartItems
        final itemsData = List<Map<String, dynamic>>.from(data['items'] ?? []);
        _tableOrders[tableId] = await _convertToCartItems(itemsData);

        notifyListeners();
      }
    } catch (e) {
      print('Error loading table order: $e');
    }
  }

  // Helper: Save table order to Firestore
  Future<void> _saveTableOrderToFirestore(
    String vendorId,
    String tableId,
  ) async {
    try {
      final itemsData = _tableOrders[tableId]!.map((item) {
        return {
          'productId': item.product.id,
          'productName': item.displayName,
          'variantId': item.variant?.id,
          'variantName': item.variant?.name,
          'quantity': item.quantity,
          'unitPrice': item.unitPrice,
          'totalPrice': item.totalPrice,
          'productData': item.product.toJson(),
          'variantData': item.variant?.toJson(),
        };
      }).toList();

      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('tableOrders')
          .doc(tableId)
          .set({
            'tableId': tableId,
            'items': itemsData,
            'total': _getTableTotal(tableId),
            'itemsCount': _tableOrders[tableId]!.length,
            'status': 'active',
            'createdAt': _tableOrderInfo[tableId]!['createdAt'],
            'updatedAt': DateTime.now(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving table order: $e');
    }
  }

  // Helper: Convert stored data back to CartItems
  Future<List<CartItem>> _convertToCartItems(
    List<Map<String, dynamic>> itemsData,
  ) async {
    final List<CartItem> cartItems = [];

    for (final itemData in itemsData) {
      try {
        final product = Product.fromJson(itemData['productData']);
        final variantData = itemData['variantData'];
        final ProductVariant? variant = variantData != null
            ? ProductVariant.fromJson(variantData)
            : null;

        cartItems.add(
          CartItem(
            product: product,
            variant: variant,
            quantity: itemData['quantity'] ?? 1,
          ),
        );
      } catch (e) {
        print('Error converting item: $e');
      }
    }

    return cartItems;
  }

  // Helper: Calculate table total
  double _getTableTotal(String tableId) {
    if (!_tableOrders.containsKey(tableId)) return 0.0;

    return _tableOrders[tableId]!.fold(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
  }

  // Check if table has active order
  bool hasActiveOrder(String tableId) {
    return _tableOrders.containsKey(tableId) &&
        _tableOrders[tableId]!.isNotEmpty;
  }

  // Get all tables with active orders
  List<String> getTablesWithOrders() {
    return _tableOrders.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList();
  }
  
}
