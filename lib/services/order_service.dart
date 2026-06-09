import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:pos/models/order.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createOrder(String restaurantId, Order order) async {
    try {
      final restaurantRef = _firestore.collection('vendors').doc(restaurantId);
      final ordersRef = restaurantRef.collection('orders').doc(order.id);
      
      await ordersRef.set(order.toMap());
      return order.id;
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  Future<List<Order>> getOrders(String restaurantId) async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(restaurantId)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Order.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  Future<Order?> getOrder(String restaurantId, String orderId) async {
    try {
      final doc = await _firestore
          .collection('vendors')
          .doc(restaurantId)
          .collection('orders')
          .doc(orderId)
          .get();

      return doc.exists ? Order.fromMap(doc.data()!) : null;
    } catch (e) {
      throw Exception('Failed to fetch order: $e');
    }
  }

  Future<void> updateOrder(String restaurantId, Order order) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(restaurantId)
          .collection('orders')
          .doc(order.id)
          .update(order.toMap());
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  Future<void> deleteOrder(String restaurantId, String orderId) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(restaurantId)
          .collection('orders')
          .doc(orderId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }

  Stream<List<Order>> watchOrders(String restaurantId) {
    return _firestore
        .collection('vendors')
        .doc(restaurantId)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Order.fromMap(doc.data()))
            .toList());
  }
}
