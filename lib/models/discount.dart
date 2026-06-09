import 'package:cloud_firestore/cloud_firestore.dart';

class Discount {
  final String id;
  final String name;
  final String description;
  final String type; 
  final double value; 
  final String imageUrl; 
  final bool isActive;
  final String vendorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Discount({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.imageUrl,
    required this.isActive,
    required this.vendorId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Discount.fromMap(Map<String, dynamic> map, String id) {
    return Discount(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'percentage',
      value: (map['value'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      isActive: map['isActive'] ?? true,
      vendorId: map['vendorId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type,
      'value': value,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'vendorId': vendorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Discount copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    double? value,
    String? imageUrl,
    bool? isActive,
    String? vendorId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Discount(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      vendorId: vendorId ?? this.vendorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isValid => isActive;

  bool canBeUsed() {
    return isActive;
  }

  double calculateDiscount(double amount) {
    if (type == 'percentage') {
      return amount * (value / 100);
    } else {
      return value;
    }
  }
}