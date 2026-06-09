// models/ingredient.dart
class Ingredient {
  Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantityInStock,
    this.lowStockThreshold = 20.0,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();

  final String id;
  String name;
  String unit; // g, ml, tsp, tbsp, piece, kg, litre
  double quantityInStock;
  double lowStockThreshold;
  DateTime createdOn;

  bool get isLowStock => quantityInStock <= lowStockThreshold;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'quantityInStock': quantityInStock,
    'lowStockThreshold': lowStockThreshold,
    'createdOn': createdOn.toIso8601String(),
  };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    unit: json['unit'] ?? 'g',
    quantityInStock: (json['quantityInStock'] ?? 0.0).toDouble(),
    lowStockThreshold: (json['lowStockThreshold'] ?? 20.0).toDouble(),
    createdOn: json['createdOn'] != null
        ? DateTime.parse(json['createdOn'])
        : DateTime.now(),
  );

  Ingredient copyWith({
    String? id,
    String? name,
    String? unit,
    double? quantityInStock,
    double? lowStockThreshold,
    DateTime? createdOn,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantityInStock: quantityInStock ?? this.quantityInStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdOn: createdOn ?? this.createdOn,
    );
  }
}
