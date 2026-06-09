import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/models/product.dart';
import 'package:flutter/foundation.dart';

class StoreOut {
  final String id;
  final String vendorId;
  final String reason;
  final List<ProductQuantity> products;
  final DateTime date;
  final String handledBy;
  final bool active;
  final DateTime createdOn;

  StoreOut({
    required this.id,
    required this.vendorId,
    required this.reason,
    required this.products,
    required this.date,
    required this.handledBy,
    this.active = true,
    DateTime? createdOn,
  }) : createdOn = createdOn ?? DateTime.now();

  int get items => products.fold(0, (sum, item) => sum + item.quantity);
  double get totalValue => products.fold(0.0, (sum, item) => sum + (item.product.salePrice * item.quantity));

  factory StoreOut.fromMap(Map<String, dynamic> data, String documentId) {
    // Parse products list
    List<ProductQuantity> products = [];
    if (data['products'] != null && data['products'] is List) {
      products = (data['products'] as List).map((item) {
        return ProductQuantity(
          product: Product.fromJson(item['product']),
          quantity: item['quantity'] ?? 0,
        );
      }).toList();
    }

    return StoreOut(
      id: data['id'] as String? ?? documentId,
      vendorId: data['vendorId'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      products: products,
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      handledBy: data['handledBy'] as String? ?? '',
      active: data['active'] as bool? ?? true,
      createdOn: data['createdOn'] != null
          ? (data['createdOn'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'reason': reason,
      'products': products.map((item) => {
        'product': item.product.toJson(),
        'quantity': item.quantity,
      }).toList(),
      'date': Timestamp.fromDate(date),
      'handledBy': handledBy,
      'active': active,
      'createdOn': Timestamp.fromDate(createdOn),
    };
  }

  StoreOut copyWith({
    String? id,
    String? vendorId,
    String? reason,
    List<ProductQuantity>? products,
    DateTime? date,
    String? handledBy,
    bool? active,
    DateTime? createdOn,
  }) {
    return StoreOut(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      reason: reason ?? this.reason,
      products: products ?? this.products,
      date: date ?? this.date,
      handledBy: handledBy ?? this.handledBy,
      active: active ?? this.active,
      createdOn: createdOn ?? this.createdOn,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoreOut &&
        other.id == id &&
        other.vendorId == vendorId &&
        other.reason == reason &&
        listEquals(other.products, products) &&
        other.date == date &&
        other.handledBy == handledBy &&
        other.active == active &&
        other.createdOn == createdOn;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      vendorId,
      reason,
      Object.hashAll(products),
      date,
      handledBy,
      active,
      createdOn,
    );
  }
}

class ProductQuantity {
  final Product product;
  final int quantity;

  ProductQuantity({
    required this.product,
    required this.quantity,
  });

  ProductQuantity copyWith({
    Product? product,
    int? quantity,
  }) {
    return ProductQuantity(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductQuantity &&
        other.product == product &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(product, quantity);
}