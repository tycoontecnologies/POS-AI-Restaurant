import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';
import 'package:pos/utils/app_colors.dart';

class RestaurantCommandCenterScreen extends StatefulWidget {
  const RestaurantCommandCenterScreen({super.key});
  @override
  State<RestaurantCommandCenterScreen> createState() => _RestaurantCommandCenterScreenState();
}

class _RestaurantCommandCenterScreenState extends State<RestaurantCommandCenterScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final tables = context.read<TableProvider>();
    final sales = context.read<SaleProvider>();
    if (tables.tables.isEmpty && !tables.isLoading) tables.loadTables();
    if (sales.sales.isEmpty && !sales.isLoading) sales.fetchSales(user.id);
  }

  bool _today(DateTime v) {
    final n = DateTime.now();
    return v.year == n.year && v.month == n.month && v.day == n.day;
  }

  Future<void> _hide(String key) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({
      'dashboardHiddenWidgets': FieldValue.arrayUnion([key]),
    }, SetOptions(merge: true));
  }

  Future<void> _restoreAll() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('vendors').doc(user.authUid).set({'dashboardHiddenWidgets': <String>[]}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final tables = context.watch<TableProvider>().tables;
    final sales = context.watch<SaleProvider>().sales;
    final todaySales = sales.where((s) => _today(s.createdAt)).toList();
    final revenue = todaySales.fold<double>(0, (a, b) => a + b.total);
    final inService = tables.where((t) => t.status != TableStatus.empty).length;
    final available = tables.where((t) => t.status == TableStatus.empty).length;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(user.authUid).snapshots(),
      builder: (_, prefSnap) {
        final hidden = Set<String>.from(prefSnap.data?.data()?['dashboardHiddenWidgets'] ?? const <String>[]);
        bool show(String key) => !hidden.contains(key);
        return Container(
          color: AppColors.backgroundLight,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Restaurant Command Center', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.grey900)),
                  const SizedBox(height: 3),
                  Text('${user.restaurantName}  •  ${user.branchName}  •  Admin intelligence', style: const TextStyle(fontSize: 11.5, color: AppColors.grey500)),
                ])),
                OutlinedButton.icon(onPressed: _restoreAll, icon: const Icon(Icons.dashboard_customize_outlined, size: 17), label: Text(hidden.isEmpty ? 'Customize' : 'Restore ${hidden.length} hidden')),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.outlineLight)), child: Row(children: [const Icon(Icons.hub_outlined, size: 16, color: AppColors.primary), const SizedBox(width: 6), Text(user.isSuperAdmin ? 'SUPER ADMIN' : user.role.name.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800))])),
              ]),
              const SizedBox(height: 15),
              LayoutBuilder(builder: (_, c) {
                final width = c.maxWidth >= 1150 ? (c.maxWidth - 48) / 5 : c.maxWidth >= 760 ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  if (show('revenue')) _Kpi(width: width, widgetKey: 'revenue', label: "Today's Revenue", value: 'Rs ${revenue.toStringAsFixed(0)}', icon: Icons.account_balance_wallet_outlined, accent: AppColors.primary, onTap: () => context.go(AppRouter.sales), onClose: _hide),
                  if (show('orders')) _Kpi(width: width, widgetKey: 'orders', label: "Today's Orders", value: '${todaySales.length}', icon: Icons.receipt_long_outlined, accent: AppColors.info, onTap: () => context.go(AppRouter.orders), onClose: _hide),
                  if (show('service')) _Kpi(width: width, widgetKey: 'service', label: 'Tables In Service', value: '$inService', icon: Icons.table_restaurant_outlined, accent: AppColors.warning, onTap: () => context.go(AppRouter.tables), onClose: _hide),
                  if (show('available')) _Kpi(width: width, widgetKey: 'available', label: 'Tables Available', value: '$available', icon: Icons.event_available_outlined, accent: AppColors.success, onTap: () => context.go(AppRouter.tables), onClose: _hide),
                  if (show('team')) _TeamKpi(width: width, restaurantId: user.id, onTap: () => context.go(AppRouter.usersRoles), onClose: () => _hide('team')),
                ]);
              }),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (_, c) {
                final three = c.maxWidth >= 1180;
                final two = c.maxWidth >= 780;
                final panels = <Widget>[
                  if (show('tables')) _Panel(widgetKey: 'tables', title: 'Tables in Service', subtitle: 'Waiter, guests, seats and live status.', onClose: _hide, onTap: () => context.go(AppRouter.tables), child: _TablesInService(restaurantId: user.id, tables: tables)),
                  if (show('transactions')) _Panel(widgetKey: 'transactions', title: 'Recent Transactions', subtitle: 'Compact view of the latest restaurant sales.', onClose: _hide, onTap: () => context.go(AppRouter.sales), child: _RecentTransactions(sales: sales.take(10).toList())),
                  if (show('workforce')) _Panel(widgetKey: 'workforce', title: 'Workforce & Login Audit', subtitle: 'Who is working, branch, source and time.', onClose: _hide, onTap: () => context.go(AppRouter.usersRoles), child: _WorkforceAudit(restaurantId: user.id)),
                  if (show('floor')) _Panel(widgetKey: 'floor', title: 'Floor Snapshot', subtitle: 'Fast status distribution across this branch.', onClose: _hide, onTap: () => context.go(AppRouter.tables), child: _FloorSnapshot(tables: tables)),
                ];
                if (!two) return Column(children: panels.map((p) => Padding(padding: const EdgeInsets.only(bottom: 12), child: p)).toList());
                final cols = three ? 3 : 2;
                final width = (c.maxWidth - (cols - 1) * 12) / cols;
                return Wrap(spacing: 12, runSpacing: 12, children: panels.map((p) => SizedBox(width: width, child: p)).toList());
              }),
            ]),
          ),
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  final double width; final String widgetKey; final String label; final String value; final IconData icon; final Color accent; final VoidCallback onTap; final Future<void> Function(String) onClose;
  const _Kpi({required this.width, required this.widgetKey, required this.label, required this.value, required this.icon, required this.accent, required this.onTap, required this.onClose});
  @override
  Widget build(BuildContext context) => Container(
    width: width, height: 98, padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)),
    child: Row(children: [
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: accent, size: 20))),
      const SizedBox(width: 10),
      Expanded(child: InkWell(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.grey500))]))),
      Align(alignment: Alignment.topRight, child: Tooltip(message: 'Hide widget', child: InkWell(onTap: () => onClose(widgetKey), child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.close_rounded, size: 15, color: AppColors.grey400))))),
    ]),
  );
}

