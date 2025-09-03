class Sale {
  final String id;
  final String vendorId;
  final List<SaleItem> items;
  final double total;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.vendorId,
    required this.items,
    required this.total,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] ?? '',
      vendorId: map['vendorId'] ?? '',
      items: List<SaleItem>.from(
        (map['items'] ?? []).map((item) => SaleItem.fromMap(item)),
      ),
      total: (map['total'] ?? 0.0).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}

class SaleItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 0,
    );
  }
}