// providers/recipe_provider.dart
import 'package:flutter/foundation.dart';
import 'package:pos/models/ingredient.dart';
import 'package:pos/models/recipe.dart';
import 'package:pos/services/ingredient_service.dart';
import 'package:pos/services/recipe_service.dart';

class RecipeProvider with ChangeNotifier {
  // Cache recipes by productId
  final Map<String, ProductRecipe> _recipes = {};
  bool _isSaving = false;

  ProductRecipe? getRecipeCached(String productId) => _recipes[productId];
  bool get isSaving => _isSaving;

  Future<ProductRecipe?> loadRecipe(String vendorId, String productId) async {
    final r = await RecipeService.getRecipe(vendorId, productId);
    if (r != null) {
      _recipes[productId] = r;
      notifyListeners();
    }
    return r;
  }

  Future<void> saveRecipe(String vendorId, ProductRecipe recipe) async {
    _isSaving = true;
    notifyListeners();
    await RecipeService.saveRecipe(vendorId, recipe);
    _recipes[recipe.productId] = recipe;
    _isSaving = false;
    notifyListeners();
  }

  Future<void> deleteRecipe(String vendorId, String productId) async {
    await RecipeService.deleteRecipe(vendorId, productId);
    _recipes.remove(productId);
    notifyListeners();
  }

  // Optional: compute how many units can be produced with current stock
  // ingredients: full list to lookup stock for each item
  int computeUnitsProducible(List<Ingredient> ingredients, ProductRecipe recipe) {
    if (recipe.items.isEmpty) return 0;
    double minUnits = double.infinity;
    for (final item in recipe.items) {
      final ing =
          ingredients.firstWhere((i) => i.id == item.ingredientId, orElse: () => Ingredient(id: '', name: '', unit: item.unit, quantityInStock: 0));
      if (item.quantityPerUnit <= 0) return 0;
      final units = ing.quantityInStock / item.quantityPerUnit;
      if (units < minUnits) minUnits = units;
    }
    if (minUnits.isInfinite || minUnits.isNaN) return 0;
    return minUnits.floor();
  }

  // Call this during sale posting to auto-decrement ingredient stocks.
  Future<void> consumeStockForSale({
    required String vendorId,
    required String productId,
    required int quantitySold,
  }) async {
    final recipe = _recipes[productId] ?? await RecipeService.getRecipe(vendorId, productId);
    if (recipe == null || recipe.items.isEmpty) return;
    final Map<String, double> decrements = {};
    for (final item in recipe.items) {
      decrements[item.ingredientId] =
          (decrements[item.ingredientId] ?? 0) + item.quantityPerUnit * quantitySold;
    }
    await IngredientService.decrementStocksBatch(vendorId, decrements);
  }
}