class _TeamKpi extends StatelessWidget {
  final double width; final String restaurantId; final VoidCallback onTap; final VoidCallback onClose;
  const _TeamKpi({required this.width, required this.restaurantId, required this.onTap, required this.onClose});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(); final start = DateTime(now.year, now.month, now.day);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('vendors').doc(restaurantId).collection('auditSessions').where('loginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).snapshots(), builder: (_, snap) {
      final active = (snap.data?.docs ?? []).where((d) => d.data()['active'] == true).map((d) => d.data()['authUid']).toSet().length;
      return Container(width: width, height: 98, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)), child: Row(children: [
        InkWell(onTap: onTap, child: Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.groups_2_outlined, color: AppColors.secondary, size: 20))), const SizedBox(width: 10),
        Expanded(child: InkWell(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$active', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const Text('Team Online', style: TextStyle(fontSize: 10, color: AppColors.grey500))]))),
        Align(alignment: Alignment.topRight, child: InkWell(onTap: onClose, child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.close_rounded, size: 15, color: AppColors.grey400)))),
      ]));
    });
  }
}

class _Panel extends StatelessWidget {
  final String widgetKey; final String title; final String subtitle; final Widget child; final Future<void> Function(String) onClose; final VoidCallback onTap;
  const _Panel({required this.widgetKey, required this.title, required this.subtitle, required this.child, required this.onClose, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 270), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineLight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: InkWell(onTap: onTap, child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)))), IconButton(tooltip: 'Hide widget', visualDensity: VisualDensity.compact, onPressed: () => onClose(widgetKey), icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.grey400))]),
      Text(subtitle, style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)), const SizedBox(height: 12), child,
    ]),
  );
}

