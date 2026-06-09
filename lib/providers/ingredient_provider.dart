// providers/ingredient_provider.dart
import 'package:flutter/foundation.dart';
import 'package:pos/models/ingredient.dart';
import 'package:pos/services/ingredient_service.dart';

class IngredientProvider with ChangeNotifier {
  List<Ingredient> _ingredients = [];
  bool _isLoading = false;

  List<Ingredient> get ingredients => _ingredients;
  bool get isLoading => _isLoading;

  Stream<List<Ingredient>> stream(String vendorId) {
    return IngredientService.streamIngredients(vendorId);
  }

  void bindStream(String vendorId) {
    if (_isLoading) return;
    _isLoading = true;
    IngredientService.streamIngredients(vendorId).listen((data) {
      _ingredients = data;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<Ingredient> add(String vendorId, Ingredient ingredient) async {
    final created = await IngredientService.addIngredient(vendorId, ingredient);
    _ingredients.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<void> update(String vendorId, Ingredient ingredient) async {
    await IngredientService.updateIngredient(vendorId, ingredient);
    final i = _ingredients.indexWhere((x) => x.id == ingredient.id);
    if (i != -1) _ingredients[i] = ingredient;
    notifyListeners();
  }

  Future<void> remove(String vendorId, String id) async {
    await IngredientService.deleteIngredient(vendorId, id);
    _ingredients.removeWhere((x) => x.id == id);
    notifyListeners();
  }
}
