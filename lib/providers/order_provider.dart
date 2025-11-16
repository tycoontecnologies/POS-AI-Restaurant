import 'package:flutter/foundation.dart';
import 'package:pos/models/order.dart';
import '../services/order_service.dart';

class OrderProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();
  List<Order> _orders = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  Future<void> createOrder(String restaurantId, Order order) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _orderService.createOrder(restaurantId, order);

      // Add to local list at the beginning
      _orders.insert(0, order);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> fetchOrders(String restaurantId) async {
    try {
      _isLoading = true;

      _orders = await _orderService.getOrders(restaurantId);

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
      _isLoading = true;
      notifyListeners();

      await _orderService.updateOrder(restaurantId, order);

      // Update local list
      final index = _orders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        _orders[index] = order;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteOrder(String restaurantId, String orderId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _orderService.deleteOrder(restaurantId, orderId);

      // Remove from local list
      _orders.removeWhere((o) => o.id == orderId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void clearOrders() {
    _orders.clear();
    notifyListeners();
  }
}
