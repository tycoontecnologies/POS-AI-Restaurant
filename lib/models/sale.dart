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
  final String? waiterId;
  final String? waiterName;
  final double tipAmount;
  final double commissionAmount;
  final double serviceChargeAmount;
  final int pointsAwarded;
  final double? customerRating;
  final String? customerReview;
  final int receiptPrintCount;

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
    this.waiterId,
    this.waiterName,
    this.tipAmount = 0,
    this.commissionAmount = 0,
    this.serviceChargeAmount = 0,
    this.pointsAwarded = 0,
    this.customerRating,
    this.customerReview,
    this.receiptPrintCount = 0,
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
      'waiterId': waiterId,
      'waiterName': waiterName,
      'tipAmount': tipAmount,
      'commissionAmount': commissionAmount,
      'serviceChargeAmount': serviceChargeAmount,
      'pointsAwarded': pointsAwarded,
      'customerRating': customerRating,
      'customerReview': customerReview,
      'receiptPrintCount': receiptPrintCount,
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
      waiterId: map['waiterId']?.toString(),
      waiterName: map['waiterName']?.toString(),
      tipAmount: (map['tipAmount'] ?? 0).toDouble(),
      commissionAmount: (map['commissionAmount'] ?? 0).toDouble(),
      serviceChargeAmount: (map['serviceChargeAmount'] ?? 0).toDouble(),
      pointsAwarded: (map['pointsAwarded'] ?? 0).toInt(),
      customerRating: map['customerRating'] == null ? null : (map['customerRating'] as num).toDouble(),
      customerReview: map['customerReview']?.toString(),
      receiptPrintCount: (map['receiptPrintCount'] ?? 0).toInt(),
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
