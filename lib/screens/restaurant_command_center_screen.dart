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

const _mpsPurple = Color(0xFF6C3BFF);
const _line = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

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
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.restaurantName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
                  const SizedBox(height: 3),
                  Text('${user.branchName}  •  Today at a glance', style: const TextStyle(fontSize: 11.5, color: _muted)),
                ])),
                OutlinedButton.icon(
                  onPressed: _restoreAll,
                  style: OutlinedButton.styleFrom(foregroundColor: _mpsPurple, side: const BorderSide(color: _line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                  icon: const Icon(Icons.dashboard_customize_outlined, size: 17),
                  label: Text(hidden.isEmpty ? 'Customize' : 'Restore ${hidden.length} hidden'),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: _line)),
                  child: Row(children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 16, color: _mpsPurple),
                    const SizedBox(width: 6),
                    Text(user.isSuperAdmin ? 'SUPER ADMIN' : user.role.name.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
              const SizedBox(height: 15),
              LayoutBuilder(builder: (_, c) {
                final width = c.maxWidth >= 1150 ? (c.maxWidth - 48) / 5 : c.maxWidth >= 760 ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  if (show('revenue')) _Kpi(width: width, widgetKey: 'revenue', label: "Today's Revenue", value: 'Rs ${revenue.toStringAsFixed(0)}', icon: Icons.account_balance_wallet_outlined, accent: _mpsPurple, onTap: () => context.go(AppRouter.sales), onClose: _hide),
                  if (show('orders')) _Kpi(width: width, widgetKey: 'orders', label: "Today's Orders", value: '${todaySales.length}', icon: Icons.receipt_long_outlined, accent: const Color(0xFF3B82F6), onTap: () => context.go(AppRouter.orders), onClose: _hide),
                  if (show('service')) _Kpi(width: width, widgetKey: 'service', label: 'Tables In Service', value: '$inService', icon: Icons.table_restaurant_outlined, accent: const Color(0xFFF59E0B), onTap: () => context.go(AppRouter.tables), onClose: _hide),
                  if (show('available')) _Kpi(width: width, widgetKey: 'available', label: 'Tables Available', value: '$available', icon: Icons.event_available_outlined, accent: const Color(0xFF10B981), onTap: () => context.go(AppRouter.tables), onClose: _hide),
                  if (show('team')) _TeamKpi(width: width, restaurantId: user.id, onTap: () => context.go(AppRouter.usersRoles), onClose: () => _hide('team')),
                ]);
              }),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (_, c) {
                final three = c.maxWidth >= 1180;
                final two = c.maxWidth >= 780;
                final panels = <Widget>[
                  if (show('tables')) _Panel(widgetKey: 'tables', title: 'Tables in Service', subtitle: 'Waiter, guests, seats and live status.', onClose: _hide, onTap: () => context.go(AppRouter.tables), child: _TablesInService(restaurantId: user.id, tables: tables)),
                  if (show('transactions')) _Panel(widgetKey: 'transactions', title: 'Recent Transactions', subtitle: 'Latest restaurant sales.', onClose: _hide, onTap: () => context.go(AppRouter.sales), child: _RecentTransactions(sales: sales.take(10).toList())),
                  if (show('workforce')) _Panel(widgetKey: 'workforce', title: 'Workforce & Login Audit', subtitle: 'Who is working, branch, source and time.', onClose: _hide, onTap: () => context.go(AppRouter.usersRoles), child: _WorkforceAudit(restaurantId: user.id)),
                  if (show('floor')) _Panel(widgetKey: 'floor', title: 'Floor Snapshot', subtitle: 'Fast status distribution.', onClose: _hide, onTap: () => context.go(AppRouter.tables), child: _FloorSnapshot(tables: tables)),
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
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))]),
    child: Row(children: [
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: accent, size: 20))),
      const SizedBox(width: 10),
      Expanded(child: InkWell(onTap: onTap, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)), const SizedBox(height: 2), Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _muted))]))),
      Align(alignment: Alignment.topRight, child: Tooltip(message: 'Hide widget', child: InkWell(onTap: () => onClose(widgetKey), child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8))))),
    ]),
  );
}

class _TeamKpi extends StatelessWidget {
  final double width; final String restaurantId; final VoidCallback onTap; final VoidCallback onClose;
  const _TeamKpi({required this.width, required this.restaurantId, required this.onTap, required this.onClose});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(); final start = DateTime(now.year, now.month, now.day);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(restaurantId).collection('sessions').where('startedAt', isGreaterThanOrEqualTo: start).snapshots(),
      builder: (_, snap) {
        final online = (snap.data?.docs ?? const []).where((d) => d.data()['endedAt'] == null).length;
        return _Kpi(width: width, widgetKey: 'team', label: 'Team Online', value: '$online', icon: Icons.groups_2_outlined, accent: const Color(0xFF3B82F6), onTap: onTap, onClose: (_) async => onClose());
      },
    );
  }
}

