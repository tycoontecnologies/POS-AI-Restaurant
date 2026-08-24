import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_provider.dart';
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

  bool _today(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year && value.month == now.month && value.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final tables = context.watch<TableProvider>().tables;
    final sales = context.watch<SaleProvider>().sales;
    final todaySales = sales.where((s) => _today(s.createdAt)).toList();
    final revenue = todaySales.fold<double>(0, (a, b) => a + b.total);
    final activeTables = tables.where((t) => t.status != TableStatus.empty).length;
    final availableTables = tables.where((t) => t.status == TableStatus.empty).length;

    return Container(
      color: AppColors.backgroundLight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Restaurant Command Center', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.grey900)),
              const SizedBox(height: 4),
              Text('${user.restaurantName}  •  ${user.branchName}', style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.outlineLight)),
              child: Row(children: [
                const Icon(Icons.hub_outlined, size: 17, color: AppColors.primary),
                const SizedBox(width: 7),
                Text(user.isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.grey700)),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (_, c) {
            final width = c.maxWidth >= 1100 ? (c.maxWidth - 48) / 5 : c.maxWidth >= 760 ? (c.maxWidth - 24) / 3 : (c.maxWidth - 12) / 2;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              _Kpi(width: width, label: "Today's Revenue", value: 'Rs ${revenue.toStringAsFixed(0)}', icon: Icons.account_balance_wallet_outlined, accent: AppColors.primary),
              _Kpi(width: width, label: "Today's Orders", value: '${todaySales.length}', icon: Icons.receipt_long_outlined, accent: AppColors.info),
              _Kpi(width: width, label: 'Tables In Service', value: '$activeTables', icon: Icons.table_restaurant_outlined, accent: AppColors.warning),
              _Kpi(width: width, label: 'Tables Available', value: '$availableTables', icon: Icons.event_available_outlined, accent: AppColors.success),
              _LiveWorkforceKpi(width: width, restaurantId: user.id),
            ]);
          }),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (_, c) {
            final stacked = c.maxWidth < 980;
            final floor = _LiveFloor(tables: tables);
            final workforce = _WorkforceAudit(restaurantId: user.id);
            if (stacked) return Column(children: [floor, const SizedBox(height: 14), workforce]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 5, child: floor),
              const SizedBox(width: 14),
              Expanded(flex: 6, child: workforce),
            ]);
          }),
          const SizedBox(height: 14),
          _RecentSales(sales: sales.take(8).toList()),
        ]),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  const _Kpi({required this.width, required this.label, required this.value, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 96,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.outlineLight)),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: accent, size: 20)),
      const SizedBox(width: 11),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.grey900)),
        const SizedBox(height: 3),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.grey500)),
      ])),
    ]),
  );
}

class _LiveWorkforceKpi extends StatelessWidget {
  final double width;
  final String restaurantId;
  const _LiveWorkforceKpi({required this.width, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('vendors').doc(restaurantId).collection('auditSessions').where('loginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).snapshots(),
      builder: (_, snap) {
        final activeUsers = (snap.data?.docs ?? []).where((d) => d.data()['active'] == true).map((d) => d.data()['authUid']).toSet().length;
        return _Kpi(width: width, label: 'Team Online', value: '$activeUsers', icon: Icons.groups_2_outlined, accent: AppColors.secondary);
      },
    );
  }
}

class _LiveFloor extends StatelessWidget {
  final List<RestaurantTable> tables;
  const _LiveFloor({required this.tables});

  @override
  Widget build(BuildContext context) {
    final available = tables.where((t) => t.status == TableStatus.empty).length;
    final occupied = tables.where((t) => t.status == TableStatus.occupied).length;
    final served = tables.where((t) => t.status == TableStatus.served).length;
    final billing = tables.where((t) => t.status == TableStatus.cleared).length;
    return _Panel(
      title: 'Live Floor',
      subtitle: 'Current table state across this branch.',
      child: Column(children: [
        _StatusLine('Available', available, tables.length, AppColors.success),
        _StatusLine('Occupied / Making', occupied, tables.length, AppColors.warning),
        _StatusLine('Served', served, tables.length, AppColors.info),
        _StatusLine('Billing', billing, tables.length, AppColors.primary),
      ]),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _StatusLine(this.label, this.value, this.total, this.color);
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(children: [
        Row(children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey700)), const Spacer(), Text('$value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: AppColors.grey100, color: color)),
      ]),
    );
  }
}

class _WorkforceAudit extends StatelessWidget {
  final String restaurantId;
  const _WorkforceAudit({required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _Panel(
      title: 'Workforce & Login Audit',
      subtitle: 'Today’s logins, work sessions, branch and source.',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('vendors').doc(restaurantId).collection('auditSessions').where('loginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).orderBy('loginAt', descending: true).limit(10).snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 210, child: Center(child: CircularProgressIndicator()));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const SizedBox(height: 210, child: Center(child: Text('No login sessions recorded today.', style: TextStyle(color: AppColors.grey500))));
          return Column(children: docs.map((d) => _SessionRow(data: d.data())).toList());
        },
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SessionRow({required this.data});
  @override
  Widget build(BuildContext context) {
    final login = data['loginAt'] is Timestamp ? (data['loginAt'] as Timestamp).toDate() : null;
    final active = data['active'] == true;
    final minutes = data['durationMinutes'] as int?;
    final worked = active && login != null ? DateTime.now().difference(login).inMinutes : (minutes ?? 0);
    final h = worked ~/ 60;
    final m = worked % 60;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariantLight))),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? AppColors.success : AppColors.grey300)),
        const SizedBox(width: 9),
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((data['userName'] ?? 'User').toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text('${data['department'] ?? data['role'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)),
        ])),
        Expanded(flex: 2, child: Text((data['branchName'] ?? 'Main Branch').toString(), style: const TextStyle(fontSize: 9.5, color: AppColors.grey600))),
        Expanded(flex: 2, child: Text((data['source'] ?? '').toString(), style: const TextStyle(fontSize: 9.5, color: AppColors.grey600))),
        SizedBox(width: 65, child: Text('${h}h ${m}m', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _RecentSales extends StatelessWidget {
  final List<Sale> sales;
  const _RecentSales({required this.sales});
  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent Transactions',
      subtitle: 'Latest sales recorded by the restaurant.',
      child: sales.isEmpty
          ? const SizedBox(height: 100, child: Center(child: Text('No recent sales.', style: TextStyle(color: AppColors.grey500))))
          : Column(children: sales.map((s) => Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariantLight))),
              child: Row(children: [
                const Icon(Icons.receipt_long_outlined, size: 17, color: AppColors.primary),
                const SizedBox(width: 9),
                Expanded(child: Text(s.tableNumber == null ? 'Order ${s.id}' : 'Table ${s.tableNumber}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
                Text('${s.items.length} items', style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)),
                const SizedBox(width: 20),
                Text('Rs ${s.total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            )).toList()),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Panel({required this.title, required this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.outlineLight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.grey900)),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(fontSize: 9.5, color: AppColors.grey500)),
      const SizedBox(height: 14),
      child,
    ]),
  );
}
