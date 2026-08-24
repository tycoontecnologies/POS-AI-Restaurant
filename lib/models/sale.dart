class Sale {
  final String id;
  final String vendorId;
  final List<SaleItem> items;
  final double total;
  final DateTime createdAt;
  final String? tableNumber;
  final String paymentMethod;
  final String? paymentReference;
  final String? praInvoiceId;
  final String? praInvoiceNo;

  Sale({
    required this.id,
    required this.vendorId,
    required this.items,
    required this.total,
    required this.createdAt,
    this.tableNumber,
    this.paymentMethod = 'Cash',
    this.paymentReference,
    this.praInvoiceId,
    this.praInvoiceNo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'tableNumber': tableNumber,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      'praInvoiceId': praInvoiceId,
      'praInvoiceNo': praInvoiceNo,
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
      tableNumber: map['tableNumber'] as String?,
      paymentMethod: (map['paymentMethod'] ?? 'Cash').toString(),
      paymentReference: map['paymentReference'] as String?,
      praInvoiceId: map['praInvoiceId'] as String?,
      praInvoiceNo: map['praInvoiceNo'] as String?,
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
