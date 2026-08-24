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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final staffRef = FirebaseFirestore.instance
        .collection('vendors')
        .doc(user.id)
        .collection('staff')
        .doc(user.authUid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: staffRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final photoUrl = (data['photoUrl'] ?? '').toString();
        final canChangePhoto = data['canChangePhoto'] == true;
        final tips = (data['tipsEarned'] ?? 0).toDouble();
        final commission = (data['commissionEarned'] ?? 0).toDouble();
        final showCommission = data['showCommissionToStaff'] == true;
        final points = (data['pointsEarned'] ?? 0).toInt();
        final rating = (data['averageRating'] ?? 0).toDouble();
        final reviews = (data['reviewCount'] ?? 0).toInt();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_dashboardTitle(user.role), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                const SizedBox(height: 4),
                Text('${user.department.isEmpty ? user.role.name : user.department}  •  ${user.branchName}', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                child: Text(user.role.name.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            ]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.outlineLight)),
              child: Row(children: [
                Stack(clipBehavior: Clip.none, children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.primarySoft,
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty ? Text(user.name.isEmpty ? 'U' : user.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)) : null,
                  ),
                  if (canChangePhoto)
                    Positioned(
                      right: -4,
                      bottom: -2,
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploading ? null : () => _pickPhoto(user),
                          child: SizedBox(width: 30, height: 30, child: Center(child: _uploading ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt_outlined, size: 15, color: Colors.white))),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                  const SizedBox(height: 3),
                  Text(user.email, style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                  const SizedBox(height: 8),
                  Text(canChangePhoto ? 'You can update your profile photo.' : 'Profile photo changes are controlled by Admin.', style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)),
                ])),
              ]),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (_, c) {
              final cardWidth = c.maxWidth >= 1000 ? (c.maxWidth - 48) / 5 : c.maxWidth >= 700 ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2;
              final cards = <Widget>[
                _WorkedHoursCard(width: cardWidth, user: user),
                _Metric(width: cardWidth, label: 'Tips Earned', value: 'Rs ${tips.toStringAsFixed(0)}', icon: Icons.volunteer_activism_outlined, color: AppColors.success),
                if (showCommission) _Metric(width: cardWidth, label: 'Commission', value: 'Rs ${commission.toStringAsFixed(0)}', icon: Icons.percent_rounded, color: AppColors.primary),
                _Metric(width: cardWidth, label: 'Points', value: '$points', icon: Icons.stars_outlined, color: AppColors.warning),
                _Metric(width: cardWidth, label: 'Customer Rating', value: reviews == 0 ? 'No reviews' : '${rating.toStringAsFixed(1)} / 5', icon: Icons.rate_review_outlined, color: AppColors.info),
              ];
              return Wrap(spacing: 12, runSpacing: 12, children: cards);
            }),
            const SizedBox(height: 18),
            const Text('My Controls', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.grey900)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: _actionsFor(user.role).map((a) => _ActionCard(action: a)).toList()),
            const SizedBox(height: 18),
            _ReviewsPanel(user: user),
          ]),
        );
      },
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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to update photo: $e'), backgroundColor: AppColors.error));
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
      case UserRole.auditor:
        return 'Owner / Auditor Dashboard';
      default:
        return 'My Dashboard';
    }
  }

  List<_Action> _actionsFor(UserRole role) {
    switch (role) {
      case UserRole.waiter:
      case UserRole.cashier:
      case UserRole.staff:
        return const [
          _Action('Tables', Icons.table_restaurant_outlined, AppRouter.tables),
          _Action('Billing', Icons.receipt_long_outlined, AppRouter.orders),
          _Action('Sales', Icons.point_of_sale_outlined, AppRouter.sales),
        ];
      case UserRole.kitchen:
        return const [_Action('Kitchen Orders', Icons.soup_kitchen_outlined, AppRouter.orders)];
      case UserRole.accounts:
        return const [
          _Action('Sales', Icons.point_of_sale_outlined, AppRouter.sales),
          _Action('Operations', Icons.receipt_long_outlined, AppRouter.purchases),
          _Action('Returns', Icons.assignment_return_outlined, AppRouter.salesReturn),
        ];
      case UserRole.operations:
        return const [
          _Action('Operations', Icons.receipt_long_outlined, AppRouter.purchases),
          _Action('Inventory', Icons.inventory_2_outlined, AppRouter.products),
          _Action('Vendors', Icons.local_shipping_outlined, AppRouter.suppliers),
          _Action('Recipes', Icons.menu_book_outlined, AppRouter.ingredients),
        ];
      case UserRole.inventory:
        return const [
          _Action('Inventory', Icons.inventory_2_outlined, AppRouter.products),
          _Action('Vendors', Icons.local_shipping_outlined, AppRouter.suppliers),
          _Action('Operations', Icons.receipt_long_outlined, AppRouter.purchases),
        ];
      case UserRole.delivery:
        return const [
          _Action('Orders', Icons.delivery_dining_outlined, AppRouter.orders),
          _Action('CRM', Icons.people_alt_outlined, AppRouter.customers),
        ];
      case UserRole.reception:
        return const [
          _Action('Tables', Icons.table_restaurant_outlined, AppRouter.tables),
          _Action('CRM', Icons.people_alt_outlined, AppRouter.customers),
        ];
      case UserRole.auditor:
        return const [
          _Action('Sales', Icons.point_of_sale_outlined, AppRouter.sales),
          _Action('Operations', Icons.receipt_long_outlined, AppRouter.purchases),
        ];
      default:
        return const [];
    }
  }
}

class _WorkedHoursCard extends StatelessWidget {
  final double width;
  final UserModel user;
  const _WorkedHoursCard({required this.width, required this.user});

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
          if (d['active'] == true && login != null) {
            minutes += DateTime.now().difference(login).inMinutes;
          } else {
            minutes += (d['durationMinutes'] as num?)?.toInt() ?? 0;
          }
        }
        return _Metric(width: width, label: 'Worked Today', value: '${minutes ~/ 60}h ${minutes % 60}m', icon: Icons.schedule_outlined, color: AppColors.secondary);
      },
    );
  }
}

class _ReviewsPanel extends StatelessWidget {
  final UserModel user;
  const _ReviewsPanel({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.outlineLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Customer Reviews', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.grey900)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('staff').doc(user.authUid).collection('reviews').orderBy('createdAt', descending: true).limit(5).snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('No customer reviews yet.', style: TextStyle(fontSize: 10.5, color: AppColors.grey500)));
            return Column(children: docs.map((doc) {
              final d = doc.data();
              final rating = (d['rating'] ?? 0).toDouble();
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariantLight))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.star_rounded, color: AppColors.warning, size: 17),
                  const SizedBox(width: 7),
                  Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 12),
                  Expanded(child: Text((d['review'] ?? '').toString(), style: const TextStyle(fontSize: 10.5, color: AppColors.grey700))),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric({required this.width, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 92,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.grey900)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)),
          ])),
        ]),
      );
}

class _ActionCard extends StatelessWidget {
  final _Action action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () => context.go(action.route),
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 170,
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.outlineLight)),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(9)), child: Icon(action.icon, color: AppColors.primary, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(action.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.grey800))),
            ]),
          ),
        ),
      );
}

class _Action {
  final String label;
  final IconData icon;
  final String route;
  const _Action(this.label, this.icon, this.route);
}