class _TablesInService extends StatelessWidget {
  final String restaurantId; final List<RestaurantTable> tables;
  const _TablesInService({required this.restaurantId, required this.tables});
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('vendors').doc(restaurantId).collection('tableOrders').snapshots(),
    builder: (_, snap) {
      final orders = {for (final d in snap.data?.docs ?? <QueryDocumentSnapshot<Map<String,dynamic>>>[]) d.id: d.data()};
      final active = tables.where((t) => t.status != TableStatus.empty).take(7).toList();
      if (active.isEmpty) return const SizedBox(height: 190, child: Center(child: Text('No tables currently in service.', style: TextStyle(color: AppColors.grey500))));
      return Column(children: active.map((t) {
        final info = orders[t.id] ?? const <String,dynamic>{};
        final waiter = (info['waiterName'] ?? 'Unassigned').toString();
        final guests = (info['customerCount'] as num?)?.toInt();
        final status = (info['status'] ?? t.status.name).toString();
        final color = status == 'making' ? AppColors.warning : t.status == TableStatus.served ? AppColors.info : t.status == TableStatus.cleared ? AppColors.primary : AppColors.error;
        return InkWell(onTap: () => context.go(AppRouter.tables), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariantLight))), child: Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8),
          SizedBox(width: 54, child: Text('T ${t.tableNumber}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(waiter, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)), Text('${guests ?? '—'} guests • ${t.numberOfSeats} seats', style: const TextStyle(fontSize: 9, color: AppColors.grey500))])),
          Text(status == 'making' ? 'MAKING' : t.status.name.toUpperCase(), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color)),
        ])));
      }).toList());
    },
  );
}

class _RecentTransactions extends StatelessWidget {
  final List<Sale> sales;
  const _RecentTransactions({required this.sales});
  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) return const SizedBox(height: 190, child: Center(child: Text('No recent sales.', style: TextStyle(color: AppColors.grey500))));
    return LayoutBuilder(builder: (_, c) {
      final two = c.maxWidth > 430;
      final w = two ? (c.maxWidth - 8) / 2 : c.maxWidth;
      return Wrap(spacing: 8, runSpacing: 8, children: sales.take(8).map((s) => InkWell(
        onTap: () => context.go(AppRouter.sales),
        child: Container(width: w, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.outlineVariantLight)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.receipt_long_outlined, size: 14, color: AppColors.primary), const SizedBox(width: 5), Expanded(child: Text(s.tableNumber == null ? 'Order' : 'Table ${s.tableNumber}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))), Text('Rs ${s.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))]),
          const SizedBox(height: 5), Text('${s.items.length} items • ${s.paymentMethod}', style: const TextStyle(fontSize: 8.8, color: AppColors.grey500)),
        ])),
      )).toList());
    });
  }
}

class _WorkforceAudit extends StatelessWidget {
  final String restaurantId;
  const _WorkforceAudit({required this.restaurantId});
  @override
  Widget build(BuildContext context) {
    final n = DateTime.now(); final start = DateTime(n.year,n.month,n.day);
    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(restaurantId).collection('auditSessions').where('loginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).orderBy('loginAt', descending: true).limit(7).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox(height: 190, child: Center(child: Text('No sessions today.', style: TextStyle(color: AppColors.grey500))));
        return Column(children: docs.map((d) {
          final x = d.data(); final login = x['loginAt'] is Timestamp ? (x['loginAt'] as Timestamp).toDate() : null; final active = x['active'] == true; final mins = active && login != null ? DateTime.now().difference(login).inMinutes : (x['durationMinutes'] as num?)?.toInt() ?? 0;
          return Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariantLight))), child: Row(children: [Container(width: 7,height:7,decoration:BoxDecoration(shape:BoxShape.circle,color:active?AppColors.success:AppColors.grey300)), const SizedBox(width:7), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((x['userName'] ?? 'User').toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5,fontWeight:FontWeight.w700)), Text('${x['department'] ?? x['role'] ?? ''} • ${x['source'] ?? ''}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize:8.8,color:AppColors.grey500))])), Text('${mins~/60}h ${mins%60}m', style: const TextStyle(fontSize:9.5,fontWeight:FontWeight.w700))]));
        }).toList());
      },
    );
  }
}

class _FloorSnapshot extends StatelessWidget {
  final List<RestaurantTable> tables;
  const _FloorSnapshot({required this.tables});
  @override
  Widget build(BuildContext context) {
    final rows = <(String,int,Color)>[
      ('Available', tables.where((t)=>t.status==TableStatus.empty).length, AppColors.success),
      ('Occupied', tables.where((t)=>t.status==TableStatus.occupied).length, AppColors.error),
      ('Served', tables.where((t)=>t.status==TableStatus.served).length, AppColors.info),
      ('Billing', tables.where((t)=>t.status==TableStatus.cleared).length, AppColors.primary),
    ];
    return Column(children: rows.map((r) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Container(width:9,height:9,decoration:BoxDecoration(color:r.$3,shape:BoxShape.circle)), const SizedBox(width:8), Expanded(child: Text(r.$1, style: const TextStyle(fontSize:10.5))), Text('${r.$2}', style: const TextStyle(fontSize:11,fontWeight:FontWeight.w900))]))).toList());
  }
}