class _Panel extends StatelessWidget {
  final String widgetKey; final String title; final String subtitle; final Widget child; final Future<void> Function(String) onClose; final VoidCallback onTap;
  const _Panel({required this.widgetKey, required this.title, required this.subtitle, required this.child, required this.onClose, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 260),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 9.5, color: _muted))]))),
        IconButton(tooltip: 'Hide widget', visualDensity: VisualDensity.compact, onPressed: () => onClose(widgetKey), icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8))),
      ]),
      const SizedBox(height: 8),
      Expanded(child: child),
    ]),
  );
}

class _RecentTransactions extends StatelessWidget {
  final List<Sale> sales;
  const _RecentTransactions({required this.sales});
  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) return const Center(child: Text('No transactions yet.', style: TextStyle(color: _muted)));
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (_, i) {
        final s = sales[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(9), border: Border.all(color: _line)),
          child: Row(children: [
            const Icon(Icons.receipt_long_outlined, size: 16, color: _mpsPurple),
            const SizedBox(width: 8),
            Expanded(child: Text(s.tableNumber?.isNotEmpty == true ? 'Table ${s.tableNumber}' : 'Order', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
            Text('${s.items.length} items', style: const TextStyle(fontSize: 9, color: _muted)),
            const SizedBox(width: 10),
            Text('Rs ${s.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
          ]),
        );
      },
    );
  }
}

class _TablesInService extends StatelessWidget {
  final String restaurantId; final List<RestaurantTable> tables;
  const _TablesInService({required this.restaurantId, required this.tables});
  @override
  Widget build(BuildContext context) {
    final active = tables.where((t) => t.status != TableStatus.empty).take(9).toList();
    if (active.isEmpty) return const Center(child: Text('No tables in service.', style: TextStyle(color: _muted)));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(restaurantId).collection('tableOrders').snapshots(),
      builder: (_, snap) {
        final infos = <String, Map<String, dynamic>>{for (final d in snap.data?.docs ?? const []) d.id: d.data()};
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, itemCount: active.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final t = active[i]; final info = infos[t.id] ?? const <String, dynamic>{};
            final waiter = (info['waiterName'] ?? 'Unassigned').toString();
            final guests = (info['guestCount'] ?? '—').toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF59E0B))),
                const SizedBox(width: 8),
                SizedBox(width: 62, child: Text(t.name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(waiter, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)), Text('$guests guests • ${t.numberOfSeats} seats', style: const TextStyle(fontSize: 9, color: _muted))])),
                Text(t.status.name.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
              ]),
            );
          },
        );
      },
    );
  }
}

class _WorkforceAudit extends StatelessWidget {
  final String restaurantId;
  const _WorkforceAudit({required this.restaurantId});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(); final start = DateTime(now.year, now.month, now.day);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(restaurantId).collection('sessions').where('startedAt', isGreaterThanOrEqualTo: start).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) return const Center(child: Text('No work sessions today.', style: TextStyle(color: _muted)));
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, itemCount: docs.take(8).length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: Text((d['userName'] ?? d['email'] ?? 'Team member').toString(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
              Text((d['branchName'] ?? 'Main Branch').toString(), style: const TextStyle(fontSize: 9, color: _muted)),
            ]));
          },
        );
      },
    );
  }
}

class _FloorSnapshot extends StatelessWidget {
  final List<RestaurantTable> tables;
  const _FloorSnapshot({required this.tables});
  @override
  Widget build(BuildContext context) {
    final total = tables.isEmpty ? 1 : tables.length;
    final empty = tables.where((t) => t.status == TableStatus.empty).length;
    final occupied = tables.where((t) => t.status == TableStatus.occupied).length;
    final served = tables.where((t) => t.status == TableStatus.served).length;
    final cleared = tables.where((t) => t.status == TableStatus.cleared).length;
    final data = [('Available', empty, const Color(0xFF10B981)), ('Occupied', occupied, const Color(0xFFF59E0B)), ('Served', served, const Color(0xFF3B82F6)), ('Cleared', cleared, _mpsPurple)];
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: data.map((d) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(children: [
      Row(children: [Expanded(child: Text(d.$1, style: const TextStyle(fontSize: 10))), Text('${d.$2}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))]),
      const SizedBox(height: 5),
      LinearProgressIndicator(value: d.$2 / total, minHeight: 7, borderRadius: BorderRadius.circular(10), backgroundColor: const Color(0xFFF1F5F9), valueColor: AlwaysStoppedAnimation(d.$3)),
    ]))).toList());
  }
}
