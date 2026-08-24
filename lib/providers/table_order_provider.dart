// table_order_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/product.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/cart_provider.dart';

class TableOrderProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, List<CartItem>> _tableOrders = {};
  final Map<String, Map<String, dynamic>> _tableOrderInfo = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _allOrdersSubscription;

  TableOrderProvider(this.authProvider);

  List<CartItem> getOrderForTable(String tableId) => _tableOrders[tableId] ?? [];
  Map<String, dynamic> getOrderInfo(String tableId) => _tableOrderInfo[tableId] ?? {};

  String getOrderStatus(String tableId) {
    return (_tableOrderInfo[tableId]?['status'] ?? 'empty').toString();
  }

  Future<void> addToTableOrder({
    required String tableId,
    required Product product,
    ProductVariant? variant,
    int quantity = 1,
  }) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null) return;

    if (!_tableOrders.containsKey(tableId)) {
      _tableOrders[tableId] = [];
      _tableOrderInfo[tableId] = {
        'tableId': tableId,
        'createdAt': DateTime.now(),
        'status': 'open',
        'itemsCount': 0,
        'total': 0.0,
      };
    }

    _tableOrders[tableId]!.add(CartItem(product: product, variant: variant, quantity: quantity));
    _tableOrderInfo[tableId]!['itemsCount'] = _tableOrders[tableId]!.length;
    _tableOrderInfo[tableId]!['total'] = _getTableTotal(tableId);
    _tableOrderInfo[tableId]!['updatedAt'] = DateTime.now();
    if ((_tableOrderInfo[tableId]!['status'] ?? '').toString().isEmpty) {
      _tableOrderInfo[tableId]!['status'] = 'open';
    }

    await _saveTableOrderToFirestore(vendorId, tableId);
    notifyListeners();
  }

  Future<void> removeFromTableOrder({required String tableId, required int itemIndex}) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null || !_tableOrders.containsKey(tableId)) return;
    if (itemIndex < _tableOrders[tableId]!.length) {
      _tableOrders[tableId]!.removeAt(itemIndex);
      _tableOrderInfo[tableId]!['itemsCount'] = _tableOrders[tableId]!.length;
      _tableOrderInfo[tableId]!['total'] = _getTableTotal(tableId);
      _tableOrderInfo[tableId]!['updatedAt'] = DateTime.now();
      await _saveTableOrderToFirestore(vendorId, tableId);
      notifyListeners();
    }
  }

  Future<void> updateTableOrderQuantity({
    required String tableId,
    required int itemIndex,
    required int quantity,
  }) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null || !_tableOrders.containsKey(tableId)) return;

    if (itemIndex < _tableOrders[tableId]!.length) {
      final item = _tableOrders[tableId]![itemIndex];
      final availableStock = item.variant?.quantity ?? item.product.quantity;
      if (quantity > availableStock) {
        throw Exception('Insufficient stock. Only $availableStock available.');
      }

      if (quantity <= 0) {
        _tableOrders[tableId]!.removeAt(itemIndex);
      } else {
        item.quantity = quantity;
      }

      _tableOrderInfo[tableId]!['itemsCount'] = _tableOrders[tableId]!.length;
      _tableOrderInfo[tableId]!['total'] = _getTableTotal(tableId);
      _tableOrderInfo[tableId]!['updatedAt'] = DateTime.now();
      await _saveTableOrderToFirestore(vendorId, tableId);
      notifyListeners();
    }
  }

  Future<void> setOrderStatus(String tableId, String status) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null) return;

    _tableOrderInfo.putIfAbsent(tableId, () => {
      'tableId': tableId,
      'createdAt': DateTime.now(),
      'itemsCount': _tableOrders[tableId]?.length ?? 0,
      'total': _getTableTotal(tableId),
    });
    _tableOrderInfo[tableId]!['status'] = status;
    _tableOrderInfo[tableId]!['updatedAt'] = DateTime.now();

    await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('tableOrders')
        .doc(tableId)
        .set({
          'status': status,
          'updatedAt': DateTime.now(),
        }, SetOptions(merge: true));

    notifyListeners();
  }

  Future<void> setOrderMeta(String tableId, Map<String, dynamic> values) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null || values.isEmpty) return;

    _tableOrderInfo.putIfAbsent(tableId, () => {
      'tableId': tableId,
      'createdAt': DateTime.now(),
      'itemsCount': _tableOrders[tableId]?.length ?? 0,
      'total': _getTableTotal(tableId),
    });
    _tableOrderInfo[tableId]!.addAll(values);
    _tableOrderInfo[tableId]!['updatedAt'] = DateTime.now();

    await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('tableOrders')
        .doc(tableId)
        .set({...values, 'updatedAt': DateTime.now()}, SetOptions(merge: true));

    notifyListeners();
  }

  Future<void> clearTableOrder(String tableId) async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null) return;

    _tableOrders.remove(tableId);
    _tableOrderInfo.remove(tableId);

    await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('tableOrders')
        .doc(tableId)
        .delete();

    notifyListeners();
  }

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
        final itemsData = List<Map<String, dynamic>>.from(data['items'] ?? []);
        _tableOrders[tableId] = await _convertToCartItems(itemsData);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading table order: $e');
    }
  }

  Future<void> loadAllTableOrders() async {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null) return;

    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('tableOrders')
          .get();

      await _applySnapshot(snapshot);
    } catch (e) {
      debugPrint('Error loading table orders: $e');
    }
  }

  void watchAllTableOrders() {
    final vendorId = authProvider.currentUser?.id;
    if (vendorId == null) return;
    _allOrdersSubscription?.cancel();
    _allOrdersSubscription = _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('tableOrders')
        .snapshots()
        .listen((snapshot) async {
      await _applySnapshot(snapshot);
    }, onError: (Object e) {
      debugPrint('Error watching table orders: $e');
    });
  }

  Future<void> _applySnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    final seen = <String>{};
    for (final doc in snapshot.docs) {
      seen.add(doc.id);
      final data = doc.data();
      _tableOrderInfo[doc.id] = Map<String, dynamic>.from(data);
      final rawItems = data['items'] ?? [];
      final itemsData = List<Map<String, dynamic>>.from(rawItems);
      _tableOrders[doc.id] = await _convertToCartItems(itemsData);
    }

    final removed = _tableOrders.keys.where((id) => !seen.contains(id)).toList();
    for (final id in removed) {
      _tableOrders.remove(id);
      _tableOrderInfo.remove(id);
    }
    notifyListeners();
  }

  Future<void> _saveTableOrderToFirestore(String vendorId, String tableId) async {
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

      final info = _tableOrderInfo[tableId] ?? {};
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
            'status': info['status'] ?? 'open',
            'createdAt': info['createdAt'] ?? DateTime.now(),
            'updatedAt': DateTime.now(),
            if (info['waiterId'] != null) 'waiterId': info['waiterId'],
            if (info['waiterName'] != null) 'waiterName': info['waiterName'],
            if (info['customerCount'] != null) 'customerCount': info['customerCount'],
            if (info['kotNumber'] != null) 'kotNumber': info['kotNumber'],
            if (info['billNumber'] != null) 'billNumber': info['billNumber'],
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving table order: $e');
    }
  }

  Future<List<CartItem>> _convertToCartItems(List<Map<String, dynamic>> itemsData) async {
    final List<CartItem> cartItems = [];
    for (final itemData in itemsData) {
      try {
        final product = Product.fromJson(itemData['productData']);
        final variantData = itemData['variantData'];
        final ProductVariant? variant = variantData != null
            ? ProductVariant.fromJson(variantData)
            : null;
        cartItems.add(CartItem(product: product, variant: variant, quantity: itemData['quantity'] ?? 1));
      } catch (e) {
        debugPrint('Error converting item: $e');
      }
    }
    return cartItems;
  }

  double _getTableTotal(String tableId) {
    if (!_tableOrders.containsKey(tableId)) return 0.0;
    return _tableOrders[tableId]!.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  bool hasActiveOrder(String tableId) {
    return _tableOrders.containsKey(tableId) && _tableOrders[tableId]!.isNotEmpty;
  }

  List<String> getTablesWithOrders() {
    return _tableOrders.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList();
  }

  @override
  void dispose() {
    _allOrdersSubscription?.cancel();
    super.dispose();
  }
}
