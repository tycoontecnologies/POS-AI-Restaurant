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

  Future<void> _restore(UserModel user) async {
    await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({'dashboardHiddenWidgets': <String>[]}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final staffRef = FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('staff').doc(user.authUid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
            final showCommission = data['showCommissionToStaff'] == true;
            final points = (data['pointsEarned'] ?? 0).toInt();
            final rating = (data['averageRating'] ?? 0).toDouble();
            final reviews = (data['reviewCount'] ?? 0).toInt();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_dashboardTitle(user.role), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.grey900)),
                    const SizedBox(height: 3),
                    Text('${user.department.isEmpty ? user.role.name : user.department} • ${user.branchName}', style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                  ])),
                  OutlinedButton.icon(onPressed: () => _restore(user), icon: const Icon(Icons.dashboard_customize_outlined, size: 16), label: Text(hidden.isEmpty ? 'Customize' : 'Restore ${hidden.length} hidden')),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)), child: Text(user.role.name.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary))),
                ]),
                const SizedBox(height: 14),
                if (show('profile')) _WidgetBox(onClose: () => _hide(user, 'profile'), child: Row(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    CircleAvatar(radius: 38, backgroundColor: AppColors.primarySoft, backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null, child: photoUrl.isEmpty ? Text(user.name.isEmpty ? 'U' : user.name.substring(0,1).toUpperCase(), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.primary)) : null),
                    if (canChangePhoto) Positioned(right: -3, bottom: -2, child: Material(color: AppColors.primary, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: _uploading ? null : () => _pickPhoto(user), child: SizedBox(width: 28, height: 28, child: Center(child: _uploading ? const SizedBox(width:12,height:12,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.camera_alt_outlined,size:14,color:Colors.white))))))
                  ]),
                  const SizedBox(width: 15),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(user.email, style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)), const SizedBox(height: 6), Text(canChangePhoto ? 'Profile photo editing enabled by Admin.' : 'Profile photo changes are controlled by Admin.', style: const TextStyle(fontSize: 9.5, color: AppColors.grey500))])),
                ])),
                if (show('profile')) const SizedBox(height: 12),
                LayoutBuilder(builder: (_, c) {
                  final cardWidth = c.maxWidth >= 1000 ? (c.maxWidth - 48) / 5 : c.maxWidth >= 700 ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    if (show('hours')) _WorkedHours(width: cardWidth, user: user, onClose: () => _hide(user, 'hours')),
                    if (show('tips')) _Metric(width: cardWidth, keyName: 'tips', label: 'Tips Earned', value: 'Rs ${tips.toStringAsFixed(0)}', icon: Icons.volunteer_activism_outlined, color: AppColors.success, onClose: () => _hide(user, 'tips')),
                    if (showCommission && show('commission')) _Metric(width: cardWidth, keyName: 'commission', label: 'Commission', value: 'Rs ${commission.toStringAsFixed(0)}', icon: Icons.percent_rounded, color: AppColors.primary, onClose: () => _hide(user, 'commission')),
                    if (show('points')) _Metric(width: cardWidth, keyName: 'points', label: 'Points', value: '$points', icon: Icons.stars_outlined, color: AppColors.warning, onClose: () => _hide(user, 'points')),
                    if (show('rating')) _Metric(width: cardWidth, keyName: 'rating', label: 'Customer Rating', value: reviews == 0 ? 'No reviews' : '${rating.toStringAsFixed(1)} / 5', icon: Icons.rate_review_outlined, color: AppColors.info, onClose: () => _hide(user, 'rating')),
                  ]);
                }),
                if (show('controls')) ...[
                  const SizedBox(height: 14),
                  _WidgetBox(onClose: () => _hide(user, 'controls'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('My Controls', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 10),
                    Wrap(spacing: 9, runSpacing: 9, children: _actionsFor(user.role).map((a) => _ActionCard(action: a)).toList()),
                  ])),
                ],
                if (show('reviews')) ...[
                  const SizedBox(height: 12),
                  _WidgetBox(onClose: () => _hide(user, 'reviews'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Customer Reviews', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 6),
                    Text(reviews == 0 ? 'No reviews recorded yet.' : '$reviews reviews • ${rating.toStringAsFixed(1)} / 5 average', style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
                  ])),
                ],
              ]),
            );
          },
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
    } finally { if (mounted) setState(() => _uploading = false); }
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
        return const [_Action('Tables', Icons.table_restaurant_outlined, AppRouter.tables), _Action('Billing', Icons.receipt_long_outlined, AppRouter.orders), _Action('Sales', Icons.point_of_sale_outlined, AppRouter.sales)];
      case UserRole.kitchen:
        return const [_Action('Kitchen Orders', Icons.soup_kitchen_outlined, AppRouter.orders)];
      case UserRole.accounts:
        return const [_Action('Sales', Icons.point_of_sale_outlined, AppRouter.sales), _Action('Operations', Icons.receipt_long_outlined, AppRouter.purchases), _Action('Returns', Icons.assignment_return_outlined, AppRouter.salesReturn)];
      case UserRole.operations:
        return const [_Action('Operations', Icons.receipt_long_outlined, AppRouter.purchases), _Action('Inventory', Icons.inventory_2_outlined, AppRouter.products), _Action('Vendors', Icons.local_shipping_outlined, AppRouter.suppliers), _Action('Recipes', Icons.menu_book_outlined, AppRouter.ingredients)];
      case UserRole.inventory:
        return const [_Action('Inventory', Icons.inventory_2_outlined, AppRouter.products), _Action('Vendors', Icons.local_shipping_outlined, AppRouter.suppliers), _Action('Operations', Icons.receipt_long_outlined, AppRouter.purchases)];
      case UserRole.delivery:
        return const [_Action('Orders', Icons.delivery_dining_outlined, AppRouter.orders), _Action('CRM', Icons.people_alt_outlined, AppRouter.customers)];
      case UserRole.reception:
        return const [_Action('Tables', Icons.table_restaurant_outlined, AppRouter.tables), _Action('CRM', Icons.people_alt_outlined, AppRouter.customers)];
      default: return const [];
    }
  }
}

