// models/product.dart
class Product {
  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.salePrice,
    required this.purchasePrice,
    required this.quantity,
    this.active = true,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();

  final String id;
  String name;
  String category;
  String unit;
  double salePrice;
  double purchasePrice;
  int quantity;
  bool active;
  DateTime createdOn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'unit': unit,
    'salePrice': salePrice,
    'purchasePrice': purchasePrice,
    'quantity': quantity,
    'active': active,
    'createdOn': createdOn.toIso8601String(),
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    category: json['category'] ?? '',
    unit: json['unit'] ?? '',
    salePrice: (json['salePrice'] ?? 0.0).toDouble(),
    purchasePrice: (json['purchasePrice'] ?? 0.0).toDouble(),
    quantity: json['quantity'] ?? 0,
    active: json['active'] ?? true,
    createdOn: json['createdOn'] != null
        ? DateTime.parse(json['createdOn'])
        : DateTime.now(),
  );

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? unit,
    double? salePrice,
    double? purchasePrice,
    int? quantity,
    bool? active,
    DateTime? createdOn,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      quantity: quantity ?? this.quantity,
      active: active ?? this.active,
      createdOn: createdOn ?? this.createdOn,
    );
  }
}
