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

  Future<void> _hide(UserModel user, String key) async {
    await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({
      'dashboardHiddenWidgets': FieldValue.arrayUnion([key]),
    }, SetOptions(merge: true));
  }

  Future<void> _show(UserModel user, String key) async {
    await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({
      'dashboardHiddenWidgets': FieldValue.arrayRemove([key]),
    }, SetOptions(merge: true));
  }

  Future<void> _restore(UserModel user) async {
    await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({
      'dashboardHiddenWidgets': <String>[],
    }, SetOptions(merge: true));
  }

  Future<void> _addWidgets(UserModel user, Set<String> hidden) async {
    if (!user.canAddWidgets) return;
    final available = <String, String>{
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
    final addable = hidden.where(available.containsKey).toList();
    if (addable.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All permitted widgets are already visible.')));
      return;
    }
    final selected = <String>{};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          title: const Text('Add Widgets'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                children: addable.map((k) => CheckboxListTile(
                  value: selected.contains(k),
                  title: Text(available[k]!),
                  onChanged: (v) => setModal(() => v == true ? selected.add(k) : selected.remove(k)),
                )).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, selected), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (result != null) {
      for (final key in result) {
        await _show(user, key);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final staffRef = FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('staff').doc(user.authUid);

    return ColoredBox(
      color: Colors.white,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('vendors').doc(user.authUid).snapshots(),
        builder: (_, prefSnap) {
          final hidden = Set<String>.from(prefSnap.data?.data()?['dashboardHiddenWidgets'] ?? const <String>[]);
          bool show(String key) => !hidden.contains(key);
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: staffRef.snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? <String, dynamic>{};
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
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_dashboardTitle(user.role), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.grey900)),
                      const SizedBox(height: 3),
                      Text('${user.department.isEmpty ? user.role.name : user.department} • ${user.branchName}', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                    ])),
                    if (user.canAddWidgets) OutlinedButton.icon(onPressed: () => _addWidgets(user, hidden), icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Add Widgets')),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(onPressed: () => _restore(user), icon: const Icon(Icons.restore_rounded, size: 16), label: const Text('Restore')),
                  ]),
                  const SizedBox(height: 14),
                  if (show('profile')) _WidgetBox(
                    title: 'Profile',
                    onClose: () => _hide(user, 'profile'),
                    child: Row(children: [
                      Stack(clipBehavior: Clip.none, children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppColors.primarySoft,
                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty ? Text(user.name.isEmpty ? 'U' : user.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.primary)) : null,
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
                                child: SizedBox(width: 28, height: 28, child: Center(child: _uploading ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white))),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(width: 15),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        Text(user.email, style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                      ])),
                    ]),
                  ),
                  if (show('profile')) const SizedBox(height: 12),
                  LayoutBuilder(builder: (_, c) {
                    final cardWidth = c.maxWidth >= 1100 ? (c.maxWidth - 60) / 6 : c.maxWidth >= 700 ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2;
                    return Wrap(spacing: 12, runSpacing: 12, children: [
                      if (show('hours')) _WorkedHours(width: cardWidth, user: user, onClose: () => _hide(user, 'hours')),
                      if (show('tips')) _Metric(width: cardWidth, label: 'My Tips', value: 'Rs ${tips.toStringAsFixed(0)}', icon: Icons.volunteer_activism_outlined, color: AppColors.success, onClose: () => _hide(user, 'tips')),
                      if (show('service')) _Metric(width: cardWidth, label: 'Service Charges', value: 'Rs ${serviceCharges.toStringAsFixed(0)}', icon: Icons.room_service_outlined, color: AppColors.secondary, onClose: () => _hide(user, 'service')),
                      if (showCommission && show('commission')) _Metric(width: cardWidth, label: 'My Commission', value: 'Rs ${commission.toStringAsFixed(0)}', icon: Icons.percent_rounded, color: AppColors.primary, onClose: () => _hide(user, 'commission')),
                      if (show('points')) _Metric(width: cardWidth, label: 'My Points', value: '$points', icon: Icons.stars_outlined, color: AppColors.warning, onClose: () => _hide(user, 'points')),
                      if (show('rating')) _Metric(width: cardWidth, label: 'Customer Rating', value: reviews == 0 ? 'No reviews' : '${rating.toStringAsFixed(1)} / 5', icon: Icons.rate_review_outlined, color: AppColors.info, onClose: () => _hide(user, 'rating')),
                    ]);
                  }),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (_, c) {
                    final width = c.maxWidth >= 900 ? (c.maxWidth - 24) / 3 : c.maxWidth >= 620 ? (c.maxWidth - 12) / 2 : c.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: actions.where((a) => show('feature_${a.route}')).map((a) => SizedBox(width: width, child: _FeatureWidget(action: a, onClose: () => _hide(user, 'feature_${a.route}')))).toList(),
                    );
                  }),
                  if (show('reviews')) ...[
                    const SizedBox(height: 12),
                    _WidgetBox(title: 'Customer Reviews', onClose: () => _hide(user, 'reviews'), child: Text(reviews == 0 ? 'No reviews recorded yet.' : '$reviews reviews • ${rating.toStringAsFixed(1)} / 5 average', style: const TextStyle(fontSize: 10.5, color: AppColors.grey500))),
                  ],
                ]),
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
      case UserRole.waiter: return 'Waiter Dashboard';
      case UserRole.cashier: return 'Cashier Dashboard';
      case UserRole.kitchen: return 'Kitchen Dashboard';
      case UserRole.accounts: return 'Accounts Dashboard';
      case UserRole.operations: return 'Operations Dashboard';
      case UserRole.inventory: return 'Inventory Dashboard';
      case UserRole.delivery: return 'Delivery Dashboard';
      case UserRole.reception: return 'Reception Dashboard';
      default: return 'My Dashboard';
    }
  }

  List<_Action> _actionsFor(UserRole role) {
    switch (role) {
      case UserRole.waiter:
      case UserRole.cashier:
      case UserRole.staff:
        return const [
          _Action('Tables', 'Open and manage assigned tables', Icons.table_restaurant_outlined, AppRouter.tables),
          _Action('Billing / KOT', 'Orders, KOT and checkout', Icons.receipt_long_outlined, AppRouter.orders),
        ];
      case UserRole.kitchen:
        return const [_Action('Kitchen Orders', 'Live KOT preparation queue', Icons.soup_kitchen_outlined, AppRouter.orders)];
      case UserRole.accounts:
        return const [
          _Action('Sales', 'Sales and receipt records', Icons.point_of_sale_outlined, AppRouter.sales),
          _Action('Operations', 'Purchases and operational transactions', Icons.receipt_long_outlined, AppRouter.purchases),
          _Action('Returns', 'Sales returns and refunds', Icons.assignment_return_outlined, AppRouter.salesReturn),
        ];
      case UserRole.operations:
        return const [
          _Action('Operations', 'Purchases and operations', Icons.receipt_long_outlined, AppRouter.purchases),
          _Action('Inventory', 'Products and stock', Icons.inventory_2_outlined, AppRouter.products),
          _Action('Vendors', 'Supplier management', Icons.local_shipping_outlined, AppRouter.suppliers),
          _Action('Recipes', 'Recipe and ingredient control', Icons.menu_book_outlined, AppRouter.ingredients),
        ];
      case UserRole.inventory:
        return const [
          _Action('Inventory', 'Products and stock', Icons.inventory_2_outlined, AppRouter.products),
          _Action('Vendors', 'Supplier management', Icons.local_shipping_outlined, AppRouter.suppliers),
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
      default: return const [];
    }
  }
}

