// purchase_return.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseReturn {
  final String id;
  final String vendorId;
  final String originalPurchaseId;
  final String supplierId;
  final String supplierName;
  final List<PurchaseReturnItem> items;
  final double totalRefund;
  final String reason;
  final DateTime createdAt;

  PurchaseReturn({
    required this.id,
    required this.vendorId,
    required this.originalPurchaseId,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.totalRefund,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'originalPurchaseId': originalPurchaseId,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalRefund': totalRefund,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PurchaseReturn.fromMap(Map<String, dynamic> map) {
    return PurchaseReturn(
      id: map['id'] ?? '',
      vendorId: map['vendorId'] ?? '',
      originalPurchaseId: map['originalPurchaseId'] ?? '',
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      items: List<PurchaseReturnItem>.from(
        (map['items'] ?? []).map((item) => PurchaseReturnItem.fromMap(item)),
      ),
      totalRefund: (map['totalRefund'] ?? 0.0).toDouble(),
      reason: map['reason'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class PurchaseReturnItem {
  final String productId;
  final String productName;
  final double originalPrice;
  final int returnedQuantity;
  final double refundAmount;

  PurchaseReturnItem({
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

  factory PurchaseReturnItem.fromMap(Map<String, dynamic> map) {
    return PurchaseReturnItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      originalPrice: (map['originalPrice'] ?? 0.0).toDouble(),
      returnedQuantity: map['returnedQuantity'] ?? 0,
      refundAmount: (map['refundAmount'] ?? 0.0).toDouble(),
    );
  }
}