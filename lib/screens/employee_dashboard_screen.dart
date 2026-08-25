import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_colors.dart';
import 'package:provider/provider.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  bool _uploading = false;

  Future<void> _setHidden(UserModel user, String key, bool hidden) async {
    await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({
      'dashboardHiddenWidgets': hidden
          ? FieldValue.arrayUnion([key])
          : FieldValue.arrayRemove([key]),
    }, SetOptions(merge: true));
  }

  Future<void> _restore(UserModel user) async {
    await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({
      'dashboardHiddenWidgets': <String>[],
    }, SetOptions(merge: true));
  }

  Future<void> _addWidgets(UserModel user, Set<String> hidden) async {
    if (!user.canAddWidgets) return;
    final all = <String, String>{
      'profile': 'Profile',
      'hours': 'Worked Today',
      'tips': 'My Tips',
      'service': 'Service Charges',
      'commission': 'My Commission',
      'points': 'My Points',
      'rating': 'Customer Rating',
      'reviews': 'Customer Reviews',
      for (final a in _actionsFor(user.role)) 'feature_${a.route}': a.label,
    };
    final addable = hidden.where(all.containsKey).toList();
    if (addable.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All permitted widgets are already visible.')),
        );
      }
      return;
    }

    final selected = <String>{};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Add Widgets'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                children: addable
                    .map(
                      (key) => CheckboxListTile(
                        dense: true,
                        value: selected.contains(key),
                        title: Text(all[key]!),
                        onChanged: (value) => setModal(() {
                          if (value == true) {
                            selected.add(key);
                          } else {
                            selected.remove(key);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, selected), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (result == null) return;
    for (final key in result) {
      await _setHidden(user, key, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final vendorRef = FirebaseFirestore.instance.collection('vendors').doc(user.id);
    final userRef = FirebaseFirestore.instance.collection('vendors').doc(user.authUid);
    final staffRef = vendorRef.collection('staff').doc(user.authUid);

    return ColoredBox(
      color: AppColors.backgroundLight,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (_, prefSnap) {
          final hidden = Set<String>.from(
            prefSnap.data?.data()?['dashboardHiddenWidgets'] ?? const <String>[],
          );
          bool show(String key) => !hidden.contains(key);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: staffRef.snapshots(),
            builder: (context, staffSnap) {
              final data = staffSnap.data?.data() ?? <String, dynamic>{};
              final photoUrl = (data['photoUrl'] ?? '').toString();
              final canChangePhoto = data['canChangePhoto'] == true;
              final tips = (data['tipsEarned'] ?? 0).toDouble();
              final commission = (data['commissionEarned'] ?? 0).toDouble();
              final serviceCharges = (data['serviceChargesEarned'] ?? 0).toDouble();
              final showCommission = data['showCommissionToStaff'] == true;
              final points = (data['pointsEarned'] ?? 0).toInt();
              final rating = (data['averageRating'] ?? 0).toDouble();
              final reviews = (data['reviewCount'] ?? 0).toInt();
              final actions = _actionsFor(user.role);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _dashboardTitle(user.role),
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.grey900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${user.department.isEmpty ? _roleName(user.role) : user.department} • ${user.branchName}',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.grey500),
                              ),
                            ],
                          ),
                        ),
                        if (user.canAddWidgets)
                          OutlinedButton.icon(
                            onPressed: () => _addWidgets(user, hidden),
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text('Add Widgets'),
                          ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _restore(user),
                          icon: const Icon(Icons.restore_rounded, size: 17),
                          label: const Text('Restore'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (show('profile')) ...[
                      _DashboardWidget(
                        title: 'Profile',
                        subtitle: 'Your account and workstation identity',
                        onClose: () => _setHidden(user, 'profile', true),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 34,
                                  backgroundColor: AppColors.primarySoft,
                                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                  child: photoUrl.isEmpty
                                      ? Text(
                                          user.name.isEmpty ? 'U' : user.name.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 23,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : null,
                                ),
                                if (canChangePhoto)
                                  Positioned(
                                    right: -3,
                                    bottom: -2,
                                    child: Material(
                                      color: AppColors.primary,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _uploading ? null : () => _pickPhoto(user),
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: Center(
                                            child: _uploading
                                                ? const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 3),
                                  Text(user.email, style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    LayoutBuilder(
                      builder: (_, constraints) {
                        final width = constraints.maxWidth >= 1100
                            ? (constraints.maxWidth - 48) / 5
                            : constraints.maxWidth >= 700
                                ? (constraints.maxWidth - 24) / 3
                                : (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (show('hours'))
                              _WorkedHours(width: width, user: user, onClose: () => _setHidden(user, 'hours', true)),
                            if (show('tips'))
                              _MetricWidget(width: width, label: 'My Tips', value: 'Rs ${tips.toStringAsFixed(0)}', icon: Icons.volunteer_activism_outlined, color: AppColors.success, onClose: () => _setHidden(user, 'tips', true)),
                            if (show('service'))
                              _MetricWidget(width: width, label: 'Service Charges', value: 'Rs ${serviceCharges.toStringAsFixed(0)}', icon: Icons.room_service_outlined, color: AppColors.secondary, onClose: () => _setHidden(user, 'service', true)),
                            if (showCommission && show('commission'))
                              _MetricWidget(width: width, label: 'My Commission', value: 'Rs ${commission.toStringAsFixed(0)}', icon: Icons.percent_rounded, color: AppColors.primary, onClose: () => _setHidden(user, 'commission', true)),
                            if (show('points'))
                              _MetricWidget(width: width, label: 'My Points', value: '$points', icon: Icons.stars_outlined, color: AppColors.warning, onClose: () => _setHidden(user, 'points', true)),
                            if (show('rating'))
                              _MetricWidget(width: width, label: 'Customer Rating', value: reviews == 0 ? 'No reviews' : '${rating.toStringAsFixed(1)} / 5', icon: Icons.rate_review_outlined, color: AppColors.info, onClose: () => _setHidden(user, 'rating', true)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (_, constraints) {
                        final width = constraints.maxWidth >= 1000
                            ? (constraints.maxWidth - 24) / 3
                            : constraints.maxWidth >= 650
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: actions
                              .where((a) => show('feature_${a.route}'))
                              .map(
                                (a) => SizedBox(
                                  width: width,
                                  child: _FeatureWidget(
                                    action: a,
                                    onClose: () => _setHidden(user, 'feature_${a.route}', true),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    if (show('reviews')) ...[
                      const SizedBox(height: 12),
                      _DashboardWidget(
                        title: 'Customer Reviews',
                        subtitle: 'Feedback linked to your service profile',
                        onClose: () => _setHidden(user, 'reviews', true),
                        child: Text(
                          reviews == 0 ? 'No reviews recorded yet.' : '$reviews reviews • ${rating.toStringAsFixed(1)} / 5 average',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.grey600),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickPhoto(UserModel user) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 900);
      if (file == null) return;
      setState(() => _uploading = true);
      final Uint8List bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance.ref('vendors/${user.id}/staff/${user.authUid}/profile.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'));
      final url = await ref.getDownloadURL();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('staff').doc(user.authUid), {'photoUrl': url}, SetOptions(merge: true));
      batch.set(FirebaseFirestore.instance.collection('vendors').doc(user.authUid), {'photoUrl': url}, SetOptions(merge: true));
      await batch.commit();
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _dashboardTitle(UserRole role) {
    switch (role) {
      case UserRole.waiter:
        return 'Waiter Dashboard';
      case UserRole.cashier:
        return 'Cashier Dashboard';
      case UserRole.kitchen:
        return 'Kitchen Dashboard';
      case UserRole.accounts:
        return 'Accounts Dashboard';
      case UserRole.operations:
        return 'Operations Dashboard';
      case UserRole.inventory:
        return 'Inventory Dashboard';
      case UserRole.delivery:
        return 'Delivery Dashboard';
      case UserRole.reception:
        return 'Reception Dashboard';
      case UserRole.manager:
        return 'Manager Dashboard';
      case UserRole.auditor:
        return 'Owner / Auditor Dashboard';
      default:
        return 'My Dashboard';
    }
  }
}

String _roleName(UserRole role) => role.name
    .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}')
    .trim();

List<_Action> _actionsFor(UserRole role) {
  switch (role) {
    case UserRole.superAdmin:
    case UserRole.admin:
    case UserRole.manager:
    case UserRole.auditor:
      return const [
        _Action('Tables', 'Live floor, guest seating and table controls', Icons.table_restaurant_outlined, AppRouter.tables),
        _Action('Billing / KOT', 'Orders, kitchen flow and checkout', Icons.receipt_long_outlined, AppRouter.orders),
        _Action('Inventory', 'Products, stock and variants', Icons.inventory_2_outlined, AppRouter.products),
        _Action('Sales', 'Sales and receipt history', Icons.point_of_sale_outlined, AppRouter.sales),
        _Action('Returns', 'Sales returns and refunds', Icons.assignment_return_outlined, AppRouter.salesReturn),
        _Action('CRM', 'Customers and feedback', Icons.people_alt_outlined, AppRouter.customers),
        _Action('Operations', 'Purchases and operating transactions', Icons.settings_suggest_outlined, AppRouter.purchases),
        _Action('Store', 'Store issue and stock movement', Icons.storefront_outlined, AppRouter.storeOut),
        _Action('Expenses', 'Expense recording and control', Icons.payments_outlined, AppRouter.expenses),
        _Action('Suppliers', 'Supplier and vendor management', Icons.local_shipping_outlined, AppRouter.suppliers),
        _Action('Recipes', 'Recipes and ingredient controls', Icons.menu_book_outlined, AppRouter.ingredients),
        _Action('Branches', 'Branch and location management', Icons.account_tree_outlined, AppRouter.branches),
        _Action('PRA', 'Fiscal / PRA settings and monitoring', Icons.verified_user_outlined, AppRouter.praSettings),
        _Action('Users & Roles', 'Department users and permissions', Icons.manage_accounts_outlined, AppRouter.usersRoles),
        _Action('Settings', 'Restaurant and interface settings', Icons.settings_outlined, AppRouter.settings),
      ];
    case UserRole.waiter:
    case UserRole.cashier:
    case UserRole.staff:
      return const [
        _Action('Tables', 'Open and manage assigned tables', Icons.table_restaurant_outlined, AppRouter.tables),
        _Action('Billing / KOT', 'Orders, KOT and checkout', Icons.receipt_long_outlined, AppRouter.orders),
        _Action('CRM', 'Customer details allowed for your role', Icons.people_alt_outlined, AppRouter.customers),
      ];
    case UserRole.kitchen:
      return const [
        _Action('Kitchen Orders', 'Live KOT preparation queue', Icons.soup_kitchen_outlined, AppRouter.orders),
        _Action('Recipes', 'Recipe and ingredient reference', Icons.menu_book_outlined, AppRouter.ingredients),
      ];
    case UserRole.accounts:
      return const [
        _Action('Sales', 'Sales and receipt records', Icons.point_of_sale_outlined, AppRouter.sales),
        _Action('Expenses', 'Expense records and ledgers', Icons.payments_outlined, AppRouter.expenses),
        _Action('Operations', 'Purchases and transactions', Icons.receipt_long_outlined, AppRouter.purchases),
        _Action('Returns', 'Returns and refunds', Icons.assignment_return_outlined, AppRouter.salesReturn),
        _Action('Suppliers', 'Supplier ledgers', Icons.local_shipping_outlined, AppRouter.suppliers),
      ];
    case UserRole.operations:
      return const [
        _Action('Operations', 'Purchases and operations', Icons.receipt_long_outlined, AppRouter.purchases),
        _Action('Inventory', 'Products and stock', Icons.inventory_2_outlined, AppRouter.products),
        _Action('Store', 'Store issue and material movement', Icons.storefront_outlined, AppRouter.storeOut),
        _Action('Suppliers', 'Supplier management', Icons.local_shipping_outlined, AppRouter.suppliers),
        _Action('Recipes', 'Recipe and ingredient control', Icons.menu_book_outlined, AppRouter.ingredients),
      ];
    case UserRole.inventory:
      return const [
        _Action('Inventory', 'Products and stock', Icons.inventory_2_outlined, AppRouter.products),
        _Action('Store', 'Store issue and material movement', Icons.storefront_outlined, AppRouter.storeOut),
        _Action('Suppliers', 'Supplier management', Icons.local_shipping_outlined, AppRouter.suppliers),
        _Action('Operations', 'Purchases and inward stock', Icons.receipt_long_outlined, AppRouter.purchases),
      ];
    case UserRole.delivery:
      return const [
        _Action('Orders', 'Delivery order queue', Icons.delivery_dining_outlined, AppRouter.orders),
        _Action('CRM', 'Customer details', Icons.people_alt_outlined, AppRouter.customers),
      ];
    case UserRole.reception:
      return const [
        _Action('Tables', 'Floor and guest seating', Icons.table_restaurant_outlined, AppRouter.tables),
        _Action('CRM', 'Customer details', Icons.people_alt_outlined, AppRouter.customers),
      ];
    case UserRole.user:
      return const [];
  }
}

class _DashboardWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onClose;

  const _DashboardWidget({required this.title, this.subtitle, required this.child, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineLight),
        boxShadow: const [BoxShadow(color: Color(0x090F172A), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppColors.grey900)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove widget',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 17, color: AppColors.grey400),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _MetricWidget extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onClose;

  const _MetricWidget({required this.width, required this.label, required this.value, required this.icon, required this.color, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineLight),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.grey900)),
                const SizedBox(height: 3),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              tooltip: 'Remove widget',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 15, color: AppColors.grey400),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkedHours extends StatelessWidget {
  final double width;
  final UserModel user;
  final VoidCallback onClose;

  const _WorkedHours({required this.width, required this.user, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('vendors')
          .doc(user.id)
          .collection('auditSessions')
          .where('loginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .snapshots(),
      builder: (_, snap) {
        var minutes = 0;
        for (final doc in snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
          final data = doc.data();
          if ((data['authUid'] ?? data['userId'] ?? '').toString() != user.authUid) continue;
          final login = data['loginAt'];
          final logout = data['logoutAt'];
          if (login is Timestamp) {
            final end = logout is Timestamp ? logout.toDate() : DateTime.now();
            minutes += end.difference(login.toDate()).inMinutes.clamp(0, 24 * 60);
          }
        }
        return _MetricWidget(
          width: width,
          label: 'Worked Today',
          value: '${minutes ~/ 60}h ${minutes % 60}m',
          icon: Icons.schedule_rounded,
          color: AppColors.primary,
          onClose: onClose,
        );
      },
    );
  }
}

class _FeatureWidget extends StatelessWidget {
  final _Action action;
  final VoidCallback onClose;

  const _FeatureWidget({required this.action, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineLight),
        boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(action.icon, color: AppColors.primary, size: 20),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove widget',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.grey400),
              ),
            ],
          ),
          const Spacer(),
          Text(action.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.grey900)),
          const SizedBox(height: 3),
          Text(action.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.go(action.route),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Open', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action {
  final String label;
  final String description;
  final IconData icon;
  final String route;

  const _Action(this.label, this.description, this.icon, this.route);
}
