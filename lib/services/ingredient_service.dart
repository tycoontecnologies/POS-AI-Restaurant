// services/ingredient_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/ingredient.dart';

class IngredientService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _ingredientsPath(String vendorId) =>
      'vendors/$vendorId/ingredients';

  static Stream<List<Ingredient>> streamIngredients(String vendorId) {
    return _firestore
        .collection(_ingredientsPath(vendorId))
        .orderBy('createdOn', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Ingredient.fromJson(d.data()))
            .toList());
  }

  static Future<Ingredient> addIngredient(
    String vendorId,
    Ingredient ingredient,
  ) async {
    final doc = _firestore.collection(_ingredientsPath(vendorId)).doc();
    final withId = ingredient.copyWith(id: doc.id);
    await doc.set(withId.toJson());
    return withId;
  }

  static Future<void> updateIngredient(
    String vendorId,
    Ingredient ingredient,
  ) async {
    await _firestore
        .collection(_ingredientsPath(vendorId))
        .doc(ingredient.id)
        .update(ingredient.toJson());
  }

  static Future<void> deleteIngredient(
    String vendorId,
    String id,
  ) async {
    await _firestore.collection(_ingredientsPath(vendorId)).doc(id).delete();
  }

  static Future<void> decrementStocksBatch(
    String vendorId, Map<String, double> decrements,
  ) async {
    final batch = _firestore.batch();
    for (final entry in decrements.entries) {
      final ref =
          _firestore.collection(_ingredientsPath(vendorId)).doc(entry.key);
      batch.update(ref, {'quantityInStock': FieldValue.increment(-entry.value)});
    }
    await batch.commit();
  }
}
