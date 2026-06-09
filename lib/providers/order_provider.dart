import 'package:flutter/foundation.dart';
import 'package:pos/models/order.dart';
import '../services/order_service.dart';

class OrderProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();

  List<Order> _orders = [];
  bool _isLoading = false;
  bool _isLoaded = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  List<Order> get recentOrders {
    if (_orders.length <= 50) return _orders;
    return _orders.take(50).toList();
  }

  Future<void> createOrder(String restaurantId, Order order) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _orderService.createOrder(restaurantId, order);

      _orders.insert(0, order);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchOrders(
    String restaurantId, {
    bool forceRefresh = false,
  }) async {
    if (_isLoaded && !forceRefresh) {
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final orders = await _orderService.getOrders(restaurantId);

      if (orders.length > 50) {
        _orders = orders.take(50).toList();
      } else {
        _orders = orders;
      }

      _isLoaded = true;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateOrder(String restaurantId, Order order) async {
    try {
      await _orderService.updateOrder(restaurantId, order);

      final index = _orders.indexWhere((o) => o.id == order.id);

      if (index != -1) {
        _orders[index] = order;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteOrder(String restaurantId, String orderId) async {
    try {
      await _orderService.deleteOrder(restaurantId, orderId);

      _orders.removeWhere((o) => o.id == orderId);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void clearOrders() {
    _orders.clear();
    _isLoaded = false;
    notifyListeners();
  }
}