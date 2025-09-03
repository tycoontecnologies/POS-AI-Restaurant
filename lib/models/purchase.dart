import 'package:cloud_firestore/cloud_firestore.dart';

class Purchase {
  final String id;
  final String supplierId;
  final String supplierName;
  final List<PurchaseItem> items;
  final double total;
  final DateTime date;
  final String status;
  final DateTime createdOn;

  Purchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.total,
    required this.date,
    required this.status,
    required this.createdOn,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'date': Timestamp.fromDate(date),
      'status': status,
      'createdOn': Timestamp.fromDate(createdOn),
    };
  }

  static Purchase fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'],
      supplierId: json['supplierId'],
      supplierName: json['supplierName'],
      items: (json['items'] as List)
          .map((item) => PurchaseItem.fromJson(item))
          .toList(),
      total: (json['total'] as num).toDouble(),
      date: (json['date'] as Timestamp).toDate(),
      status: json['status'],
      createdOn: (json['createdOn'] as Timestamp).toDate(),
    );
  }

  Purchase copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    List<PurchaseItem>? items,
    double? total,
    DateTime? date,
    String? status,
    DateTime? createdOn,
  }) {
    return Purchase(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
      total: total ?? this.total,
      date: date ?? this.date,
      status: status ?? this.status,
      createdOn: createdOn ?? this.createdOn,
    );
  }
}

class PurchaseItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;

  PurchaseItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
    };
  }

  static PurchaseItem fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      productId: json['productId'],
      productName: json['productName'],
      quantity: json['quantity'],
      unitPrice: (json['unitPrice'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }
}