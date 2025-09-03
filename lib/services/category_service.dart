// services/category_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/category.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get vendor-specific categories collection reference
  CollectionReference getVendorCategoriesCollection(String vendorId) {
    return _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('categories');
  }

  // Add category with auto-generated ID
  Future<Category> addCategory(Category category, String vendorId) async {
    final docRef = getVendorCategoriesCollection(vendorId).doc();
    final newCategory = category.copyWith(id: docRef.id);

    await docRef.set(newCategory.toJson());
    return newCategory;
  }

  // Update category
  Future<void> updateCategory(Category category, String vendorId) async {
    await getVendorCategoriesCollection(
      vendorId,
    ).doc(category.id).update(category.toJson());
  }

  // Delete category
  Future<void> deleteCategory(String categoryId, String vendorId) async {
    await getVendorCategoriesCollection(vendorId).doc(categoryId).delete();
  }

  // Get categories stream with pagination
  Stream<List<Category>> getCategories({
    required String vendorId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) {
    var query = getVendorCategoriesCollection(vendorId)
        .where('active', isEqualTo: true)
        .orderBy('createdOn', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Category.fromJson(doc.data() as Map<String, dynamic>))
          .toList(),
    );
  }

  // Get category by ID
  Future<Category?> getCategoryById(String categoryId, String vendorId) async {
    final doc = await getVendorCategoriesCollection(
      vendorId,
    ).doc(categoryId).get();
    if (doc.exists) {
      return Category.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Get total count of categories
  Future<int> getCategoriesCount(String vendorId) async {
    final snapshot = await getVendorCategoriesCollection(
      vendorId,
    ).where('active', isEqualTo: true).count().get();
    return snapshot.count ?? 0;
  }

  // Get categories for search (without pagination)
  Stream<List<Category>> searchCategories(String query, String vendorId) {
    return getVendorCategoriesCollection(vendorId)
        .where('active', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Category.fromJson(doc.data() as Map<String, dynamic>),
              )
              .where(
                (category) =>
                    category.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList(),
        );
  }
}
