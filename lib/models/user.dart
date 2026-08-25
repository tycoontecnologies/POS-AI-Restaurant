import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { superAdmin, admin, manager, cashier, waiter, kitchen, operations, accounts, inventory, delivery, reception, auditor, staff, user }
enum SubscriptionType { trial, monthly, yearly, lifetime }

class UserModel {
  static const String addWidgetsPermission = 'add_widgets';
  static const String viewEmployeesWidgetPermission = 'widget_employees';
  static const String viewAccountsWidgetPermission = 'widget_accounts';
  static const String viewStoreWidgetPermission = 'widget_store';
  static const String viewKotWidgetPermission = 'widget_kot';
  static const String viewPaymentsWidgetPermission = 'widget_payments';
  static const String viewPraWidgetPermission = 'widget_pra';
  static const String viewCamerasWidgetPermission = 'widget_cameras';
  static const String viewLeakageWidgetPermission = 'widget_leakage';
  static const String viewBranchesWidgetPermission = 'widget_branches';

  final String id;
  final String authUid;
  final String email;
  final String name;
  final UserRole role;
  final String department;
  final List<String> permissions;
  final String branchId;
  final String branchName;
  final DateTime createdAt;
  final bool isActive;
  final DateTime trialEndsAt;
  final SubscriptionType subscriptionType;
  final DateTime? subscriptionEndsAt;
  final bool hasActiveSubscription;
  final String location;
  final String phoneNo;
  final String restaurantName;
  final String? restaurantLogoUrl;

  UserModel({required this.id, String? authUid, required this.email, required this.name, required this.role, this.department = '', this.permissions = const [], this.branchId = 'main', this.branchName = 'Main Branch', required this.createdAt, this.isActive = true, required this.trialEndsAt, required this.subscriptionType, this.subscriptionEndsAt, this.hasActiveSubscription = false, required this.location, required this.phoneNo, required this.restaurantName, this.restaurantLogoUrl}) : authUid = authUid ?? id;

  factory UserModel.fromMap(Map<String, dynamic> data, String authDocumentId) {
    final tenantId = (data['ownerId'] ?? data['restaurantId'] ?? authDocumentId).toString();
    return UserModel(id: tenantId, authUid: authDocumentId, email: data['email'] ?? '', name: data['name'] ?? '', role: _parseRole((data['role'] ?? '').toString()), department: (data['department'] ?? '').toString(), permissions: List<String>.from(data['permissions'] ?? const <String>[]), branchId: (data['branchId'] ?? 'main').toString(), branchName: (data['branchName'] ?? 'Main Branch').toString(), createdAt: _toDate(data['createdAt']) ?? DateTime.now(), isActive: data['isActive'] ?? true, trialEndsAt: _toDate(data['trialEndsAt']) ?? DateTime.now().add(const Duration(days: 7)), subscriptionType: _parseSubscriptionType((data['subscriptionType'] ?? '').toString()), subscriptionEndsAt: _toDate(data['subscriptionEndsAt']), hasActiveSubscription: data['hasActiveSubscription'] ?? false, location: data['location'] ?? '', phoneNo: data['phoneNo'] ?? '', restaurantName: data['restaurantName'] ?? '', restaurantLogoUrl: data['restaurantLogoUrl']);
  }

  Map<String, dynamic> toMap() => {'email': email, 'name': name, 'role': role.name, 'department': department, 'permissions': permissions, 'ownerId': id, 'branchId': branchId, 'branchName': branchName, 'createdAt': Timestamp.fromDate(createdAt), 'isActive': isActive, 'trialEndsAt': Timestamp.fromDate(trialEndsAt), 'subscriptionType': subscriptionType.name, 'subscriptionEndsAt': subscriptionEndsAt != null ? Timestamp.fromDate(subscriptionEndsAt!) : null, 'hasActiveSubscription': hasActiveSubscription, 'location': location, 'phoneNo': phoneNo, 'restaurantName': restaurantName, 'restaurantLogoUrl': restaurantLogoUrl};

  static DateTime? _toDate(dynamic value) { if (value == null) return null; if (value is Timestamp) return value.toDate(); if (value is DateTime) return value; return null; }
  static UserRole _parseRole(String role) { switch (role) { case 'superAdmin': case 'super_admin': return UserRole.superAdmin; case 'admin': return UserRole.admin; case 'manager': return UserRole.manager; case 'cashier': return UserRole.cashier; case 'waiter': return UserRole.waiter; case 'kitchen': return UserRole.kitchen; case 'operations': return UserRole.operations; case 'accounts': return UserRole.accounts; case 'inventory': return UserRole.inventory; case 'delivery': return UserRole.delivery; case 'reception': return UserRole.reception; case 'auditor': case 'ownerView': return UserRole.auditor; case 'staff': return UserRole.staff; default: return UserRole.user; } }
  static SubscriptionType _parseSubscriptionType(String type) { switch (type) { case 'monthly': return SubscriptionType.monthly; case 'yearly': return SubscriptionType.yearly; case 'lifetime': return SubscriptionType.lifetime; default: return SubscriptionType.trial; } }

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
  bool get isManager => role == UserRole.manager;
  bool get isKitchen => role == UserRole.kitchen;
  bool get isStaff => role == UserRole.staff || role == UserRole.cashier || role == UserRole.waiter;
  bool get isRegularUser => role == UserRole.user;
  bool get isDepartmentAccount => authUid != id;
  bool get isTrialActive => trialEndsAt.isAfter(DateTime.now());
  bool get shouldRedirectToPricing => !isTrialActive && !hasActiveSubscription;

  /// Super Admin/Admin can always customize. Other users require the explicit Add Widgets right.
  bool get canAddWidgets => isAdmin || permissions.contains(addWidgetsPermission);
  bool hasPermission(String permission) => isAdmin || permissions.contains(permission);
  bool canAddWidget(String widgetPermission) => canAddWidgets && hasPermission(widgetPermission);
}
