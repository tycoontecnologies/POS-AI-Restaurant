class SaleReturn {
  final String id;
  final String vendorId;
  final String originalSaleId;
  final List<SaleReturnItem> items;
  final double totalRefund;
  final String reason;
  final DateTime createdAt;

  SaleReturn({
    required this.id,
    required this.vendorId,
    required this.originalSaleId,
    required this.items,
    required this.totalRefund,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'originalSaleId': originalSaleId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalRefund': totalRefund,
      'reason': reason,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SaleReturn.fromMap(Map<String, dynamic> map) {
    return SaleReturn(
      id: map['id'] ?? '',
      vendorId: map['vendorId'] ?? '',
      originalSaleId: map['originalSaleId'] ?? '',
      items: List<SaleReturnItem>.from(
        (map['items'] ?? []).map((item) => SaleReturnItem.fromMap(item)),
      ),
      totalRefund: (map['totalRefund'] ?? 0.0).toDouble(),
      reason: map['reason'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}

class SaleReturnItem {
  final String productId;
  final String productName;
  final double originalPrice;
  final int returnedQuantity;
  final double refundAmount;

  SaleReturnItem({
    required this.productId,
    required this.productName,
    required this.originalPrice,
    required this.returnedQuantity,
    required this.refundAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'originalPrice': originalPrice,
      'returnedQuantity': returnedQuantity,
      'refundAmount': refundAmount,
    };
  }

  factory SaleReturnItem.fromMap(Map<String, dynamic> map) {
    return SaleReturnItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      originalPrice: (map['originalPrice'] ?? 0.0).toDouble(),
      returnedQuantity: map['returnedQuantity'] ?? 0,
      refundAmount: (map['refundAmount'] ?? 0.0).toDouble(),
    );
  }
}