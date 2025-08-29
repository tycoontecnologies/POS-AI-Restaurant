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
    id: json['id'],
    name: json['name'],
    category: json['category'],
    unit: json['unit'],
    salePrice: json['salePrice']?.toDouble() ?? 0.0,
    purchasePrice: json['purchasePrice']?.toDouble() ?? 0.0,
    quantity: json['quantity'] ?? 0,
    active: json['active'] ?? true,
    createdOn: DateTime.parse(json['createdOn']),
  );
}