class _WidgetBox extends StatelessWidget {
  final Widget child; final VoidCallback onClose;
  const _WidgetBox({required this.child, required this.onClose});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.outlineLight)),
    child: Stack(children: [Padding(padding: const EdgeInsets.only(right: 20), child: child), Positioned(right: 0, top: 0, child: Tooltip(message: 'Hide widget', child: InkWell(onTap: onClose, child: const Icon(Icons.close_rounded, size: 16, color: AppColors.grey400))))]),
  );
}

class _WorkedHours extends StatelessWidget {
  final double width; final UserModel user; final VoidCallback onClose;
  const _WorkedHours({required this.width, required this.user, required this.onClose});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(); final start = DateTime(now.year, now.month, now.day);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(user.id).collection('auditSessions').where('loginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).snapshots(),
      builder: (_, snap) {
        var minutes = 0;
        for (final doc in snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
          final d = doc.data(); if ((d['authUid'] ?? '').toString() != user.authUid) continue;
          final login = d['loginAt'] is Timestamp ? (d['loginAt'] as Timestamp).toDate() : null;
          minutes += d['active'] == true && login != null ? DateTime.now().difference(login).inMinutes : (d['durationMinutes'] as num?)?.toInt() ?? 0;
        }
        return _Metric(width: width, keyName: 'hours', label: 'Worked Today', value: '${minutes ~/ 60}h ${minutes % 60}m', icon: Icons.schedule_outlined, color: AppColors.secondary, onClose: onClose);
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final double width; final String keyName; final String label; final String value; final IconData icon; final Color color; final VoidCallback onClose;
  const _Metric({required this.width, required this.keyName, required this.label, required this.value, required this.icon, required this.color, required this.onClose});
  @override
  Widget build(BuildContext context) => Container(width: width, height: 96, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)), child: Row(children: [Container(width:40,height:40,decoration:BoxDecoration(color:color.withValues(alpha:.10),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:20)),const SizedBox(width:10),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)),Text(label,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9.5,color:AppColors.grey500))])),Align(alignment:Alignment.topRight,child:InkWell(onTap:onClose,child:const Padding(padding:EdgeInsets.all(3),child:Icon(Icons.close_rounded,size:15,color:AppColors.grey400))))]));
}

class _ActionCard extends StatelessWidget {
  final _Action action;
  const _ActionCard({required this.action});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(onPressed: () => context.go(action.route), icon: Icon(action.icon, size: 17), label: Text(action.label), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13)));
}

class _Action {
  final String label; final IconData icon; final String route;
  const _Action(this.label, this.icon, this.route);
}
