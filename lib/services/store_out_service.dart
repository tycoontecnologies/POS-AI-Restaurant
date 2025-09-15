import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pos/models/product.dart';
import '../models/store_out.dart';

class StoreOutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current vendor ID from authenticated user
  String _getCurrentVendorId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid; // Using user UID as vendor ID
  }

  // Update the getStoreOuts method to return both data and last document
  Future<Map<String, dynamic>> getStoreOutsWithPagination({
    int limit = 10,
    DocumentSnapshot? lastDocument,
  }) async {
    final query = getStoreOutsQuery(limit: limit, lastDocument: lastDocument);
    final snapshot = await query.get();

    final storeOuts = snapshot.docs
        .map(
          (doc) => StoreOut.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();

    final newLastDocument = snapshot.docs.isNotEmpty
        ? snapshot.docs.last
        : null;

    return {'storeOuts': storeOuts, 'lastDocument': newLastDocument};
  }

  // Get store-outs collection for current vendor
  CollectionReference _getStoreOutsCollection() {
    final vendorId = _getCurrentVendorId();
    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('store_outs');
  }

  // Get store-outs query with pagination support
  Query getStoreOutsQuery({int limit = 10, DocumentSnapshot? lastDocument}) {
    Query query = _getStoreOutsCollection()
        .where('active', isEqualTo: true)
        .orderBy('date', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query;
  }

  // Stream store-outs for real-time updates
  Stream<List<StoreOut>> streamStoreOuts({int limit = 10}) {
    return getStoreOutsQuery(limit: limit).snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) =>
                StoreOut.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList(),
    );
  }

  // Get store-outs with pagination
  Future<List<StoreOut>> getStoreOuts({
    int limit = 10,
    DocumentSnapshot? lastDocument,
  }) async {
    final query = getStoreOutsQuery(limit: limit, lastDocument: lastDocument);
    final snapshot = await query.get();

    return snapshot.docs
        .map(
          (doc) => StoreOut.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  // Get single store-out by ID
  Future<StoreOut?> getStoreOut(String storeOutId) async {
    final doc = await _getStoreOutsCollection().doc(storeOutId).get();

    if (doc.exists) {
      return StoreOut.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // Create new store-out record
  Future<String> createStoreOut(StoreOut storeOut) async {
    final docRef = _getStoreOutsCollection().doc();
    final vendorId = _getCurrentVendorId();

    final storeOutWithId = storeOut.copyWith(id: docRef.id, vendorId: vendorId);

    // Update product quantities
    await updateProductQuantities(storeOut.products, vendorId);

    await docRef.set(storeOutWithId.toMap());
    return docRef.id;
  }

  // Update existing store-out record
  Future<void> updateStoreOut(StoreOut storeOut) async {
    await _getStoreOutsCollection().doc(storeOut.id).update(storeOut.toMap());
  }

  // Delete store-out record (soft delete by setting active to false)
  Future<void> deleteStoreOut(String storeOutId) async {
    await _getStoreOutsCollection().doc(storeOutId).update({'active': false});
  }

  // Hard delete store-out record
  Future<void> hardDeleteStoreOut(String storeOutId) async {
    await _getStoreOutsCollection().doc(storeOutId).delete();
  }

  // Search store-outs by query
  Future<List<StoreOut>> searchStoreOuts(String query) async {
    final snapshot = await _getStoreOutsCollection()
        .where('active', isEqualTo: true)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => StoreOut.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .where(
          (storeOut) =>
              storeOut.id.toLowerCase().contains(query.toLowerCase()) ||
              storeOut.reason.toLowerCase().contains(query.toLowerCase()) ||
              storeOut.handledBy.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  // Get store-outs count
  Future<int> getStoreOutsCount() async {
    final snapshot = await _getStoreOutsCollection()
        .where('active', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // Get store-outs by date range
  Future<List<StoreOut>> getStoreOutsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _getStoreOutsCollection()
        .where('active', isEqualTo: true)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => StoreOut.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  // Get store-outs by reason
  Future<List<StoreOut>> getStoreOutsByReason(String reason) async {
    final snapshot = await _getStoreOutsCollection()
        .where('active', isEqualTo: true)
        .where('reason', isEqualTo: reason)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => StoreOut.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  // Add this method to your existing StoreOutService class
  String getVendorProductsPath(String vendorId) {
    return 'vendors/$vendorId/products';
  }

  // Update the _getLastDocument method in the provider to use this:
  // Future<DocumentSnapshot?> _getLastDocument() async {
  //   if (_storeOuts.isEmpty) return null;

  //   final lastStoreOut = _storeOuts.last;
  //   final doc = await _getStoreOutsCollection().doc(lastStoreOut.id).get();
  //   return doc.exists ? doc : null;
  // }

  // Bulk operations for batch processing
  Future<void> bulkCreateStoreOuts(List<StoreOut> storeOuts) async {
    final batch = _firestore.batch();
    final storeOutsCollection = _getStoreOutsCollection();
    final vendorId = _getCurrentVendorId();

    for (final storeOut in storeOuts) {
      final docRef = storeOutsCollection.doc();
      final storeOutWithId = storeOut.copyWith(
        id: docRef.id,
        vendorId: vendorId,
      );
      batch.set(docRef, storeOutWithId.toMap());
    }

    await batch.commit();
  }

  Future<void> updateProductQuantities(
    List<ProductQuantity> products,
    String vendorId,
  ) async {
    final batch = _firestore.batch();
    final productsCollection = _firestore.collection(
      getVendorProductsPath(vendorId),
    );

    for (final item in products) {
      final productDoc = productsCollection.doc(item.product.id);

      // Check if this is a variant product (ID contains variant indicator)
      if (item.product.id.contains('_')) {
        // Handle variant product quantity update
        final parts = item.product.id.split('_');
        final baseProductId = parts[0];
        final variantId = parts[1];

        final productDoc = productsCollection.doc(baseProductId);
        final productSnapshot = await productDoc.get();

        if (productSnapshot.exists) {
          final productData = productSnapshot.data() as Map<String, dynamic>;
          final variants = List<Map<String, dynamic>>.from(
            productData['variants'] ?? [],
          );

          final variantIndex = variants.indexWhere((v) => v['id'] == variantId);
          if (variantIndex != -1) {
            final currentVariantQty = variants[variantIndex]['quantity'] ?? 0;
            final newVariantQty = currentVariantQty - item.quantity;

            if (newVariantQty < 0) {
              throw Exception('Insufficient quantity for ${item.product.name}');
            }

            variants[variantIndex]['quantity'] = newVariantQty;
            batch.update(productDoc, {'variants': variants});
          }
        }
      } else {
        // Handle regular product quantity update
        final newQuantity = item.product.quantity - item.quantity;

        if (newQuantity < 0) {
          throw Exception('Insufficient quantity for ${item.product.name}');
        }

        batch.update(productDoc, {'quantity': newQuantity});
      }
    }

    await batch.commit();
  }

  // Add method to get all products for a vendor
  Future<List<Product>> getVendorProducts(String vendorId) async {
    final snapshot = await _firestore
        .collection(getVendorProductsPath(vendorId))
        .where('active', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => Product.fromJson(doc.data())).toList();
  }

  // Bulk update store-outs
  Future<void> bulkUpdateStoreOuts(List<StoreOut> storeOuts) async {
    final batch = _firestore.batch();
    final storeOutsCollection = _getStoreOutsCollection();

    for (final storeOut in storeOuts) {
      batch.update(storeOutsCollection.doc(storeOut.id), storeOut.toMap());
    }

    await batch.commit();
  }
}
