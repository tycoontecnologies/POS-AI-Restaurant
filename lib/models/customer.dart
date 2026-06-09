import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String? email; 
  final String phone;
  final String address;
  final String? city;
  final bool active;
  final DateTime createdOn;
  final double totalSpent;

  Customer({
    required this.id,
    required this.name,
    this.email, 
    required this.phone,
    required this.address,
    this.city,
    required this.active,
    required this.createdOn,
    this.totalSpent = 0.0,
  });

  factory Customer.fromMap(Map<String, dynamic> data, String id) {
    return Customer(
      id: id,
      name: data['name'] ?? '',
      email: data['email'], 
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      city: data['city'],
      active: data['active'] ?? true,
      createdOn: data['createdOn'] != null
          ? (data['createdOn'] as Timestamp).toDate()
          : DateTime.now(),
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    bool? active,
    DateTime? createdOn,
    double? totalSpent,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      active: active ?? this.active,
      createdOn: createdOn ?? this.createdOn,
      totalSpent: totalSpent ?? this.totalSpent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email, // Can be null
      'phone': phone,
      'address': address,
      'city': city,
      // Removed country
      'active': active,
      'createdOn': Timestamp.fromDate(createdOn),
      'totalSpent': totalSpent,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.phone == phone &&
        other.address == address &&
        other.city == city &&
        other.active == active &&
        other.createdOn == createdOn &&
        other.totalSpent == totalSpent;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, email, phone, address, city, active,
        createdOn, totalSpent); 
  }
}