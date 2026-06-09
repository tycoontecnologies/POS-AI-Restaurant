import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/discount.dart';

class DiscountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addDiscount(Discount discount) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(discount.vendorId)
          .collection('discounts')
          .doc(discount.id)
          .set(discount.toMap());
    } catch (e) {
      throw Exception('Failed to add discount: $e');
    }
  }

  Future<void> updateDiscount(Discount discount) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(discount.vendorId)
          .collection('discounts')
          .doc(discount.id)
          .update(discount.toMap());
    } catch (e) {
      throw Exception('Failed to update discount: $e');
    }
  }

  Future<void> deleteDiscount(String vendorId, String discountId) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('discounts')
          .doc(discountId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete discount: $e');
    }
  }

  Future<List<Discount>> getDiscounts(String vendorId) async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('discounts')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Discount.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch discounts: $e');
    }
  }

  Future<Discount?> getDiscountById(String vendorId, String discountId) async {
    try {
      final doc = await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('discounts')
          .doc(discountId)
          .get();

      if (doc.exists) {
        return Discount.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch discount: $e');
    }
  }

  Future<void> incrementUsageCount(String vendorId, String discountId) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('discounts')
          .doc(discountId)
          .update({
        'currentUsageCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to increment usage count: $e');
    }
  }

  Stream<List<Discount>> getDiscountsStream(String vendorId) {
    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('discounts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Discount.fromMap(doc.data(), doc.id))
            .toList());
  }
}
