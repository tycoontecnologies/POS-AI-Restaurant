// models/recipe.dart
class RecipeItem {
  RecipeItem({
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.quantityPerUnit, // quantity needed per 1 unit of product
  });

  final String ingredientId;
  final String ingredientName;
  final String unit;
  final double quantityPerUnit;

  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    'ingredientName': ingredientName,
    'unit': unit,
    'quantityPerUnit': quantityPerUnit,
  };

  factory RecipeItem.fromJson(Map<String, dynamic> json) => RecipeItem(
    ingredientId: json['ingredientId'] ?? '',
    ingredientName: json['ingredientName'] ?? '',
    unit: json['unit'] ?? '',
    quantityPerUnit: (json['quantityPerUnit'] ?? 0.0).toDouble(),
  );
}

class ProductRecipe {
  ProductRecipe({
    required this.productId,
    required this.productName,
    required this.items,
    DateTime? updatedOn,
  }) : updatedOn = updatedOn ?? DateTime.now();

  final String productId;
  final String productName;
  List<RecipeItem> items;
  DateTime updatedOn;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'items': items.map((e) => e.toJson()).toList(),
    'updatedOn': updatedOn.toIso8601String(),
  };

  factory ProductRecipe.fromJson(Map<String, dynamic> json) => ProductRecipe(
    productId: json['productId'] ?? '',
    productName: json['productName'] ?? '',
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => RecipeItem.fromJson(e))
        .toList(),
    updatedOn: json['updatedOn'] != null
        ? DateTime.parse(json['updatedOn'])
        : DateTime.now(),
  );
}
