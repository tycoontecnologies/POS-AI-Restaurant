import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, kitchen, user, staff }

enum SubscriptionType { trial, monthly, yearly, lifetime }

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  final bool isActive;
  final DateTime trialEndsAt;
  final SubscriptionType subscriptionType;
  final DateTime? subscriptionEndsAt;
  final bool hasActiveSubscription;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.isActive = true,
    required this.trialEndsAt,
    required this.subscriptionType,
    this.subscriptionEndsAt,
    this.hasActiveSubscription = false,
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
      trialEndsAt: data['trialEndsAt'] != null
          ? (data['trialEndsAt'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(minutes: 3)),
      // : DateTime.now().add(const Duration(days: 7)),
      subscriptionType: _parseSubscriptionType(data['subscriptionType']),
      subscriptionEndsAt: data['subscriptionEndsAt'] != null
          ? (data['subscriptionEndsAt'] as Timestamp).toDate()
          : null,
      hasActiveSubscription: data['hasActiveSubscription'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'trialEndsAt': Timestamp.fromDate(trialEndsAt),
      'subscriptionType': subscriptionType.toString().split('.').last,
      'subscriptionEndsAt': subscriptionEndsAt != null
          ? Timestamp.fromDate(subscriptionEndsAt!)
          : null,
      'hasActiveSubscription': hasActiveSubscription,
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

  static SubscriptionType _parseSubscriptionType(String type) {
    switch (type) {
      case 'monthly':
        return SubscriptionType.monthly;
      case 'yearly':
        return SubscriptionType.yearly;
      case 'lifetime':
        return SubscriptionType.lifetime;
      default:
        return SubscriptionType.trial;
    }
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isKitchen => role == UserRole.kitchen;
  bool get isStaff => role == UserRole.staff;
  bool get isRegularUser => role == UserRole.user;

  bool get isTrialActive => trialEndsAt.isAfter(DateTime.now());
  bool get shouldRedirectToPricing => !isTrialActive && !hasActiveSubscription;
}
