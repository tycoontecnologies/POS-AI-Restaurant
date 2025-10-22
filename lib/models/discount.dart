import 'package:cloud_firestore/cloud_firestore.dart';

class Discount {
  final String id;
  final String name;
  final String description;
  final String type; // 'percentage' or 'fixed'
  final double value; // percentage (0-100) or fixed amount
  final List<String> applicableProductIds; // empty = all products
  final List<String> applicableCategoryIds; // empty = all categories
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final int maxUsageCount; // -1 = unlimited
  final int currentUsageCount;
  final String vendorId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Discount({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.applicableProductIds,
    required this.applicableCategoryIds,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.maxUsageCount,
    required this.currentUsageCount,
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
      applicableProductIds: List<String>.from(map['applicableProductIds'] ?? []),
      applicableCategoryIds: List<String>.from(map['applicableCategoryIds'] ?? []),
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      maxUsageCount: map['maxUsageCount'] ?? -1,
      currentUsageCount: map['currentUsageCount'] ?? 0,
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
      'applicableProductIds': applicableProductIds,
      'applicableCategoryIds': applicableCategoryIds,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isActive': isActive,
      'maxUsageCount': maxUsageCount,
      'currentUsageCount': currentUsageCount,
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
    List<String>? applicableProductIds,
    List<String>? applicableCategoryIds,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    int? maxUsageCount,
    int? currentUsageCount,
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
      applicableProductIds: applicableProductIds ?? this.applicableProductIds,
      applicableCategoryIds: applicableCategoryIds ?? this.applicableCategoryIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      maxUsageCount: maxUsageCount ?? this.maxUsageCount,
      currentUsageCount: currentUsageCount ?? this.currentUsageCount,
      vendorId: vendorId ?? this.vendorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool isValidNow() {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && (endDate == null || now.isBefore(endDate!));
  }

  bool canBeUsed() {
    return isValidNow() && (maxUsageCount == -1 || currentUsageCount < maxUsageCount);
  }

  double calculateDiscount(double amount) {
    if (type == 'percentage') {
      return amount * (value / 100);
    } else {
      return value;
    }
  }
}
