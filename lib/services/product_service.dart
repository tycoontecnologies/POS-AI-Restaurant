// services/firebase_product_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/product.dart';

class ProductService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String getVendorProductsPath(String vendorId) {
    return 'vendors/$vendorId/products';
  }

  static Stream<List<Product>> getProducts(
    String vendorId, {
    // int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    Query query = _firestore
        .collection(getVendorProductsPath(vendorId))
        .orderBy('createdOn', descending: true);
    // .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  static Future<Product> addProduct(String vendorId, Product product) async {
    final docRef = _firestore.collection(getVendorProductsPath(vendorId)).doc();

    // Use Firebase auto-generated ID
    final productWithId = Product(
      id: docRef.id,
      name: product.name,
      category: product.category,
      unit: product.unit,
      salePrice: product.salePrice,
      purchasePrice: product.purchasePrice,
      quantity: product.quantity,
      active: product.active,
      createdOn: product.createdOn,
      hasVariants: product.hasVariants,
      variants: product.variants,
      attributes: product.attributes,
      imageUrl: product.imageUrl,
    );

    await docRef.set(productWithId.toJson());
    return productWithId;
  }

  static Future<void> updateProduct(String vendorId, Product product) async {
    await _firestore
        .collection(getVendorProductsPath(vendorId))
        .doc(product.id)
        .update(product.toJson());
  }

  static Future<void> deleteProduct(String vendorId, String productId) async {
    await _firestore
        .collection(getVendorProductsPath(vendorId))
        .doc(productId)
        .delete();
  }

  static Future<void> seedInitialData(String vendorId) async {
    final sampleProducts = [
      Product(
        id: 'temp1',
        name: 'Laptop',
        category: 'Electronics',
        unit: 'piece',
        salePrice: 999.99,
        purchasePrice: 800.00,
        quantity: 15,
        active: true,
      ),
      Product(
        id: 'temp2',
        name: 'T-Shirt',
        category: 'Clothing',
        unit: 'piece',
        salePrice: 29.99,
        purchasePrice: 15.00,
        quantity: 50,
        active: true,
      ),
      Product(
        id: 'temp3',
        name: 'Coffee',
        category: 'Food & Beverages',
        unit: 'pack',
        salePrice: 12.99,
        purchasePrice: 8.00,
        quantity: 30,
        active: true,
      ),
    ];

    for (var product in sampleProducts) {
      await addProduct(vendorId, product);
    }
  }
}
