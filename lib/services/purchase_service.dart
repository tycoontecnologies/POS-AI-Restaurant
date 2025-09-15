import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/models/purchase.dart';
import 'package:pos/models/product.dart';

class PurchaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String getCurrentVendorId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  String _getVendorPurchasesPath(String vendorId) {
    return 'vendors/$vendorId/purchases';
  }

  String _getVendorProductsPath(String vendorId) {
    return 'vendors/$vendorId/products';
  }

  Stream<List<Purchase>> getPurchasesStream({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    final vendorId = getCurrentVendorId();
    Query query = _firestore
        .collection(_getVendorPurchasesPath(vendorId))
        .orderBy('createdOn', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Purchase.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Purchase> addPurchase(Purchase purchase) async {
    final vendorId = getCurrentVendorId();
    final docRef = _firestore
        .collection(_getVendorPurchasesPath(vendorId))
        .doc();

    final purchaseWithId = purchase.copyWith(id: docRef.id);

    // Use batch write to ensure both purchase creation and stock update succeed or fail together
    final batch = _firestore.batch();

    // Add purchase document
    batch.set(docRef, purchaseWithId.toJson());

    // Update product and variant quantities
    await _updateProductQuantities(batch, vendorId, purchaseWithId.items);

    // Commit the batch
    await batch.commit();

    return purchaseWithId;
  }

  Future<void> _updateProductQuantities(
    WriteBatch batch,
    String vendorId,
    List<PurchaseItem> items,
  ) async {
    final productsRef = _firestore.collection(_getVendorProductsPath(vendorId));

    for (final item in items) {
      final productDoc = await productsRef.doc(item.productId).get();

      if (productDoc.exists) {
        final productData = productDoc.data() as Map<String, dynamic>;
        final product = Product.fromJson(productData);

        if (item.variantId != null && item.variantId!.isNotEmpty) {
          // Update variant quantity
          final updatedVariants = product.variants.map((variant) {
            if (variant.id == item.variantId) {
              return variant.copyWith(
                quantity: variant.quantity + item.quantity,
              );
            }
            return variant;
          }).toList();

          // Update the product with new variants
          batch.update(productsRef.doc(item.productId), {
            'variants': updatedVariants.map((v) => v.toJson()).toList(),
          });
        } else {
          // Update base product quantity
          batch.update(productsRef.doc(item.productId), {
            'quantity': product.quantity + item.quantity,
          });
        }
      }
    }
  }

  Future<void> updatePurchase(Purchase purchase) async {
    final vendorId = getCurrentVendorId();

    // First get the original purchase to calculate quantity differences
    final originalPurchase = await getPurchaseById(purchase.id);

    if (originalPurchase != null) {
      final batch = _firestore.batch();
      final purchasesRef = _firestore.collection(
        _getVendorPurchasesPath(vendorId),
      );
      _firestore.collection(_getVendorProductsPath(vendorId));

      // Update purchase document
      batch.update(purchasesRef.doc(purchase.id), purchase.toJson());

      // Revert original quantities first
      await _revertProductQuantities(batch, vendorId, originalPurchase.items);

      // Apply new quantities
      await _updateProductQuantities(batch, vendorId, purchase.items);

      await batch.commit();
    }
  }

  Future<void> _revertProductQuantities(
    WriteBatch batch,
    String vendorId,
    List<PurchaseItem> items,
  ) async {
    final productsRef = _firestore.collection(_getVendorProductsPath(vendorId));

    for (final item in items) {
      final productDoc = await productsRef.doc(item.productId).get();

      if (productDoc.exists) {
        final productData = productDoc.data() as Map<String, dynamic>;
        final product = Product.fromJson(productData);

        if (item.variantId != null && item.variantId!.isNotEmpty) {
          // Revert variant quantity
          final updatedVariants = product.variants.map((variant) {
            if (variant.id == item.variantId) {
              return variant.copyWith(
                quantity: variant.quantity - item.quantity,
              );
            }
            return variant;
          }).toList();

          batch.update(productsRef.doc(item.productId), {
            'variants': updatedVariants.map((v) => v.toJson()).toList(),
          });
        } else {
          // Revert base product quantity
          batch.update(productsRef.doc(item.productId), {
            'quantity': product.quantity - item.quantity,
          });
        }
      }
    }
  }

  Future<void> deletePurchase(String purchaseId) async {
    final vendorId = getCurrentVendorId();

    // First get the purchase to revert quantities
    final purchase = await getPurchaseById(purchaseId);

    if (purchase != null) {
      final batch = _firestore.batch();
      final purchasesRef = _firestore.collection(
        _getVendorPurchasesPath(vendorId),
      );

      // Delete purchase document
      batch.delete(purchasesRef.doc(purchaseId));

      // Revert product quantities
      await _revertProductQuantities(batch, vendorId, purchase.items);

      await batch.commit();
    }
  }

  Future<Purchase?> getPurchaseById(String purchaseId) async {
    final vendorId = getCurrentVendorId();
    final doc = await _firestore
        .collection(_getVendorPurchasesPath(vendorId))
        .doc(purchaseId)
        .get();

    if (doc.exists) {
      return Purchase.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}
