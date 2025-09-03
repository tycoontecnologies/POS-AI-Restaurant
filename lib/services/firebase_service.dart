import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/staff.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  static final CollectionReference _categoriesCollection = _firestore
      .collection('categories');
  static final CollectionReference _productsCollection = _firestore.collection(
    'products',
  );
  static final CollectionReference _staffCollection = _firestore.collection(
    'staff',
  );

  // Category operations
  static Future<void> addCategory(Category category) async {
    await _categoriesCollection.doc(category.id).set(category.toJson());
  }

  static Future<void> updateCategory(Category category) async {
    await _categoriesCollection.doc(category.id).update(category.toJson());
  }

  static Future<void> deleteCategory(String categoryId) async {
    await _categoriesCollection.doc(categoryId).delete();
  }

  static Stream<List<Category>> getCategories() {
    return _categoriesCollection
        .where('active', isEqualTo: true)
        .orderBy('createdOn', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Category.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  static Future<Category?> getCategoryById(String categoryId) async {
    final doc = await _categoriesCollection.doc(categoryId).get();
    if (doc.exists) {
      return Category.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Product operations
  static Future<void> addProduct(Product product) async {
    await _productsCollection.doc(product.id).set(product.toJson());
  }

  static Future<void> updateProduct(Product product) async {
    await _productsCollection.doc(product.id).update(product.toJson());
  }

  static Future<void> deleteProduct(String productId) async {
    await _productsCollection.doc(productId).delete();
  }

  static Stream<List<Product>> getProducts() {
    return _productsCollection
        .where('active', isEqualTo: true)
        .orderBy('createdOn', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Product.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  static Stream<List<Product>> getProductsByCategory(String categoryId) {
    return _productsCollection
        .where('category', isEqualTo: categoryId)
        .where('active', isEqualTo: true)
        .orderBy('createdOn', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Product.fromJson(doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  static Future<Product?> getProductById(String productId) async {
    final doc = await _productsCollection.doc(productId).get();
    if (doc.exists) {
      return Product.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Staff operations
  static Future<void> addStaff(Staff staff) async {
    await _staffCollection.doc(staff.id).set(staff.toJson());
  }

  static Future<void> updateStaff(Staff staff) async {
    await _staffCollection.doc(staff.id).update(staff.toJson());
  }

  static Future<void> deleteStaff(String staffId) async {
    await _staffCollection.doc(staffId).delete();
  }

  static Stream<List<Staff>> getStaff() {
    return _staffCollection
        .where('active', isEqualTo: true)
        .orderBy('joinDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Staff.fromJson(doc.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  static Future<Staff?> getStaffById(String staffId) async {
    final doc = await _staffCollection.doc(staffId).get();
    if (doc.exists) {
      return Staff.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Utility methods
  static Future<int> getCategoryProductCount(String categoryId) async {
    final snapshot = await _productsCollection
        .where('category', isEqualTo: categoryId)
        .where('active', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  static Future<void> seedInitialData() async {
    // Check if categories already exist
    final categoriesSnapshot = await _categoriesCollection.limit(1).get();
    if (categoriesSnapshot.docs.isNotEmpty) return;

    // Seed categories
    final categories = [
      Category(id: 'cat_1', name: 'Electronics'),
      Category(id: 'cat_2', name: 'Clothing'),
      Category(id: 'cat_3', name: 'Food & Beverages'),
      Category(id: 'cat_4', name: 'Books'),
      Category(id: 'cat_5', name: 'Home & Garden'),
    ];

    for (final category in categories) {
      await addCategory(category);
    }

    // Seed products
    final products = [
      Product(
        id: 'prod_1',
        name: 'Smartphone',
        category: 'cat_1',
        unit: 'piece',
        salePrice: 599.99,
        purchasePrice: 450.00,
        quantity: 50,
      ),
      Product(
        id: 'prod_2',
        name: 'Laptop',
        category: 'cat_1',
        unit: 'piece',
        salePrice: 999.99,
        purchasePrice: 750.00,
        quantity: 25,
      ),
      Product(
        id: 'prod_3',
        name: 'T-Shirt',
        category: 'cat_2',
        unit: 'piece',
        salePrice: 29.99,
        purchasePrice: 15.00,
        quantity: 100,
      ),
      Product(
        id: 'prod_4',
        name: 'Jeans',
        category: 'cat_2',
        unit: 'piece',
        salePrice: 79.99,
        purchasePrice: 40.00,
        quantity: 75,
      ),
      Product(
        id: 'prod_5',
        name: 'Coffee Beans',
        category: 'cat_3',
        unit: 'kg',
        salePrice: 24.99,
        purchasePrice: 12.00,
        quantity: 200,
      ),
    ];

    for (final product in products) {
      await addProduct(product);
    }
  }
}