class _WidgetBox extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onClose;
  const _WidgetBox({required this.title, required this.child, required this.onClose});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))), IconButton(tooltip: 'Remove widget', onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.grey400))]),
      child,
    ]),
  );
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
      stream: FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('auditSessions').where('loginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).snapshots(),
      builder: (_, snap) {
        var minutes = 0;
        for (final doc in snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
          final d = doc.data();
          if ((d['authUid'] ?? '').toString() != user.authUid) continue;
          final login = d['loginAt'] is Timestamp ? (d['loginAt'] as Timestamp).toDate() : null;
          minutes += d['active'] == true && login != null ? DateTime.now().difference(login).inMinutes : (d['durationMinutes'] as num?)?.toInt() ?? 0;
        }
        return _Metric(width: width, label: 'Worked Today', value: '${minutes ~/ 60}h ${minutes % 60}m', icon: Icons.schedule_outlined, color: AppColors.secondary, onClose: onClose);
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final double width;
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback onClose;
  const _Metric({required this.width, required this.label, required this.value, required this.icon, required this.color, required this.onClose});
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 96,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 10),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.grey500))])),
      Align(alignment: Alignment.topRight, child: InkWell(onTap: onClose, child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.close_rounded, size: 15, color: AppColors.grey400)))),
    ]),
  );
}

class _FeatureWidget extends StatelessWidget {
  final _Action action;
  final VoidCallback onClose;
  const _FeatureWidget({required this.action, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 146),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(9)), child: Icon(action.icon, color: AppColors.primary, size: 18)),
        const Spacer(),
        IconButton(tooltip: 'Remove widget', visualDensity: VisualDensity.compact, onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 15, color: AppColors.grey400)),
      ]),
      const SizedBox(height: 4),
      Text(action.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(action.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () => context.go(action.route),
          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
          label: const Text('Open'),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(88, 34), padding: const EdgeInsets.symmetric(horizontal: 12)),
        ),
      ),
    ]),
  );
}

class _Action {
  final String label, subtitle;
  final IconData icon;
  final String route;
  const _Action(this.label, this.subtitle, this.icon, this.route);
}
