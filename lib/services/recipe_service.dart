// services/recipe_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/recipe.dart';

class RecipeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _recipesPath(String vendorId) => 'vendors/$vendorId/recipes';

  // We store one doc per productId
  static Stream<ProductRecipe?> streamRecipe(String vendorId, String productId) {
    return _firestore
        .collection(_recipesPath(vendorId))
        .doc(productId)
        .snapshots()
        .map((doc) =>
            doc.exists ? ProductRecipe.fromJson(doc.data()!) : null);
  }

  static Future<ProductRecipe?> getRecipe(
      String vendorId, String productId) async {
    final doc =
        await _firestore.collection(_recipesPath(vendorId)).doc(productId).get();
    if (!doc.exists) return null;
    return ProductRecipe.fromJson(doc.data()!);
  }

  static Future<void> saveRecipe(
    String vendorId,
    ProductRecipe recipe,
  ) async {
    await _firestore
        .collection(_recipesPath(vendorId))
        .doc(recipe.productId)
        .set(recipe.toJson());
  }

  static Future<void> deleteRecipe(String vendorId, String productId) async {
    await _firestore.collection(_recipesPath(vendorId)).doc(productId).delete();
  }
}
