import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String id;
  final String name;
  final String phone;
  final String address;
  final bool active;
  final DateTime createdOn;
  final double amountToReceive; // New field
  final double amountToPay;     // New field

  Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.active,
    required this.createdOn,
    this.amountToReceive = 0.0, // Default value
    this.amountToPay = 0.0,     // Default value
  });

  factory Supplier.fromMap(Map<String, dynamic> data, String id) {
    return Supplier(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      active: data['active'] ?? true,
      createdOn: data['createdOn'] != null
          ? (data['createdOn'] as Timestamp).toDate()
          : DateTime.now(),
      amountToReceive: (data['amountToReceive'] as num?)?.toDouble() ?? 0.0,
      amountToPay: (data['amountToPay'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    bool? active,
    DateTime? createdOn,
    double? amountToReceive,
    double? amountToPay,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      active: active ?? this.active,
      createdOn: createdOn ?? this.createdOn,
      amountToReceive: amountToReceive ?? this.amountToReceive,
      amountToPay: amountToPay ?? this.amountToPay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'active': active,
      'createdOn': Timestamp.fromDate(createdOn),
      'amountToReceive': amountToReceive,
      'amountToPay': amountToPay,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Supplier &&
        other.id == id &&
        other.name == name &&
        other.phone == phone &&
        other.address == address &&
        other.active == active &&
        other.createdOn == createdOn &&
        other.amountToReceive == amountToReceive &&
        other.amountToPay == amountToPay;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, phone, address, active, createdOn, 
        amountToReceive, amountToPay);
  }
}