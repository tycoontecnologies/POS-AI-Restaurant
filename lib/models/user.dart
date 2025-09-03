import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, kitchen, user, staff }

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: _parseRole(data['role']),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  static UserRole _parseRole(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'kitchen':
        return UserRole.kitchen;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.user;
    }
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isKitchen => role == UserRole.kitchen;
  bool get isStaff => role == UserRole.staff;
  bool get isRegularUser => role == UserRole.user;
}
