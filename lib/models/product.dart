// models/product.dart

class ProductAttribute {
  final String id;
  final String name;
  final String type; // 'text', 'number', 'selection'
  final List<String> options; // For selection type
  final bool required;

  ProductAttribute({
    required this.id,
    required this.name,
    required this.type,
    this.options = const [],
    this.required = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'options': options,
    'required': required,
  };

  factory ProductAttribute.fromJson(Map<String, dynamic> json) =>
      ProductAttribute(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        type: json['type'] ?? 'text',
        options: List<String>.from(json['options'] ?? []),
        required: json['required'] ?? false,
      );

  ProductAttribute copyWith({
    String? id,
    String? name,
    String? type,
    List<String>? options,
    bool? required,
  }) {
    return ProductAttribute(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      options: options ?? this.options,
      required: required ?? this.required,
    );
  }
}

class ProductVariant {
  final String id;
  final String name;
  final double priceModifier;
  final int quantity;
  final bool active;
  final Map<String, String> attributes;

  ProductVariant({
    required this.id,
    required this.name,
    this.priceModifier = 0.0,
    required this.quantity,
    this.active = true,
    this.attributes = const {},
  });

  double getPrice(double basePrice) => basePrice + priceModifier;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'priceModifier': priceModifier,
    'quantity': quantity,
    'active': active,
    'attributes': attributes,
  };

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    priceModifier: (json['priceModifier'] ?? 0.0).toDouble(),
    quantity: json['quantity'] ?? 0,
    active: json['active'] ?? true,
    attributes: Map<String, String>.from(json['attributes'] ?? {}),
  );

  ProductVariant copyWith({
    String? id,
    String? name,
    double? priceModifier,
    int? quantity,
    bool? active,
    Map<String, String>? attributes,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      name: name ?? this.name,
      priceModifier: priceModifier ?? this.priceModifier,
      quantity: quantity ?? this.quantity,
      active: active ?? this.active,
      attributes: attributes ?? this.attributes,
    );
  }
}

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
    this.hasVariants = false,
    this.variants = const [],
    this.attributes = const [],
    this.imageUrl = '',
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

  bool hasVariants;
  List<ProductVariant> variants;
  List<ProductAttribute> attributes;
  String imageUrl;

  int get totalVariantQuantity =>
      variants.fold(0, (sum, variant) => sum + variant.quantity);

  List<ProductVariant> get activeVariants =>
      variants.where((v) => v.active).toList();

  bool get hasStock => hasVariants ? totalVariantQuantity > 0 : quantity > 0;

  double get minPrice => hasVariants && variants.isNotEmpty
      ? variants
            .map((v) => v.getPrice(salePrice))
            .reduce((a, b) => a < b ? a : b)
      : salePrice;

  double get maxPrice => hasVariants && variants.isNotEmpty
      ? variants
            .map((v) => v.getPrice(salePrice))
            .reduce((a, b) => a > b ? a : b)
      : salePrice;

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
    'hasVariants': hasVariants,
    'variants': variants.map((v) => v.toJson()).toList(),
    'attributes': attributes.map((a) => a.toJson()).toList(),
    'imageUrl': imageUrl,
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
    hasVariants: json['hasVariants'] ?? false,
    variants:
        (json['variants'] as List<dynamic>?)
            ?.map((v) => ProductVariant.fromJson(v))
            .toList() ??
        [],
    attributes:
        (json['attributes'] as List<dynamic>?)
            ?.map((a) => ProductAttribute.fromJson(a))
            .toList() ??
        [],
    imageUrl: json['imageUrl'] ?? '',
  );

  int get totalAvailableStock {
    if (hasVariants && variants.isNotEmpty) {
      return totalVariantQuantity;
    } else {
      return quantity;
    }
  }

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
    bool? hasVariants,
    List<ProductVariant>? variants,
    List<ProductAttribute>? attributes,
    String? imageUrl,
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
      hasVariants: hasVariants ?? this.hasVariants,
      variants: variants ?? this.variants,
      attributes: attributes ?? this.attributes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
